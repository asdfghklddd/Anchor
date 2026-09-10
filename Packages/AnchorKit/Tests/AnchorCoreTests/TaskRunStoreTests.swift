import Foundation
import Testing
@testable import AnchorCore

@Test("Archival survives restart and rejects late runs, reopening and reparenting")
func archivedTaskIsImmutable() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.json")
    let task = AnchorTask(title: "Original", completionCriteria: "Done", createdAt: Date(timeIntervalSince1970: 1))
    let item = AnchorWorkItem(taskID: task.id, title: "Work")
    let run = AnchorRun(taskID: task.id, workItemID: item.id, sourceID: "codex", execution: .running)
    let store = TaskRunStore(url: url)
    await #expect(throws: TaskRunStoreError.taskNotFound) { try await store.upsert(workItem: item) }
    try await store.upsert(task: task)
    await #expect(throws: TaskRunStoreError.ownershipMismatch) { try await store.upsert(run: run) }
    try await store.upsert(workItem: item)
    try await store.upsert(run: run)
    let ended = Date(timeIntervalSince1970: 20)
    try await store.confirmTaskEnded(taskID: task.id, at: ended)
    let before = try Data(contentsOf: url)
    let restored = TaskRunStore(url: url)
    await #expect(throws: TaskRunStoreError.taskArchived) { try await restored.upsert(run: run) }
    await #expect(throws: TaskRunStoreError.taskArchived) { try await restored.upsert(task: task) }
    #expect(try Data(contentsOf: url) == before)
    let history = await restored.snapshot()
    #expect(history.tasks.first?.endedAt == ended)
    #expect(history.runs == [run])

    let next = AnchorTask(title: "New goal", completionCriteria: "Done")
    try await restored.upsert(task: next)
    let moved = AnchorWorkItem(id: item.id, taskID: next.id, title: "Moved")
    await #expect(throws: TaskRunStoreError.ownershipMismatch) { try await restored.upsert(workItem: moved) }
    let fresh = AnchorWorkItem(taskID: next.id, title: "New work")
    try await restored.upsert(workItem: fresh)
    #expect(await restored.snapshot().workItems.count == 2)
}

@Test("One foreground task is separated from complete archived history")
func currentTaskAndHistoryAreSeparated() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("task-history.json")
    let store = TaskRunStore(url: url)
    let firstTask = AnchorTask(
        title: "First task",
        completionCriteria: "First result",
        createdAt: Date(timeIntervalSince1970: 10)
    )
    let firstItem = AnchorWorkItem(
        taskID: firstTask.id,
        title: "Codex conversation",
        createdAt: Date(timeIntervalSince1970: 11)
    )
    let firstRun = AnchorRun(
        taskID: firstTask.id,
        workItemID: firstItem.id,
        sourceID: "codex",
        sourceSessionID: "first-turn",
        execution: .idle,
        outcome: .completed,
        startedAt: Date(timeIntervalSince1970: 12),
        finishedAt: Date(timeIntervalSince1970: 13)
    )
    let firstEvent = AnchorTaskEvent(
        taskID: firstTask.id,
        workItemID: firstItem.id,
        runID: firstRun.id,
        sourceID: firstRun.sourceID,
        sourceSessionID: firstRun.sourceSessionID,
        sourceSequence: 1,
        occurredAt: Date(timeIntervalSince1970: 13),
        kind: .completed
    )
    try await store.activate(task: firstTask)
    try await store.upsert(workItem: firstItem)
    try await store.record(event: firstEvent, run: firstRun)
    try await store.confirmTaskEnded(
        taskID: firstTask.id,
        at: Date(timeIntervalSince1970: 20)
    )

    let secondTask = AnchorTask(
        title: "Second task",
        completionCriteria: "Second result",
        createdAt: Date(timeIntervalSince1970: 30)
    )
    try await store.activate(task: secondTask)

    let current = try #require(await store.currentTaskRecord())
    #expect(current.task == secondTask)
    #expect(current.workItems.isEmpty)
    let history = await store.taskHistory()
    #expect(history.count == 1)
    #expect(history.first?.task.id == firstTask.id)
    #expect(history.first?.workItems == [firstItem])
    #expect(history.first?.runs == [firstRun])
    #expect(history.first?.events == [firstEvent])
    #expect(history.first?.state.lifecycle == .archived)

    let restored = TaskRunStore(url: url)
    #expect(await restored.currentTaskRecord()?.task.id == secondTask.id)
    #expect(await restored.taskHistory() == history)
}

