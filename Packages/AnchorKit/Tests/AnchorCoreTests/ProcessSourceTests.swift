import Foundation
import Testing
@testable import AnchorCore

@Suite("Process sources and durable sync")
struct ProcessSourceTests {
    @Test("A source event for an old session cannot mutate the current Anchor task")
    func coordinatorRejectsOldSessionEvent() async throws {
        let repository = InMemorySessionRepository()
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Current task", completionCriteria: "Untouched"),
                processes: []
            )
        )
        let currentSessionID = try #require(await repository.currentProjection().session?.id)
        let oldSessionID = UUID()
        let sourceID = UUID()
        let event = ExternalProcessEvent(
            sessionID: oldSessionID,
            sourceID: sourceID,
            sequence: 1,
            process: AnchorProcess(
                sessionID: oldSessionID,
                sourceID: sourceID,
                externalID: "old-turn",
                sourceName: "Codex",
                sourceSymbol: "C",
                sourceTone: "cyan",
                title: "Old turn",
                status: .completed
            )
        )
        let source = SimulatedProcessSource(
            descriptor: SourceDescriptor(
                id: sourceID,
                name: "Old Codex session",
                kind: .integration,
                symbol: "C",
                tone: "cyan"
            ),
            script: [event]
        )
        let coordinator = ProcessSourceCoordinator(repository: repository, sources: [source])
        await coordinator.start()
        try await Task.sleep(for: .milliseconds(50))

        let session = try #require(await repository.currentProjection().session)
        #expect(session.id == currentSessionID)
        #expect(session.processes.isEmpty)
        let health = try #require(await coordinator.healthSnapshot().first)
        #expect(health.eventCount == 0)
        #expect(health.consecutiveFailures == 1)
        #expect(health.lastError == ProcessSourceError.sessionMismatch.localizedDescription)
    }

    @Test("A source registered after coordinator start begins observing immediately")
    func coordinatorRegistersSourceAtRuntime() async throws {
        let repository = InMemorySessionRepository()
        try await repository.send(.createSession(goal: AnchorGoal(title: "Test", completionCriteria: "Done"), processes: []))
        let sessionID = try #require(await repository.currentProjection().session?.id)
        let sourceID = UUID()
        let event = ExternalProcessEvent(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 1,
            process: AnchorProcess(
                sessionID: sessionID,
                sourceID: sourceID,
                sourceName: "Codex",
                sourceSymbol: "C",
                sourceTone: "cyan",
                title: "Turn",
                status: .running
            )
        )
        let source = SimulatedProcessSource(
            descriptor: SourceDescriptor(id: sourceID, name: "Codex", kind: .integration, symbol: "C", tone: "cyan"),
            script: [event]
        )
        let coordinator = ProcessSourceCoordinator(repository: repository, sources: [])
        await coordinator.start()
        await coordinator.register(source)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await repository.currentProjection().session?.processes.count == 1)
        #expect(await coordinator.healthSnapshot().first?.descriptor.id == sourceID)
    }

    @Test("A confirmed session association persists an observed run")
    func coordinatorPersistsAssociatedRun() async throws {
        let repository = InMemorySessionRepository()
        try await repository.send(.createSession(goal: AnchorGoal(title: "Test", completionCriteria: "Done"), processes: []))
        let sessionID = try #require(await repository.currentProjection().session?.id)
        let sourceID = UUID(); let taskID = UUID(); let itemID = UUID()
        let process = AnchorProcess(id: UUID(), sessionID: sessionID, sourceID: sourceID,
                                    externalID: "codex-turn-1",
                                    sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                                    title: "Build", status: .completed, updatedAt: .now)
        let event = ExternalProcessEvent(sessionID: sessionID, sourceID: sourceID, sequence: 1, process: process)
        let storeURL = URL.temporaryDirectory.appending(path: "anchor-run-" + UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = TaskRunStore(url: storeURL)
        try await store.upsert(task: AnchorTask(
            id: taskID,
            title: "Test",
            completionCriteria: "Done",
            createdAt: process.updatedAt.addingTimeInterval(-1)
        ))
        try await store.upsert(workItem: AnchorWorkItem(id: itemID, taskID: taskID, title: "Build"))
        let source = SimulatedProcessSource(script: [event])
        let coordinator = ProcessSourceCoordinator(repository: repository, sources: [source], taskRunStore: store)
        try await coordinator.setAssociation(
            AnchorEventAssociation(taskID: taskID, workItemID: itemID, confirmedByUser: true),
            for: sessionID,
            sourceID: sourceID
        )
        await coordinator.start()
        try await Task.sleep(for: .milliseconds(50))
        let snapshot = await store.snapshot()
        #expect(snapshot.runs.count == 1)
        #expect(snapshot.events.count == 1)
        #expect(snapshot.runs.first?.outcome == .completed)
        #expect(snapshot.runs.first?.sourceSessionID == process.externalID)
        try await coordinator.record(event, association: AnchorEventAssociation(taskID: taskID, workItemID: itemID, confirmedByUser: true))
        #expect((await store.snapshot()).runs.count == 1)
        #expect((await store.snapshot()).events.count == 1)
    }

    @Test("A failed task-event commit leaves the Codex checkpoint replayable")
    func coordinatorAcknowledgesCodexOnlyAfterTaskEventCommit() async throws {
        let directory = URL.temporaryDirectory.appending(
            path: "anchor-codex-commit-order-" + UUID().uuidString
        )
        let lifecycleURL = directory.appending(path: "session.jsonl")
        let checkpointURL = directory.appending(path: "checkpoints.json")
        let taskStoreURL = directory.appending(path: "task-runs.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let repository = InMemorySessionRepository()
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Commit ordering", completionCriteria: "Replayed"),
                processes: []
            )
        )
        let sessionID = try #require(await repository.currentProjection().session?.id)
        let task = AnchorTask(
            id: sessionID,
            title: "Commit ordering",
            completionCriteria: "Replayed",
            createdAt: .distantPast
        )
        let item = AnchorWorkItem(taskID: task.id, title: "Codex conversation")
        let taskStore = TaskRunStore(url: taskStoreURL)
        try await taskStore.upsert(task: task)
        try await taskStore.upsert(workItem: item)

        let checkpointStore = CodexLifecycleCheckpointStore(storageURL: checkpointURL)
        let context = ProcessSourceSessionContext(
            sessionID: sessionID,
            startedAt: .distantPast
        )
        let line = #"{"timestamp":"2026-09-09T01:02:03.123Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"commit-order"}}"# + "\n"
        try Data(line.utf8).write(to: lifecycleURL)

        let firstSource = CodexLifecycleFileSource(
            fileURL: lifecycleURL,
            pollInterval: 0.02,
            sessionContextProvider: { context },
            checkpointStore: checkpointStore
        )
        let firstCoordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: [firstSource],
            taskRunStore: taskStore
        )
        try await firstCoordinator.setAssociation(
            AnchorEventAssociation(
                taskID: task.id,
                workItemID: item.id,
                confirmedByUser: true
            ),
            for: sessionID,
            sourceID: firstSource.descriptor.id
        )

        // Keep the actor's valid in-memory state while making its next atomic
        // file replacement fail as if local storage became temporarily unavailable.
        try FileManager.default.removeItem(at: taskStoreURL)
        try FileManager.default.createDirectory(
            at: taskStoreURL,
            withIntermediateDirectories: false
        )
        let failedHealth = await firstCoordinator.healthChanges()
        await firstCoordinator.start()
        try await waitForHealthStatus(in: failedHealth, status: .failed)

        #expect((await taskStore.snapshot()).events.isEmpty)
        #expect(
            try await checkpointStore.load(
                for: CodexLifecycleFileSource.checkpointKey(for: firstSource.descriptor.id)
            ) == nil
        )
        await firstCoordinator.stop()

        try FileManager.default.removeItem(at: taskStoreURL)
        let restartedSource = CodexLifecycleFileSource(
            fileURL: lifecycleURL,
            pollInterval: 0.02,
            sessionContextProvider: { context },
            checkpointStore: checkpointStore
        )
        let restartedCoordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: [restartedSource],
            taskRunStore: taskStore
        )
        let recoveredHealth = await restartedCoordinator.healthChanges()
        await restartedCoordinator.start()
        try await waitForHealthEvent(in: recoveredHealth)

        #expect((await taskStore.snapshot()).events.count == 1)
        #expect((await taskStore.snapshot()).runs.first?.outcome == .completed)
        #expect(
            try await checkpointStore.load(
                for: CodexLifecycleFileSource.checkpointKey(for: restartedSource.descriptor.id)
            ) != nil
        )
        await restartedCoordinator.stop()
    }

    @Test("A source association cannot capture another source in the same Anchor session")
    func coordinatorScopesAssociationToSource() async throws {
        let repository = InMemorySessionRepository()
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
                processes: []
            )
        )
        let sessionID = try #require(await repository.currentProjection().session?.id)
        let codexSourceID = UUID()
        let workspaceSourceID = UUID()
        let task = AnchorTask(id: sessionID, title: "Test", completionCriteria: "Done")
        let item = AnchorWorkItem(taskID: task.id, title: "Codex conversation")
        let storeURL = URL.temporaryDirectory.appending(path: "anchor-source-scope-" + UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = TaskRunStore(url: storeURL)
        try await store.upsert(task: task)
        try await store.upsert(workItem: item)

        func event(sourceID: UUID, externalID: String) -> ExternalProcessEvent {
            ExternalProcessEvent(
                sessionID: sessionID,
                sourceID: sourceID,
                sequence: 1,
                process: AnchorProcess(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    externalID: externalID,
                    sourceName: externalID,
                    sourceSymbol: "S",
                    sourceTone: "cyan",
                    title: externalID,
                    status: .running
                )
            )
        }
        let sources = [
            ImmediateSource(
                descriptor: SourceDescriptor(id: codexSourceID, name: "Codex", kind: .integration, symbol: "C", tone: "cyan"),
                event: event(sourceID: codexSourceID, externalID: "codex-turn")
            ),
            ImmediateSource(
                descriptor: SourceDescriptor(id: workspaceSourceID, name: "Mac", kind: .manual, symbol: "M", tone: "slate"),
                event: event(sourceID: workspaceSourceID, externalID: "workspace-app")
            ),
        ]
        let coordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: sources,
            taskRunStore: store
        )
        try await coordinator.setAssociation(
            AnchorEventAssociation(taskID: task.id, workItemID: item.id, confirmedByUser: true),
            for: sessionID,
            sourceID: codexSourceID
        )
        await coordinator.start()
        try await Task.sleep(for: .milliseconds(100))

        let runs = await store.snapshot().runs
        #expect(runs.count == 1)
        #expect(runs.first?.sourceID == codexSourceID.uuidString)
        #expect(runs.first?.sourceSessionID == "codex-turn")
    }

    @Test("A normalized source event reaches the local repository exactly once")
    func coordinatorIngestsOneEvent() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-source-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storage) }

        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let sessionGoal = AnchorGoal(title: "Source goal", completionCriteria: "Observed")
        try await repository.send(.createSession(goal: sessionGoal, processes: []))
        let sessionID = try #require(await repository.currentProjection().session?.id)
        let sourceID = UUID()
        let processID = UUID()
        let process = AnchorProcess(
            id: processID,
            sessionID: sessionID,
            sourceID: sourceID,
            sourceName: "CLI",
            sourceSymbol: "C",
            sourceTone: "cyan",
            title: "Render",
            status: .running,
            progress: 0.4,
            updatedAt: .now
        )
        let event = ExternalProcessEvent(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 1,
            process: process,
            event: ProcessEvent(
                sessionID: sessionID,
                processID: processID,
                sourceID: sourceID,
                kind: .progress,
                title: "Render is halfway"
            ),
            deduplicationKey: "render-1"
        )
        let source = ImmediateSource(
            descriptor: SourceDescriptor(
                id: sourceID,
                name: "CLI",
                kind: .cli,
                symbol: "C",
                tone: "cyan"
            ),
            event: event
        )
        let coordinator = ProcessSourceCoordinator(repository: repository, sources: [source])
        let healthStream = await coordinator.healthChanges()
        await coordinator.start()

        try await waitForHealthEvent(in: healthStream)
        let projection = await repository.currentProjection()
        #expect(projection.session?.processes.first?.progress == 0.4)
        #expect(projection.session?.timeline.count == 1)
        #expect((await coordinator.healthSnapshot()).first?.eventCount == 1)
    }

    @Test("The file source consumes an atomically queued external event")
    func fileSourceMovesConsumedFile() async throws {
        let inbox = URL.temporaryDirectory.appending(path: "anchor-inbox-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: inbox) }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let sessionID = UUID()
        let sourceID = UUID()
        let event = ExternalProcessEvent(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 1,
            process: AnchorProcess(
                id: UUID(),
                sourceID: sourceID,
                sourceName: "CLI",
                sourceSymbol: "C",
                sourceTone: "cyan",
                title: "Queued process",
                status: .running,
                progress: 0.2
            )
        )
        let file = inbox.appending(path: "\(event.id.uuidString).json")
        try JSONEncoder.anchorExternal.encode(event).write(to: file, options: .atomic)

        let source = FileProcessSource(directoryURL: inbox, pollInterval: 0.05)
        let reader = ThrowingStreamReader(source.events())
        let received = try await withThrowingTaskGroup(of: ExternalProcessEvent.self) { group in
            group.addTask {
                guard let value = try await reader.first() else { throw TestTimeout.expired }
                return value
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TestTimeout.expired
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }

        #expect(received.id == event.id)
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".processed/\(event.id.uuidString).json").path))
    }

    @Test("A quarantined inbox item does not block a later valid event")
    func invalidInboxItemDoesNotStopSource() async throws {
        let inbox = URL.temporaryDirectory.appending(path: "anchor-invalid-inbox-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: inbox) }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let invalidFile = inbox.appending(path: "000-invalid.json")
        try Data("{not-json".utf8).write(to: invalidFile, options: .atomic)

        let event = ExternalProcessEvent(
            sessionID: UUID(),
            sourceID: UUID(),
            sequence: 1,
            process: AnchorProcess(
                id: UUID(),
                sourceName: "CLI",
                sourceSymbol: "C",
                sourceTone: "cyan",
                title: "Valid process",
                status: .running,
                progress: 0.5
            )
        )
        let validFile = inbox.appending(path: "001-valid.json")
        try JSONEncoder.anchorExternal.encode(event).write(to: validFile, options: .atomic)

        let source = FileProcessSource(directoryURL: inbox, pollInterval: 0.02)
        let reader = ThrowingStreamReader(source.events())
        let received = try await withThrowingTaskGroup(of: ExternalProcessEvent.self) { group in
            group.addTask {
                guard let value = try await reader.first() else { throw TestTimeout.expired }
                return value
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TestTimeout.expired
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }

        #expect(received.id == event.id)
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".failed/000-invalid.json").path))
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".processed/001-valid.json").path))
    }

    @Test("A source waits for a session and resumes a requeued event")
    func sourceResumesAfterSessionCreation() async throws {
        let inbox = URL.temporaryDirectory.appending(path: "anchor-waiting-inbox-\(UUID().uuidString)")
        let storage = URL.temporaryDirectory.appending(path: "anchor-waiting-store-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: inbox)
            try? FileManager.default.removeItem(at: storage)
        }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let sessionID = UUID()
        let sourceID = UUID()
        let processID = UUID()
        let event = ExternalProcessEvent(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 1,
            process: AnchorProcess(
                id: processID,
                sessionID: sessionID,
                sourceID: sourceID,
                sourceName: "CLI",
                sourceSymbol: "C",
                sourceTone: "cyan",
                title: "Waiting process",
                status: .running,
                progress: 0.7
            )
        )
        try JSONEncoder.anchorExternal.encode(event).write(
            to: inbox.appending(path: "\(event.id.uuidString).json"),
            options: .atomic
        )

        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let source = FileProcessSource(directoryURL: inbox, pollInterval: 0.02)
        let coordinator = ProcessSourceCoordinator(repository: repository, sources: [source])
        let waitingStream = await coordinator.healthChanges()
        await coordinator.start()
        try await waitForHealthStatus(in: waitingStream, status: .waitingForSession)

        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: "\(event.id.uuidString).json").path))
        #expect(await repository.pendingEvents().isEmpty)

        let session = AnchorSession(
            id: sessionID,
            goal: AnchorGoal(title: "Recovered goal", completionCriteria: "Observed")
        )
        let sessionEnvelope = EventEnvelope(
            sessionID: sessionID,
            sourceID: UUID(),
            sequence: 1,
            type: "session.projection.v1",
            payload: try JSONEncoder.anchor.encode(session)
        )
        try await repository.applyRemote(sessionEnvelope)

        let resumedStream = await coordinator.healthChanges()
        try await waitForHealthEvent(in: resumedStream)
        let projection = await repository.currentProjection()
        #expect(projection.session?.id == sessionID)
        #expect(projection.session?.processes.first?.id == processID)
        #expect(projection.session?.processes.first?.progress == 0.7)
        await coordinator.stop()
    }

    @Test("A source action is routed through the coordinator")
    func sourceActionIsRouted() async throws {
        let sourceID = UUID()
        let recorder = ActionRecorder()
        let source = RecordingActionSource(
            descriptor: SourceDescriptor(
                id: sourceID,
                name: "Action source",
                kind: .integration,
                symbol: "A",
                tone: "periwinkle",
                capabilities: [.observe, .resolveDecision]
            ),
            recorder: recorder
        )
        let coordinator = ProcessSourceCoordinator(
            repository: InMemorySessionRepository(),
            sources: [source]
        )
        let decisionID = UUID()
        let optionID = UUID()

        let receipt = try await coordinator.perform(
            .resolveDecision(decisionID: decisionID, optionID: optionID),
            on: sourceID
        )

        #expect(receipt.sourceID == sourceID)
        #expect(await recorder.action == .resolveDecision(decisionID: decisionID, optionID: optionID))
    }

    @Test("A failed durable upload leaves the event in the local outbox")
    func durableSyncRetriesAfterFailure() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-sync-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storage) }
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Sync goal", completionCriteria: "Uploaded"),
                processes: []
            )
        )
        let remote = FakeDurableEventStore(failNextSave: true)
        let synchronizer = DurableEventSynchronizer(local: repository, remote: remote)

        await #expect(throws: TestTimeout.self) {
            try await synchronizer.sync()
        }
        #expect(await repository.pendingEvents().count == 1)

        let report = try await synchronizer.sync()
        #expect(report.uploadedCount == 1)
        #expect(await repository.pendingEvents().isEmpty)
        #expect(await remote.count() == 1)
    }

    @Test("The durable sync runner publishes recovery states")
    func durableSyncRunnerStates() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-runner-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storage) }
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Runner goal", completionCriteria: "Available"),
                processes: []
            )
        )
        let remote = FakeDurableEventStore()
        let runner = DurableSyncRunner(
            synchronizer: DurableEventSynchronizer(local: repository, remote: remote),
            interval: 5
        )
        let stream = await runner.statusChanges()
        let reader = DurableStateReader(stream)

        let report = await runner.syncNow()
        #expect(report?.uploadedCount == 1)
        try await waitForDurableState(in: reader, expected: .available)
        #expect(await runner.currentState() == .available)

        await runner.stop()
        #expect(await runner.currentState() == .idle)
    }

    @Test("A second device discovers and restores the current iCloud session")
    func durableSyncDiscoversCurrentSession() async throws {
        let sourceURL = URL.temporaryDirectory.appending(
            path: "anchor-cloud-source-\(UUID().uuidString).json"
        )
        let targetURL = URL.temporaryDirectory.appending(
            path: "anchor-cloud-target-\(UUID().uuidString).json"
        )
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: targetURL)
        }
        let source = LocalSessionRepository(storageURL: sourceURL, sourceID: UUID())
        let target = LocalSessionRepository(storageURL: targetURL, sourceID: UUID())
        let remote = FakeDurableEventStore()
        try await source.send(
            .createSession(
                goal: AnchorGoal(
                    title: "Cloud discovery",
                    completionCriteria: "The second device restores it"
                ),
                processes: []
            )
        )

        let upload = DurableEventSynchronizer(local: source, remote: remote)
        let download = DurableEventSynchronizer(local: target, remote: remote)
        #expect(try await upload.sync().uploadedCount == 1)
        #expect(await target.currentProjection().session == nil)

        let report = try await download.sync()
        #expect(report.downloadedCount == 1)
        #expect(await target.currentProjection().session?.goal.title == "Cloud discovery")
        let targetSessionID = await target.currentProjection().session?.id
        let sourceSessionID = await source.currentProjection().session?.id
        #expect(targetSessionID == sourceSessionID)
    }

    private func waitForHealthEvent(
        in stream: AsyncStream<[SourceHealth]>
    ) async throws {
        let reader = HealthStreamReader(stream)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                await reader.waitForEventCount(1)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TestTimeout.expired
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func waitForHealthStatus(
        in stream: AsyncStream<[SourceHealth]>,
        status: SourceHealthStatus
    ) async throws {
        let reader = HealthStreamReader(stream)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                guard await reader.waitForStatus(status) else { throw TestTimeout.expired }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TestTimeout.expired
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func waitForDurableState(
        in reader: DurableStateReader,
        expected: DurableSyncState
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                guard await reader.waitFor(expected) else { throw TestTimeout.expired }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw TestTimeout.expired
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }
}

private struct ImmediateSource: ProcessSource {
    let descriptor: SourceDescriptor
    let event: ExternalProcessEvent

    func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(event)
            continuation.finish()
        }
    }
}

