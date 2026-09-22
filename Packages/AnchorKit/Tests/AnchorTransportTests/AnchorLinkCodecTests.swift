import AnchorCore
import CryptoKit
import Foundation
import Security
import Testing
@testable import AnchorTransport

@Suite("Local link codec", .serialized)
struct AnchorLinkCodecTests {
    @Test("Both pairing peers derive the same encrypted channel")
    func pairingKeyAgreement() throws {
        let client = Curve25519.KeyAgreement.PrivateKey()
        let server = Curve25519.KeyAgreement.PrivateKey()
        let clientID = UUID()
        let serverID = UUID()
        let clientKey = try AnchorLinkCodec.deriveKey(
            privateKey: client,
            peerPublicKey: server.publicKey.rawRepresentation,
            pairingCode: "123456",
            clientID: clientID,
            serverID: serverID
        )
        let serverKey = try AnchorLinkCodec.deriveKey(
            privateKey: server,
            peerPublicKey: client.publicKey.rawRepresentation,
            pairingCode: "123456",
            clientID: clientID,
            serverID: serverID
        )
        #expect(clientKey == serverKey)
    }

    @Test("Authenticated payload round-trips and rejects the wrong key")
    func sealedPayload() throws {
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrongKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let event = EventEnvelope(
            sessionID: UUID(),
            sourceID: UUID(),
            sequence: 1,
            type: "test",
            payload: Data("hello".utf8)
        )
        let sealed = try AnchorLinkCodec.seal(LinkPayload(kind: .event, event: event), using: key)
        let opened = try AnchorLinkCodec.open(sealed, using: key)

        #expect(opened.event == event)
        #expect(throws: (any Error).self) {
            _ = try AnchorLinkCodec.open(sealed, using: wrongKey)
        }
    }

    @Test("The replay window rejects a duplicate message")
    func replayWindowRejectsDuplicate() {
        var window = LinkReplayWindow()
        let messageID = UUID()

        let firstAcceptance = window.accepts(messageID)
        let secondAcceptance = window.accepts(messageID)
        #expect(firstAcceptance)
        #expect(!secondAcceptance)
    }

    @Test("Pairing accepts only the six ASCII digits shown by the Mac")
    func pairingCodeAlphabet() {
        let client = Curve25519.KeyAgreement.PrivateKey()
        let server = Curve25519.KeyAgreement.PrivateKey()

        #expect(throws: AnchorLinkError.self) {
            _ = try AnchorLinkCodec.deriveKey(
                privateKey: client,
                peerPublicKey: server.publicKey.rawRepresentation,
                pairingCode: "１２３４５６",
                clientID: UUID(),
                serverID: UUID()
            )
        }
    }

    @Test("A session payload must match its envelope session ID")
    func sessionEnvelopeValidation() throws {
        let session = AnchorSession(goal: AnchorGoal(title: "Test", completionCriteria: "Done"))
        let envelope = EventEnvelope(
            sessionID: UUID(),
            sourceID: UUID(),
            sequence: 1,
            type: "session.projection.v1",
            payload: try JSONEncoder.anchor.encode(session)
        )

        #expect(LinkedSessionDecoder.session(from: envelope) == nil)
    }

    @Test("Sending without an authenticated peer reports failure")
    func unauthenticatedSendFails() async {
        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: "com.andywang.anchor.tests.\(UUID().uuidString)")
        )
        let event = EventEnvelope(
            sessionID: UUID(),
            sourceID: UUID(),
            sequence: 1,
            type: "test",
            payload: Data()
        )

        await #expect(throws: AnchorLinkError.self) {
            try await client.send(event)
        }
    }

    @Test("A disconnected Mac does not reject a committed local session")
    func linkedRepositoryKeepsLocalSessionOffline() async throws {
        let service = "com.andywang.anchor.tests.offline.\(UUID().uuidString)"
        defer { deleteKeychainItems(service: service) }
        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: service)
        )
        let repository = LinkedSessionRepository(
            base: InMemorySessionRepository(),
            client: client
        )
        let goal = AnchorGoal(title: "Offline goal", completionCriteria: "Done")

        try await repository.send(.createSession(goal: goal, processes: []))

        let session = try #require(await repository.currentProjection().session)
        #expect(session.goal == goal)
    }

    @Test("Reconnect reconciliation replays acknowledged current history without obsolete tasks")
    func reconnectReplaysRetainedHistory() async throws {
        let suffix = UUID().uuidString
        let sourceStorage = URL.temporaryDirectory.appending(
            path: "anchor-reconcile-source-\(suffix).json"
        )
        let targetStorage = URL.temporaryDirectory.appending(
            path: "anchor-reconcile-target-\(suffix).json"
        )
        defer {
            try? FileManager.default.removeItem(at: sourceStorage)
            try? FileManager.default.removeItem(at: targetStorage)
        }

        let source = LocalSessionRepository(storageURL: sourceStorage, sourceID: UUID())
        let target = LocalSessionRepository(storageURL: targetStorage, sourceID: UUID())
        try await source.send(
            .createSession(
                goal: AnchorGoal(title: "Obsolete history", completionCriteria: "Archived"),
                processes: []
            )
        )
        try await source.send(.completeSession)
        try await source.send(
            .createSession(
                goal: AnchorGoal(title: "Recovered history", completionCriteria: "Visible"),
                processes: []
            )
        )
        let retainedEvents = await source.retainedEvents()
        let currentEvent = try #require(retainedEvents.last)
        for event in await source.pendingEvents() {
            try await source.markDelivered(event.id)
        }
        #expect(await source.pendingEvents().isEmpty)

        let linked = LinkedSessionRepository(
            base: source,
            transport: ApplyingEventTransport(receiver: target)
        )
        await linked.reconcilePeerHistory()
        await linked.reconcilePeerHistory()

        #expect(await target.currentProjection().session?.goal.title == "Recovered history")
        #expect(await target.currentProjection().archivedSessions.isEmpty == true)
        #expect(await target.retainedEvents() == [currentEvent])
    }

    @Test("Updating trust material does not delete the existing Keychain item first")
    func keychainUpdate() throws {
        let service = "com.andywang.anchor.tests.keychain.\(UUID().uuidString)"
        defer { deleteKeychainItems(service: service) }
        let store = PairingIdentityStore(service: service)
        let peerID = UUID()

        try store.saveSharedKey(Data("first".utf8), peerID: peerID)
        try store.saveSharedKey(Data("second".utf8), peerID: peerID)

        #expect(store.sharedKey(peerID: peerID) == Data("second".utf8))
    }

    @Test("Authenticated local events are applied in receive order before acknowledgement")
    func authenticatedEventRoundTrip() async throws {
        let suffix = UUID().uuidString
        let serviceType = isolatedServiceType()
        let serverService = "com.andywang.anchor.tests.server.\(suffix)"
        let clientService = "com.andywang.anchor.tests.client.\(suffix)"
        defer {
            deleteKeychainItems(service: serverService)
            deleteKeychainItems(service: clientService)
        }

        let server = AnchorBonjourServer(
            identityStore: PairingIdentityStore(service: serverService),
            serviceType: serviceType
        )
        let recorder = EventRecorder()
        server.onEvent = { event in
            if event.sequence == 1 {
                try await Task.sleep(for: .milliseconds(100))
            }
            await recorder.record(event)
        }
        try server.start()
        defer { server.stop() }

        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: clientService),
            serviceType: serviceType
        )
        defer { client.stop() }
        client.startDiscovery()
        let code = try #require(await server.currentPairingCode())
        try await client.pair(using: code)

        let sessionID = UUID()
        let sourceID = UUID()
        let firstEvent = EventEnvelope(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 1,
            type: "test.round-trip",
            payload: Data("first".utf8)
        )
        let secondEvent = EventEnvelope(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 2,
            type: "test.round-trip",
            payload: Data("second".utf8)
        )
        let firstDelivery = Task { try await client.send(firstEvent) }
        try await Task.sleep(for: .milliseconds(20))
        let secondDelivery = Task { try await client.send(secondEvent) }
        try await firstDelivery.value
        try await secondDelivery.value

        #expect(await recorder.events == [firstEvent, secondEvent])
    }

    @Test("The production phone-to-Mac task loop preserves status and history")
    func bidirectionalRepositoryRoundTrip() async throws {
        let suffix = UUID().uuidString
        let serviceType = isolatedServiceType()
        let serverService = "com.andywang.anchor.tests.server.repo.\(suffix)"
        let clientService = "com.andywang.anchor.tests.client.repo.\(suffix)"
        let serverStorage = URL.temporaryDirectory.appending(path: "anchor-server-\(suffix).json")
        let clientStorage = URL.temporaryDirectory.appending(path: "anchor-client-\(suffix).json")
        defer {
            deleteKeychainItems(service: serverService)
            deleteKeychainItems(service: clientService)
            try? FileManager.default.removeItem(at: serverStorage)
            try? FileManager.default.removeItem(at: clientStorage)
        }

        let server = AnchorBonjourServer(
            identityStore: PairingIdentityStore(service: serverService),
            serviceType: serviceType
        )
        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: clientService),
            serviceType: serviceType
        )
        let serverBase = LocalSessionRepository(
            storageURL: serverStorage,
            sourceID: UUID()
        )
        let clientBase = LocalSessionRepository(
            storageURL: clientStorage,
            sourceID: UUID()
        )
        let serverRepository = LinkedSessionRepository(base: serverBase, transport: server)
        let clientRepository = LinkedSessionRepository(base: clientBase, transport: client)

        server.onEvent = { [weak serverRepository] event in
            guard let serverRepository else { throw CancellationError() }
            try await serverRepository.applyRemote(event)
        }
        client.onEvent = { [weak clientRepository] event in
            guard let clientRepository else { throw CancellationError() }
            try await clientRepository.applyRemote(event)
        }
        server.onConnectionState = { state in
            guard state == .connected else { return }
            Task { await serverRepository.flushPendingEvents() }
        }
        client.onConnectionState = { state in
            guard state == .connected else { return }
            Task { await clientRepository.flushPendingEvents() }
        }

        // The phone owns task creation even while the Mac is offline. The
        // durable event remains queued until the authenticated link returns.
        try await clientRepository.send(
            .createSession(
                goal: AnchorGoal(title: "Phone goal", completionCriteria: "Synced"),
                processes: []
            )
        )
        #expect(await clientBase.pendingEvents().count == 1)

        try server.start()
        defer { server.stop() }
        client.startDiscovery()
        defer { client.stop() }
        try await client.pair(
            using: try #require(await server.currentPairingCode())
        )
        await clientRepository.flushPendingEvents()
        #expect(await clientBase.pendingEvents().isEmpty)
        #expect(await serverBase.currentProjection().session?.goal.title == "Phone goal")

        try await serverRepository.send(.addNote("Mac note"))
        #expect(await serverBase.pendingEvents().isEmpty)
        #expect(await clientBase.currentProjection().session?.notes.first?.text == "Mac note")

        let sessionID = try #require(await serverBase.currentProjection().session?.id)
        let sourceID = UUID()
        let processID = UUID()
        let runningAt = Date.now
        let runningProcess = AnchorProcess(
            id: processID,
            sessionID: sessionID,
            sourceID: sourceID,
            externalID: "codex-session",
            sourceName: "Codex",
            sourceSymbol: "C",
            sourceTone: "cyan",
            title: "Codex conversation",
            status: .running,
            updatedAt: runningAt
        )
        try await serverRepository.send(
            .observeProcess(
                ProcessObservation(
                    process: runningProcess,
                    event: ProcessEvent(
                        sessionID: sessionID,
                        processID: processID,
                        sourceID: sourceID,
                        externalID: "codex-turn-1",
                        occurredAt: runningAt,
                        kind: .progress,
                        title: "Codex started"
                    )
                )
            )
        )
        #expect(await clientBase.currentProjection().session?.processes.first?.status == .running)

        let completedAt = runningAt.addingTimeInterval(1)
        var completedProcess = runningProcess
        completedProcess.status = .completed
        completedProcess.updatedAt = completedAt
        try await serverRepository.send(
            .observeProcess(
                ProcessObservation(
                    process: completedProcess,
                    event: ProcessEvent(
                        sessionID: sessionID,
                        processID: processID,
                        sourceID: sourceID,
                        externalID: "codex-turn-1",
                        occurredAt: completedAt,
                        kind: .completed,
                        title: "Codex completed"
                    )
                )
            )
        )
        #expect(await clientBase.currentProjection().session?.processes.first?.status == .completed)

        try await clientRepository.send(.completeSession)
        #expect(await clientBase.currentProjection().session == nil)
        #expect(await serverBase.currentProjection().session == nil)
        #expect(await clientBase.currentProjection().archivedSessions.first?.id == sessionID)
        #expect(await serverBase.currentProjection().archivedSessions.first?.id == sessionID)
        #expect(await clientBase.currentProjection().archivedSessions.first?.timeline.count == 2)

        try await clientRepository.send(
            .createSession(
                goal: AnchorGoal(title: "Next phone goal", completionCriteria: "Separated"),
                processes: []
            )
        )
        #expect(await serverBase.currentProjection().session?.goal.title == "Next phone goal")
        #expect(await serverBase.currentProjection().archivedSessions.first?.id == sessionID)
    }

    @Test("A real Codex lifecycle reaches the iPhone projection over the local link")
    func codexLifecycleRoundTrip() async throws {
        let suffix = UUID().uuidString
        let serviceType = isolatedServiceType()
        let serverService = "com.andywang.anchor.tests.server.codex.\(suffix)"
        let clientService = "com.andywang.anchor.tests.client.codex.\(suffix)"
        let root = URL.temporaryDirectory.appending(path: "anchor-codex-link-\(suffix)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            deleteKeychainItems(service: serverService)
            deleteKeychainItems(service: clientService)
            try? FileManager.default.removeItem(at: root)
        }

        let server = AnchorBonjourServer(
            identityStore: PairingIdentityStore(service: serverService),
            serviceType: serviceType
        )
        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: clientService),
            serviceType: serviceType
        )
        let serverBase = LocalSessionRepository(
            storageURL: root.appending(path: "mac-session.json"),
            sourceID: UUID()
        )
        let clientBase = LocalSessionRepository(
            storageURL: root.appending(path: "iphone-session.json"),
            sourceID: UUID()
        )
        let serverRepository = LinkedSessionRepository(base: serverBase, transport: server)
        let clientRepository = LinkedSessionRepository(base: clientBase, transport: client)
        server.onEvent = { [weak serverRepository] event in
            guard let serverRepository else { throw CancellationError() }
            try await serverRepository.applyRemote(event)
        }
        client.onEvent = { [weak clientRepository] event in
            guard let clientRepository else { throw CancellationError() }
            try await clientRepository.applyRemote(event)
        }
        server.onConnectionState = { state in
            guard state == .connected else { return }
            Task { await serverRepository.flushPendingEvents() }
        }
        client.onConnectionState = { state in
            guard state == .connected else { return }
            Task { await clientRepository.flushPendingEvents() }
        }

        try await clientRepository.send(
            .createSession(
                goal: AnchorGoal(
                    title: "Observe Codex",
                    completionCriteria: "The iPhone receives the terminal state."
                ),
                processes: []
            )
        )
        try server.start()
        defer { server.stop() }
        client.startDiscovery()
        defer { client.stop() }
        try await client.pair(using: try #require(await server.currentPairingCode()))
        await clientRepository.flushPendingEvents()

        let session = try #require(await serverBase.currentProjection().session)
        client.stop()
        let sourceID = UUID()
        let workItemID = UUID()
        let taskStore = TaskRunStore(url: root.appending(path: "mac-task-runs.json"))
        try await taskStore.upsert(
            task: AnchorTask(
                id: session.id,
                title: session.goal.title,
                completionCriteria: session.goal.completionCriteria,
                createdAt: session.startedAt
            )
        )
        try await taskStore.upsert(
            workItem: AnchorWorkItem(
                id: workItemID,
                taskID: session.id,
                title: "Codex conversation",
                createdAt: session.startedAt
            )
        )

        let sessionFile = root.appending(path: "rollout-\(UUID().uuidString).jsonl")
        let sessionMetadata = #"{"timestamp":"2026-09-14T00:00:00.000Z","type":"session_meta","payload":{"id":"codex-session","cwd":"/private/example/Anchor","originator":"Codex Desktop"}}"#
        try Data("\(sessionMetadata)\n".utf8).write(to: sessionFile)
        let source = CodexLifecycleFileSource(
            fileURL: sessionFile,
            pollInterval: 0.05,
            sessionContextProvider: {
                ProcessSourceSessionContext(
                    sessionID: session.id,
                    startedAt: session.startedAt
                )
            },
            checkpointStore: CodexLifecycleCheckpointStore(
                storageURL: root.appending(path: "codex-checkpoints.json")
            ),
            descriptor: SourceDescriptor(
                id: sourceID,
                name: "Codex",
                kind: .integration,
                symbol: "C",
                tone: "cyan",
                capabilities: [.observe],
                permission: .granted
            )
        )
        let coordinator = ProcessSourceCoordinator(
            repository: serverRepository,
            sources: [],
            taskRunStore: taskStore
        )
        await coordinator.start()
        try await coordinator.setAssociation(
            AnchorEventAssociation(
                taskID: session.id,
                workItemID: workItemID,
                confirmedByUser: true
            ),
            for: session.id,
            sourceID: sourceID
        )
        await coordinator.register(source)

        let startedAt = session.startedAt.addingTimeInterval(1)
        try appendCodexLifecycle(
            .started,
            turnID: "turn-1",
            at: startedAt,
            to: sessionFile
        )
        try await waitForSourceEventCount(1, in: coordinator, sourceID: sourceID)
        #expect(await serverBase.pendingEvents().count == 1)
        #expect(await clientBase.currentProjection().session?.processes.isEmpty == true)

        client.startDiscovery()
        try await waitForProcessStatus(.running, in: clientBase)
        await serverRepository.flushPendingEvents()
        #expect(await serverBase.pendingEvents().isEmpty)

        try appendCodexLifecycle(
            .completed,
            turnID: "turn-1",
            at: startedAt.addingTimeInterval(1),
            to: sessionFile
        )
        try await waitForProcessStatus(.completed, in: clientBase)
        try await waitForSourceEventCount(2, in: coordinator, sourceID: sourceID)
        await coordinator.stop()

        let phoneSession = try #require(await clientBase.currentProjection().session)
        #expect(phoneSession.processes.count == 1)
        #expect(phoneSession.processes.first?.sourceName == "Codex")
        #expect(phoneSession.processes.first?.status == .completed)
        #expect(phoneSession.timeline.map(\.kind) == [.completed, .created])
        let taskRecord = try #require(await taskStore.currentTaskRecord())
        #expect(taskRecord.runs.first?.outcome == .completed)
        #expect(taskRecord.events.map(\.kind) == [.started, .completed])
        #expect(await serverBase.pendingEvents().isEmpty)
    }

    @Test("A paired iPhone can request the Mac's current process snapshot")
    func processSnapshotRoundTrip() async throws {
        let suffix = UUID().uuidString
        let serviceType = isolatedServiceType()
        let serverService = "com.andywang.anchor.tests.server.snapshot.\(suffix)"
        let clientService = "com.andywang.anchor.tests.client.snapshot.\(suffix)"
        defer {
            deleteKeychainItems(service: serverService)
            deleteKeychainItems(service: clientService)
        }

        let server = AnchorBonjourServer(
            identityStore: PairingIdentityStore(service: serverService),
            serviceType: serviceType
        )
        server.onCurrentProcessSnapshot = {
            CurrentProcessSnapshot(processNames: ["Claude", "Gemini", "Claude"])
        }
        try server.start()
        defer { server.stop() }

        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: clientService),
            serviceType: serviceType
        )
        defer { client.stop() }
        client.startDiscovery()
        try await client.pair(
            using: try #require(await server.currentPairingCode())
        )

        let snapshot = try await client.currentProcessSnapshot()
        #expect(snapshot.processNames == ["Claude", "Gemini"])
    }

}