@Test("A second foreground task is rejected unless the transition is explicit")
func implicitSecondForegroundTaskIsRejected() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("single-current-task.json")
    let store = TaskRunStore(url: url)
    let first = AnchorTask(title: "First", completionCriteria: "Done")
    let second = AnchorTask(title: "Second", completionCriteria: "Done")
    try await store.upsert(task: first)
    let bytesBeforeRejectedWrite = try Data(contentsOf: url)

    await #expect(throws: TaskRunStoreError.activeTaskConflict) {
        try await store.upsert(task: second)
    }

    #expect(try Data(contentsOf: url) == bytesBeforeRejectedWrite)
    #expect(await store.currentTaskRecord()?.task == first)
    #expect(await store.taskHistory().isEmpty)
}

@Test("An older task cannot replace a newer foreground task")
func outOfOrderActivationCannotReplaceCurrentTask() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("ordered-task-boundary.json")
    let store = TaskRunStore(url: url)
    let newer = AnchorTask(
        title: "Newer task",
        completionCriteria: "New result",
        createdAt: Date(timeIntervalSince1970: 30)
    )
    let older = AnchorTask(
        title: "Delayed older task",
        completionCriteria: "Old result",
        createdAt: Date(timeIntervalSince1970: 10)
    )
    try await store.activate(task: newer)
    let bytesBeforeRejectedWrite = try Data(contentsOf: url)

    await #expect(throws: TaskRunStoreError.activeTaskConflict) {
        try await store.activate(task: older)
    }

    #expect(try Data(contentsOf: url) == bytesBeforeRejectedWrite)
    #expect(await store.currentTaskRecord()?.task == newer)
    #expect(await store.taskHistory().isEmpty)
}

@Test("Confirmed session association persists and unconfirmed mapping is rejected")
func sessionAssociationPersists() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("bindings.json")
    let task = AnchorTask(title: "Task", completionCriteria: "Done")
    let item = AnchorWorkItem(taskID: task.id, title: "Codex turn")
    let sessionID = UUID()
    let sourceID = UUID()
    let store = TaskRunStore(url: url)
    try await store.upsert(task: task)
    try await store.upsert(workItem: item)
    await #expect(throws: TaskRunStoreError.confirmationRequired) {
        try await store.confirmAssociation(AnchorSessionAssociation(
            sessionID: sessionID,
            sourceID: sourceID,
            target: AnchorEventAssociation(taskID: task.id, workItemID: item.id)
        ))
    }
    let confirmed = AnchorSessionAssociation(
        sessionID: sessionID,
        sourceID: sourceID,
        target: AnchorEventAssociation(taskID: task.id, workItemID: item.id, confirmedByUser: true)
    )
    try await store.confirmAssociation(confirmed)
    #expect(await TaskRunStore(url: url).associations() == [confirmed])
}

@Test("Legacy session-only associations decode but cannot be confirmed without a source")
func legacySessionAssociationRequiresSourceIdentity() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("legacy-bindings.json")
    let task = AnchorTask(title: "Task", completionCriteria: "Done")
    let item = AnchorWorkItem(taskID: task.id, title: "Codex turn")
    let current = AnchorSessionAssociation(
        sessionID: UUID(),
        sourceID: UUID(),
        target: AnchorEventAssociation(taskID: task.id, workItemID: item.id, confirmedByUser: true),
        confirmedAt: Date(timeIntervalSince1970: 1)
    )
    var legacyObject = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
    )
    legacyObject.removeValue(forKey: "sourceID")
    let legacy = try JSONDecoder().decode(
        AnchorSessionAssociation.self,
        from: JSONSerialization.data(withJSONObject: legacyObject)
    )
    #expect(legacy.sourceID == nil)

    let store = TaskRunStore(url: url)
    try await store.upsert(task: task)
    try await store.upsert(workItem: item)
    await #expect(throws: TaskRunStoreError.sourceIdentityRequired) {
        try await store.confirmAssociation(legacy)
    }
    #expect(await store.associations().isEmpty)
}