private struct RecordingActionSource: ProcessSource {
    let descriptor: SourceDescriptor
    let recorder: ActionRecorder

    func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func perform(_ action: SourceAction) async throws -> SourceActionReceipt {
        await recorder.record(action)
        return SourceActionReceipt(sourceID: descriptor.id, action: action)
    }
}

private actor ActionRecorder {
    private(set) var action: SourceAction?

    func record(_ action: SourceAction) {
        self.action = action
    }
}

private actor FakeDurableEventStore: DurableEventStore {
    private var stored: [UUID: EventEnvelope] = [:]
    private var failNextSave: Bool
    private var activeSessionID: UUID?

    init(failNextSave: Bool = false) {
        self.failNextSave = failNextSave
    }

    func save(_ envelope: EventEnvelope) throws {
        if failNextSave {
            failNextSave = false
            throw TestTimeout.expired
        }
        stored[envelope.id] = envelope
        if let operation = try? JSONDecoder.anchor.decode(
            SessionOperation.self,
            from: envelope.payload
        ), case .createSession = operation {
            activeSessionID = envelope.sessionID
        }
    }

    func currentSessionID() -> UUID? { activeSessionID }

    func events(for sessionID: UUID, onOrAfter date: Date?) -> [EventEnvelope] {
        stored.values.filter {
            $0.sessionID == sessionID && (date == nil || $0.timestamp >= date!)
        }
    }

    func count() -> Int { stored.count }
}

private enum TestTimeout: Error {
    case expired
}

private actor ThrowingStreamReader<Element: Sendable> {
    private let stream: AsyncThrowingStream<Element, Error>

    init(_ stream: AsyncThrowingStream<Element, Error>) {
        self.stream = stream
    }

    func first() async throws -> Element? {
        for try await value in stream {
            return value
        }
        return nil
    }
}

private actor HealthStreamReader {
    private let stream: AsyncStream<[SourceHealth]>

    init(_ stream: AsyncStream<[SourceHealth]>) {
        self.stream = stream
    }

    func waitForEventCount(_ count: Int) async {
        for await health in stream {
            if health.first?.eventCount == count { return }
        }
    }

    func waitForStatus(_ status: SourceHealthStatus) async -> Bool {
        for await health in stream {
            if health.first?.status == status { return true }
        }
        return false
    }
}

private actor DurableStateReader {
    private let stream: AsyncStream<DurableSyncState>

    init(_ stream: AsyncStream<DurableSyncState>) {
        self.stream = stream
    }

    func waitFor(_ expected: DurableSyncState) async -> Bool {
        for await state in stream {
            if state == expected { return true }
        }
        return false
    }
}
