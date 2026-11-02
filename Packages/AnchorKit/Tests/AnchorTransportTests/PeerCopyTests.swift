import AnchorCore
import AnchorTransport
import Foundation
import Testing

@Suite("Taking the Mac's copy")
struct PeerCopyTests {
    /// Hands each event to a receiver the way the link does: requests to the
    /// Mac's handler, everything else into the repository.
    private actor Wire: AnchorEventTransport {
        private var receive: (@Sendable (EventEnvelope) async throws -> Void)?

        func connect(_ receive: @escaping @Sendable (EventEnvelope) async throws -> Void) {
            self.receive = receive
        }

        func send(_ event: EventEnvelope) async throws {
            guard let receive else { throw CancellationError() }
            try await receive(event)
        }
    }

    private func conversation(in sessionID: UUID, title: String) -> SessionCommand {
        let process = AnchorProcess(
            id: StableProcessIdentity.id(namespace: "test.conversation", sessionID: sessionID, externalID: title),
            sessionID: sessionID, sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C",
            sourceTone: "cyan", title: title, status: .running, updatedAt: .now
        )
        return .observeProcess(ProcessObservation(process: process, deduplicationKey: "test.\(sessionID).\(title)"))
    }

    @Test func aPhoneGoesBackToWhereARestoredMacIs() async throws {
        let folder = URL.temporaryDirectory.appending(path: "peer-copy-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let phoneURL = folder.appending(path: "phone.json")
        let macURL = folder.appending(path: "mac.json")
        let snapshotURL = folder.appending(path: "mac-snapshot.json")
        let phoneID = UUID()
        let macID = UUID()

        let phone = LocalSessionRepository(storageURL: phoneURL, sourceID: phoneID)
        let toMac = Wire()
        let toPhone = Wire()
        let phoneLink = LinkedSessionRepository(base: phone, transport: toMac)
        await toPhone.connect { try await phone.applyRemote($0) }

        func connectMac(_ mac: LocalSessionRepository) async -> LinkedSessionRepository {
            let macLink = LinkedSessionRepository(base: mac, transport: toPhone)
            await toMac.connect { envelope in
                if PeerHistoryRequest(envelope: envelope) != nil {
                    await macLink.resendAllHistory()
                    return
                }
                try await mac.applyRemote(envelope)
            }
            return macLink
        }

        // The prepared starting point: a task with a note and a conversation, one finished.
        var mac = LocalSessionRepository(storageURL: macURL, sourceID: macID)
        var macLink = await connectMac(mac)
        let done = AnchorSession(goal: AnchorGoal(title: "Old", completionCriteria: "Done"))
        let essay = AnchorSession(goal: AnchorGoal(title: "Essay", completionCriteria: "Done"))
        try await phoneLink.send(.hostSession(done))
        try await phoneLink.send(.forSession(done.id, .completeSession))
        try await phoneLink.send(.hostSession(essay))
        try await phoneLink.send(.forSession(essay.id, .addNote("Prepared")))
        await phoneLink.flushPendingEvents()
        try await macLink.send(conversation(in: essay.id, title: "Main"))
        await macLink.flushPendingEvents()
        try FileManager.default.copyItem(at: macURL, to: snapshotURL)

        // The demo changes both sides.
        let demo = AnchorSession(goal: AnchorGoal(title: "Made on stage", completionCriteria: "Done"))
        try await phoneLink.send(.hostSession(demo))
        try await phoneLink.send(.forSession(essay.id, .addNote("On stage")))
        await phoneLink.flushPendingEvents()
        try await macLink.send(conversation(in: essay.id, title: "Stage"))
        await macLink.flushPendingEvents()
        #expect(await mac.currentProjection().hostedSessions.count == 2)

        // The phone empties first; what the old Mac still sends is not kept.
        try await phoneLink.awaitPeerCopy()
        #expect(await phone.currentProjection().hostedSessions.isEmpty)
        #expect(await phone.currentProjection().archivedSessions.isEmpty)
        #expect(await phone.currentProjection().awaitsPeerCopy)
        try await macLink.send(conversation(in: essay.id, title: "Late"))
        await macLink.flushPendingEvents()
        #expect(await phone.currentProjection().hostedSessions.isEmpty)

        // The Mac comes back from its snapshot; the phone connects.
        try FileManager.default.removeItem(at: macURL)
        try FileManager.default.copyItem(at: snapshotURL, to: macURL)
        mac = LocalSessionRepository(storageURL: macURL, sourceID: macID)
        macLink = await connectMac(mac)
        await phoneLink.reconcilePeerHistory()
        await macLink.reconcilePeerHistory()

        let restored = await phone.currentProjection()
        #expect(!restored.awaitsPeerCopy)
        #expect(restored.hostedSessions.map(\.id) == [essay.id])
        #expect(restored.archivedSessions.map(\.id) == [done.id])
        #expect(restored.session?.notes.map(\.text) == ["Prepared"])
        #expect(restored.session?.processes.map(\.title) == ["Main"])
        // Nothing from the stage went back to the Mac.
        #expect(await mac.currentProjection().hostedSessions.map(\.id) == [essay.id])
        #expect(await mac.currentProjection().session?.notes.map(\.text) == ["Prepared"])

        // The phone's next change still reaches the Mac.
        try await phoneLink.send(.forSession(essay.id, .addNote("Next")))
        await phoneLink.flushPendingEvents()
        #expect(await mac.currentProjection().session?.notes.map(\.text) == ["Next", "Prepared"])

        // Waiting survives a relaunch.
        try await phone.awaitPeerCopy()
        let relaunched = LocalSessionRepository(storageURL: phoneURL, sourceID: phoneID)
        #expect(await relaunched.currentProjection().awaitsPeerCopy)
        #expect(await relaunched.retainedEvents().isEmpty)
    }
}