@Test("Task run store survives a new repository instance")
func taskRunStorePersistsHierarchy() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("task-runs.json")
    let task = AnchorTask(title: "Build module", completionCriteria: "Tests pass")
    let item = AnchorWorkItem(taskID: task.id, title: "Implement parser")
    let run = AnchorRun(taskID: task.id, workItemID: item.id, sourceID: "com.openai.codex", execution: .running)
    let first = TaskRunStore(url: url)
    try await first.upsert(task: task); try await first.upsert(workItem: item); try await first.upsert(run: run)
    let second = TaskRunStore(url: url)
    let snapshot = await second.snapshot()
    #expect(snapshot.tasks == [task]); #expect(snapshot.workItems == [item]); #expect(snapshot.runs == [run])
}

@Test("Persisted run history exposes the same reactivated work item state after restart")
func persistedWorkItemProjectionSurvivesRestart() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("task-runs.json")
    let task = AnchorTask(title: "Build observer", completionCriteria: "Validated")
    let item = AnchorWorkItem(taskID: task.id, title: "Codex task", generation: 2)
    let failed = AnchorRun(
        taskID: task.id,
        workItemID: item.id,
        sourceID: "com.openai.codex",
        sourceSessionID: "turn-one",
        execution: .idle,
        outcome: .failed,
        startedAt: Date(timeIntervalSince1970: 10),
        finishedAt: Date(timeIntervalSince1970: 20)
    )
    let retry = AnchorRun(
        taskID: task.id,
        workItemID: item.id,
        sourceID: "com.openai.codex",
        sourceSessionID: "turn-two",
        execution: .running,
        attention: [.needsInput],
        startedAt: Date(timeIntervalSince1970: 30)
    )
    let store = TaskRunStore(url: url)
    try await store.upsert(task: task)
    try await store.upsert(workItem: item)
    try await store.upsert(run: failed)
    try await store.upsert(run: retry)

    let restored = TaskRunStore(url: url)
    let projection = try #require(await restored.workItemState(id: item.id))
    #expect(projection.execution == .running)
    #expect(projection.outcome == .none)
    #expect(projection.attention == [.hasFailure, .needsInput])
    #expect(projection.generation == 3)
    #expect(projection.runCount == 2)
    #expect(await restored.workItemStates(taskID: task.id) == [projection])
    let taskProjection = try #require(await restored.taskState(id: task.id))
    #expect(taskProjection.lifecycle == .active)
    #expect(taskProjection.execution == .running)
    #expect(taskProjection.attention == [.hasFailure, .needsInput])
    #expect(taskProjection.outcome == .none)
    #expect(taskProjection.workItemCount == 1)
    #expect(taskProjection.runCount == 2)
}

@Test("Different phase events update one run and late starts cannot undo completion after restart")
func phaseIdentityPersistsAcrossRestart() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("runs.json")
    let session = UUID()
    let source = UUID()
    let association = AnchorEventAssociation(taskID: UUID(), workItemID: UUID(), confirmedByUser: true)
    func event(_ phase: String, at: String) throws -> ExternalProcessEvent {
        let json = #"{"timestamp":"DATE","type":"event_msg","payload":{"type":"PHASE","turn_id":"one-turn"}}"#
            .replacingOccurrences(of: "DATE", with: at).replacingOccurrences(of: "PHASE", with: phase)
        return try #require(CodexLifecycleRecord(json: Data(json.utf8))).externalEvent(sessionID: session, sourceID: source)
    }
    let start = try event("task_started", at: "2026-09-05T01:02:03.123Z")
    let finish = try event("task_complete", at: "2026-09-05T01:03:03.123Z")
    #expect(start.id != finish.id)
    let store = TaskRunStore(url: url)
    try await store.upsert(task: AnchorTask(id: association.taskID, title: "Task", completionCriteria: "Done"))
    try await store.upsert(workItem: AnchorWorkItem(id: association.workItemID, taskID: association.taskID, title: "Turn"))
    try await store.upsert(run: start.makeRun(association: association))
    try await store.upsert(run: finish.makeRun(association: association))
    let restored = TaskRunStore(url: url)
    try await restored.upsert(run: start.makeRun(association: association))
    let runs = await restored.snapshot().runs
    #expect(runs.count == 1)
    #expect(runs.first?.outcome == .completed)
    #expect(runs.first?.startedAt == start.occurredAt)
    #expect(runs.first?.finishedAt == finish.occurredAt)
    #expect(runs.first?.sourceSessionID == "one-turn")
}

