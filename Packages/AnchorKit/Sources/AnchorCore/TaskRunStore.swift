import Foundation

public enum TaskRunStoreError: Error, Equatable, Sendable {
    case taskNotFound, taskArchived, ownershipMismatch, invalidArchive, confirmationRequired, sourceIdentityRequired
    case activeTaskConflict, eventIdentityConflict, eventOutsideTaskBoundary
    case unsupportedSchemaVersion(Int), migrationBackupConflict
}

/// Small durable store for the task hierarchy while the legacy session projection migrates.
public actor TaskRunStore {
    public static let currentSchemaVersion = 2

    private struct State: Codable {
        var schemaVersion: Int
        var tasks: [AnchorTask]
        var workItems: [AnchorWorkItem]
        var runs: [AnchorRun]
        var events: [AnchorTaskEvent]
        var associations: [AnchorSessionAssociation]

        init(schemaVersion: Int = TaskRunStore.currentSchemaVersion, tasks: [AnchorTask] = [], workItems: [AnchorWorkItem] = [], runs: [AnchorRun] = [], events: [AnchorTaskEvent] = [], associations: [AnchorSessionAssociation] = []) {
            self.schemaVersion = schemaVersion
            self.tasks = tasks; self.workItems = workItems; self.runs = runs; self.events = events; self.associations = associations
        }

        private enum CodingKeys: String, CodingKey { case schemaVersion, tasks, workItems, runs, events, associations }
        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            guard (1 ... TaskRunStore.currentSchemaVersion).contains(schemaVersion) else {
                throw TaskRunStoreError.unsupportedSchemaVersion(schemaVersion)
            }
            tasks = try values.decodeIfPresent([AnchorTask].self, forKey: .tasks) ?? []
            workItems = try values.decodeIfPresent([AnchorWorkItem].self, forKey: .workItems) ?? []
            runs = try values.decodeIfPresent([AnchorRun].self, forKey: .runs) ?? []
            events = try values.decodeIfPresent([AnchorTaskEvent].self, forKey: .events) ?? []
            associations = try values.decodeIfPresent([AnchorSessionAssociation].self, forKey: .associations) ?? []
        }
    }
    private let url: URL
    private var state: State
    private var recoveryError: Error?
    private var legacySourceData: Data?

    public static func defaultStorageURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Anchor/task-runs.json")
    }

    public init(url: URL = TaskRunStore.defaultStorageURL()) {
        self.url = url
        state = State()
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                state = try JSONDecoder().decode(State.self, from: data)
                if state.schemaVersion < Self.currentSchemaVersion {
                    legacySourceData = data
                }
            }
            catch { recoveryError = error }
        }
    }

    public static func migrationBackupURL(for storageURL: URL) -> URL {
        storageURL.appendingPathExtension("pre-v2.backup")
    }

    public func snapshot() -> (tasks: [AnchorTask], workItems: [AnchorWorkItem], runs: [AnchorRun], events: [AnchorTaskEvent], associations: [AnchorSessionAssociation]) {
        (state.tasks, state.workItems, state.runs, state.events, state.associations)
    }

    /// Returns the current three-dimensional state derived from persisted run history.
    public func workItemState(id: UUID) -> AnchorWorkItemState? {
        guard let workItem = state.workItems.first(where: { $0.id == id }) else { return nil }
        return AnchorWorkItemStateProjector.project(workItem: workItem, runs: state.runs)
    }

    /// Returns stable projections for every work item owned by one semantic task.
    public func workItemStates(taskID: UUID) -> [AnchorWorkItemState] {
        state.workItems
            .filter { $0.taskID == taskID }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { AnchorWorkItemStateProjector.project(workItem: $0, runs: state.runs) }
    }

    /// Aggregates the observed work without treating it as user confirmation.
    public func taskState(id: UUID) -> AnchorTaskState? {
        guard let task = state.tasks.first(where: { $0.id == id }) else { return nil }
        return AnchorTaskStateProjector.project(
            task: task,
            workItemStates: workItemStates(taskID: id)
        )
    }

    /// Returns the one non-archived task. Ambiguous legacy data is not guessed.
    public func currentTaskRecord() -> AnchorTaskRecord? {
        let current = state.tasks.filter { $0.lifecycle != .archived }
        guard current.count == 1, let task = current.first else { return nil }
        return taskRecord(for: task)
    }

    /// Returns immutable archived task histories, newest completion first.
    public func taskHistory() -> [AnchorTaskRecord] {
        state.tasks
            .filter { $0.lifecycle == .archived }
            .sorted(by: Self.historyOrder)
            .map(taskRecord)
    }

    /// Activates a user-created foreground task and closes any older foreground
    /// task at this new task's boundary. This also repairs an interrupted
    /// completion write without merging the two histories.
    public func activate(task: AnchorTask) throws {
        guard task.lifecycle != .archived, task.endedAt == nil else {
            throw TaskRunStoreError.invalidArchive
        }
        if let existing = state.tasks.first(where: { $0.id == task.id }),
           existing.lifecycle == .archived {
            throw TaskRunStoreError.taskArchived
        }

        var next = state
        for index in next.tasks.indices where
            next.tasks[index].id != task.id && next.tasks[index].lifecycle != .archived {
            guard task.createdAt >= next.tasks[index].createdAt else {
                throw TaskRunStoreError.activeTaskConflict
            }
            next.tasks[index].lifecycle = .archived
            next.tasks[index].endedAt = task.createdAt
        }
        next.tasks.removeAll { $0.id == task.id }
        next.tasks.append(task)
        try persist(next)
    }

    public func upsert(task: AnchorTask) throws {
        if let existing = state.tasks.first(where: { $0.id == task.id }), existing.lifecycle == .archived {
            guard existing == task else { throw TaskRunStoreError.taskArchived }
            return
        }
        // Archival requires the explicit user-confirmation operation below.
        guard task.lifecycle != .archived, task.endedAt == nil else { throw TaskRunStoreError.invalidArchive }
        if !state.tasks.contains(where: { $0.id == task.id }),
           state.tasks.contains(where: { $0.lifecycle != .archived }) {
            throw TaskRunStoreError.activeTaskConflict
        }
        var next = state
        next.tasks.removeAll { $0.id == task.id }
        next.tasks.append(task)
        try persist(next)
    }

    public func upsert(workItem: AnchorWorkItem) throws {
        try requireOpenTask(workItem.taskID)
        if let existing = state.workItems.first(where: { $0.id == workItem.id }), existing.taskID != workItem.taskID {
            throw TaskRunStoreError.ownershipMismatch
        }
        var next = state
        next.workItems.removeAll { $0.id == workItem.id }
        next.workItems.append(workItem)
        try persist(next)
    }

    public func upsert(run: AnchorRun) throws {
        try requireOpenTask(run.taskID)
        var next = state
        try apply(run: run, to: &next)
        try persist(next)
    }

    /// Commits the immutable source fact and its current Run projection together.
    public func record(event: AnchorTaskEvent, run: AnchorRun) throws {
        try requireOpenTask(event.taskID)
        guard event.taskID == run.taskID,
              event.workItemID == run.workItemID,
              event.runID == run.id,
              event.sourceID == run.sourceID,
              event.sourceSessionID == run.sourceSessionID else {
            throw TaskRunStoreError.ownershipMismatch
        }
        guard let task = state.tasks.first(where: { $0.id == event.taskID }),
              event.occurredAt >= task.createdAt else {
            throw TaskRunStoreError.eventOutsideTaskBoundary
        }
        if let existing = state.events.first(where: { $0.id == event.id }) {
            guard Self.sameSourceFact(existing, event) else {
                throw TaskRunStoreError.eventIdentityConflict
            }
            return
        }

        var next = state
        next.events.append(event)
        try apply(run: run, to: &next)
        try persist(next)
    }

    public func events(taskID: UUID) -> [AnchorTaskEvent] {
        state.events
            .filter { $0.taskID == taskID }
            .sorted(by: Self.eventOrder)
    }

    public func confirmTaskEnded(taskID: UUID, at date: Date = .now) throws {
        guard let index = state.tasks.firstIndex(where: { $0.id == taskID }) else {
            throw TaskRunStoreError.taskNotFound
        }
        if state.tasks[index].lifecycle == .archived { return }
        guard date >= state.tasks[index].createdAt else { throw TaskRunStoreError.invalidArchive }
        var next = state
        next.tasks[index].lifecycle = .archived
        next.tasks[index].endedAt = date
        // Preserve unresolved runs exactly as they were when the user ended the task.
        try persist(next)
    }

    public func confirmAssociation(_ association: AnchorSessionAssociation) throws {
        guard association.target.confirmedByUser else { throw TaskRunStoreError.confirmationRequired }
        guard association.sourceID != nil else { throw TaskRunStoreError.sourceIdentityRequired }
        try requireOpenTask(association.target.taskID)
        guard state.workItems.contains(where: {
            $0.id == association.target.workItemID && $0.taskID == association.target.taskID
        }) else { throw TaskRunStoreError.ownershipMismatch }
        var next = state
        next.associations.removeAll {
            $0.sessionID == association.sessionID
                && ($0.sourceID == association.sourceID || $0.sourceID == nil)
        }
        next.associations.append(association)
        try persist(next)
    }

    public func associations() -> [AnchorSessionAssociation] { state.associations }

    private func taskRecord(for task: AnchorTask) -> AnchorTaskRecord {
        let workItems = state.workItems
            .filter { $0.taskID == task.id }
            .sorted(by: Self.workItemOrder)
        let runs = state.runs
            .filter { $0.taskID == task.id }
            .sorted(by: Self.runOrder)
        let events = state.events
            .filter { $0.taskID == task.id }
            .sorted(by: Self.eventOrder)
        return AnchorTaskRecord(
            task: task,
            state: AnchorTaskStateProjector.project(
                task: task,
                workItemStates: workItems.map {
                    AnchorWorkItemStateProjector.project(workItem: $0, runs: runs)
                }
            ),
            workItems: workItems,
            runs: runs,
            events: events
        )
    }

    private func requireOpenTask(_ id: UUID) throws {
        if let recoveryError { throw recoveryError }
        guard let task = state.tasks.first(where: { $0.id == id }) else { throw TaskRunStoreError.taskNotFound }
        guard task.lifecycle != .archived else { throw TaskRunStoreError.taskArchived }
    }

    private func apply(run: AnchorRun, to next: inout State) throws {
        guard next.workItems.contains(where: { $0.id == run.workItemID && $0.taskID == run.taskID }) else {
            throw TaskRunStoreError.ownershipMismatch
        }
        var updated = run
        if let old = next.runs.first(where: { $0.id == run.id }) {
            guard old.taskID == run.taskID, old.workItemID == run.workItemID,
                  old.sourceID == run.sourceID, old.sourceSessionID == run.sourceSessionID else {
                throw TaskRunStoreError.ownershipMismatch
            }
            if old.outcome != .none {
                // A delayed start may backfill timing, but it cannot reopen or
                // otherwise rewrite the already observed terminal result.
                guard run.startedAt < old.startedAt else { return }
                updated = AnchorRun(
                    id: old.id,
                    taskID: old.taskID,
                    workItemID: old.workItemID,
                    sourceID: old.sourceID,
                    sourceSessionID: old.sourceSessionID,
                    execution: old.execution,
                    attention: old.attention,
                    outcome: old.outcome,
                    startedAt: run.startedAt,
                    finishedAt: old.finishedAt
                )
            } else {
                updated = AnchorRun(
                    id: run.id,
                    taskID: run.taskID,
                    workItemID: run.workItemID,
                    sourceID: run.sourceID,
                    sourceSessionID: run.sourceSessionID,
                    execution: run.execution,
                    attention: run.attention,
                    outcome: run.outcome,
                    startedAt: min(old.startedAt, run.startedAt),
                    finishedAt: run.finishedAt
                )
            }
        }
        next.runs.removeAll { $0.id == run.id }
        next.runs.append(updated)
    }

    private static func eventOrder(_ lhs: AnchorTaskEvent, _ rhs: AnchorTaskEvent) -> Bool {
        if lhs.occurredAt != rhs.occurredAt { return lhs.occurredAt < rhs.occurredAt }
        if lhs.sourceSequence != rhs.sourceSequence { return lhs.sourceSequence < rhs.sourceSequence }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func workItemOrder(_ lhs: AnchorWorkItem, _ rhs: AnchorWorkItem) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func runOrder(_ lhs: AnchorRun, _ rhs: AnchorRun) -> Bool {
        if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func historyOrder(_ lhs: AnchorTask, _ rhs: AnchorTask) -> Bool {
        let lhsDate = lhs.endedAt ?? lhs.createdAt
        let rhsDate = rhs.endedAt ?? rhs.createdAt
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func sameSourceFact(_ lhs: AnchorTaskEvent, _ rhs: AnchorTaskEvent) -> Bool {
        lhs.version == rhs.version
            && lhs.id == rhs.id
            && lhs.taskID == rhs.taskID
            && lhs.workItemID == rhs.workItemID
            && lhs.runID == rhs.runID
            && lhs.sourceID == rhs.sourceID
            && lhs.sourceSessionID == rhs.sourceSessionID
            && lhs.sourceSequence == rhs.sourceSequence
            && lhs.occurredAt == rhs.occurredAt
            && lhs.kind == rhs.kind
    }

    private func persist(_ next: State) throws {
        // Never overwrite an unreadable history or expose an uncommitted in-memory update.
        if let recoveryError { throw recoveryError }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let legacySourceData {
            let backupURL = Self.migrationBackupURL(for: url)
            if FileManager.default.fileExists(atPath: backupURL.path) {
                guard try Data(contentsOf: backupURL) == legacySourceData else {
                    throw TaskRunStoreError.migrationBackupConflict
                }
            } else {
                let temporaryBackupURL = directory.appendingPathComponent(
                    ".task-runs-migration-" + UUID().uuidString + ".tmp"
                )
                defer { try? FileManager.default.removeItem(at: temporaryBackupURL) }
                try legacySourceData.write(to: temporaryBackupURL, options: .atomic)
                do {
                    try FileManager.default.moveItem(
                        at: temporaryBackupURL,
                        to: backupURL
                    )
                } catch {
                    guard FileManager.default.fileExists(atPath: backupURL.path) else {
                        throw error
                    }
                    guard try Data(contentsOf: backupURL) == legacySourceData else {
                        throw TaskRunStoreError.migrationBackupConflict
                    }
                }
            }
        }
        var upgraded = next
        upgraded.schemaVersion = Self.currentSchemaVersion
        let data = try JSONEncoder().encode(upgraded)
        try data.write(to: url, options: .atomic)
        state = upgraded
        legacySourceData = nil
    }
}
