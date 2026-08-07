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
        let serverService = "com.andywang.anchor.tests.server.\(suffix)"
        let clientService = "com.andywang.anchor.tests.client.\(suffix)"
        defer {
            deleteKeychainItems(service: serverService)
            deleteKeychainItems(service: clientService)
        }

        let server = AnchorBonjourServer(
            identityStore: PairingIdentityStore(service: serverService)
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
            identityStore: PairingIdentityStore(service: clientService)
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

    @Test("A paired client and server replicate durable operations in both directions")
    func bidirectionalRepositoryRoundTrip() async throws {
        let suffix = UUID().uuidString
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
            identityStore: PairingIdentityStore(service: serverService)
        )
        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: clientService)
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

        try server.start()
        defer { server.stop() }
        client.startDiscovery()
        defer { client.stop() }
        try await client.pair(
            using: try #require(await server.currentPairingCode())
        )

        try await clientRepository.send(
            .createSession(
                goal: AnchorGoal(title: "Phone goal", completionCriteria: "Synced"),
                processes: []
            )
        )
        #expect(await clientBase.pendingEvents().isEmpty)
        #expect(await serverBase.currentProjection().session?.goal.title == "Phone goal")

        try await serverRepository.send(.addNote("Mac note"))
        #expect(await serverBase.pendingEvents().isEmpty)
        #expect(await clientBase.currentProjection().session?.notes.first?.text == "Mac note")
    }

    @Test("A paired iPhone can request the Mac's current process snapshot")
    func processSnapshotRoundTrip() async throws {
        let suffix = UUID().uuidString
        let serverService = "com.andywang.anchor.tests.server.snapshot.\(suffix)"
        let clientService = "com.andywang.anchor.tests.client.snapshot.\(suffix)"
        defer {
            deleteKeychainItems(service: serverService)
            deleteKeychainItems(service: clientService)
        }

        let server = AnchorBonjourServer(
            identityStore: PairingIdentityStore(service: serverService)
        )
        server.onCurrentProcessSnapshot = {
            CurrentProcessSnapshot(processNames: ["Claude", "Gemini", "Claude"])
        }
        try server.start()
        defer { server.stop() }

        let client = AnchorBonjourClient(
            identityStore: PairingIdentityStore(service: clientService)
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

private func deleteKeychainItems(service: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
    ]
    SecItemDelete(query as CFDictionary)
}