private actor EventRecorder {
    private(set) var events: [EventEnvelope] = []

    func record(_ event: EventEnvelope) {
        events.append(event)
    }
}

private actor ApplyingEventTransport: AnchorEventTransport {
    let receiver: any EventBackedSessionRepository

    init(receiver: any EventBackedSessionRepository) {
        self.receiver = receiver
    }

    func send(_ event: EventEnvelope) async throws {
        try await receiver.applyRemote(event)
    }
}

private func deleteKeychainItems(service: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
    ]
    SecItemDelete(query as CFDictionary)
}

private func isolatedServiceType() -> String {
    "_at\(UUID().uuidString.prefix(8).lowercased())._tcp"
}

private func appendCodexLifecycle(
    _ lifecycle: CodexLifecycleRecord.CodexLifecycle,
    turnID: String,
    at date: Date,
    to url: URL
) throws {
    let timestamp = ISO8601DateFormatter.string(
        from: date,
        timeZone: TimeZone(secondsFromGMT: 0)!,
        formatOptions: [.withInternetDateTime, .withFractionalSeconds]
    )
    let line = #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"\#(lifecycle.rawValue)","turn_id":"\#(turnID)"}}"#
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\(line)\n".utf8))
}

private func waitForProcessStatus(
    _ status: ProcessStatus,
    in repository: any SessionRepository
) async throws {
    let stream = await repository.projections()
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            for await projection in stream {
                if projection.session?.processes.contains(where: {
                    $0.sourceName == "Codex" && $0.status == status
                }) == true {
                    return
                }
            }
            throw AnchorLinkTestError.projectionStreamEnded
        }
        group.addTask {
            try await Task.sleep(for: .seconds(3))
            throw AnchorLinkTestError.timedOutWaitingForProcess
        }
        _ = try await group.next()
        group.cancelAll()
    }
}

private func waitForSourceEventCount(
    _ expectedCount: Int,
    in coordinator: ProcessSourceCoordinator,
    sourceID: UUID
) async throws {
    let stream = await coordinator.healthChanges()
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            for await health in stream {
                if health.first(where: { $0.descriptor.id == sourceID })?.eventCount
                    == expectedCount {
                    return
                }
            }
            throw AnchorLinkTestError.healthStreamEnded
        }
        group.addTask {
            try await Task.sleep(for: .seconds(3))
            throw AnchorLinkTestError.timedOutWaitingForSource
        }
        _ = try await group.next()
        group.cancelAll()
    }
}

private enum AnchorLinkTestError: Error {
    case projectionStreamEnded
    case timedOutWaitingForProcess
    case healthStreamEnded
    case timedOutWaitingForSource
}