@Test("Persistence errors preserve memory and unreadable saved bytes")
func failedPersistenceDoesNotCommit() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocked = directory.appendingPathComponent("parent-file")
    try Data("block".utf8).write(to: blocked)
    let store = TaskRunStore(url: blocked.appendingPathComponent("runs.json"))
    let task = AnchorTask(title: "Task", completionCriteria: "Done")
    await #expect(throws: (any Error).self) { try await store.upsert(task: task) }
    #expect(await store.snapshot().tasks.isEmpty)

    let corrupt = directory.appendingPathComponent("corrupt.json")
    let original = Data("unreadable-history".utf8)
    try original.write(to: corrupt)
    let protected = TaskRunStore(url: corrupt)
    await #expect(throws: (any Error).self) { try await protected.upsert(task: task) }
    #expect(try Data(contentsOf: corrupt) == original)
    #expect(await protected.snapshot().tasks.isEmpty)
}

@Test("Legacy task history upgrades with an exact recovery backup")
func legacyTaskHistoryMigratesWithBackup() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("task-runs.json")
    let task = AnchorTask(title: "Legacy task", completionCriteria: "Preserved")
    let item = AnchorWorkItem(taskID: task.id, title: "Legacy work")
    let initial = TaskRunStore(url: url)
    try await initial.upsert(task: task)
    try await initial.upsert(workItem: item)

    var legacyObject = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
    legacyObject.removeValue(forKey: "schemaVersion")
    legacyObject.removeValue(forKey: "events")
    let legacyBytes = try JSONSerialization.data(
        withJSONObject: legacyObject,
        options: [.sortedKeys]
    )
    try legacyBytes.write(to: url, options: .atomic)

    let migrated = TaskRunStore(url: url)
    #expect(await migrated.snapshot().tasks == [task])
    #expect(await migrated.snapshot().workItems == [item])
    try await migrated.confirmTaskEnded(taskID: task.id, at: .now)
    let newTask = AnchorTask(title: "Current task", completionCriteria: "Stored")
    try await migrated.upsert(task: newTask)

    let backupURL = TaskRunStore.migrationBackupURL(for: url)
    #expect(try Data(contentsOf: backupURL) == legacyBytes)
    let upgradedObject = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
    #expect(upgradedObject["schemaVersion"] as? Int == TaskRunStore.currentSchemaVersion)
    #expect(upgradedObject["events"] != nil)

    let restoredFromBackup = TaskRunStore(url: backupURL)
    #expect(await restoredFromBackup.snapshot().tasks == [task])
    #expect(await restoredFromBackup.snapshot().workItems == [item])
}

@Test("A future task history version is rejected without overwriting its bytes")
func futureTaskHistoryIsProtected() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("future.json")
    let first = TaskRunStore(url: url)
    try await first.upsert(task: AnchorTask(title: "Future", completionCriteria: "Protected"))
    var object = try #require(
        JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    )
    object["schemaVersion"] = TaskRunStore.currentSchemaVersion + 1
    let futureBytes = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    try futureBytes.write(to: url, options: .atomic)

    let protected = TaskRunStore(url: url)
    await #expect(
        throws: TaskRunStoreError.unsupportedSchemaVersion(
            TaskRunStore.currentSchemaVersion + 1
        )
    ) {
        try await protected.upsert(
            task: AnchorTask(title: "Must not write", completionCriteria: "Rejected")
        )
    }
    #expect(try Data(contentsOf: url) == futureBytes)
    #expect(
        !FileManager.default.fileExists(
            atPath: TaskRunStore.migrationBackupURL(for: url).path
        )
    )
}
