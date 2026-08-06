import Foundation
import Testing
@testable import AnchorCore

@Suite("Process sources and durable sync")
struct ProcessSourceTests {
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

    init(failNextSave: Bool = false) {
        self.failNextSave = failNextSave
    }

    func save(_ envelope: EventEnvelope) throws {
        if failNextSave {
            failNextSave = false
            throw TestTimeout.expired
        }
        stored[envelope.id] = envelope
    }

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
