import Foundation
import Testing
@testable import AnchorCore

@Suite("Retired recording migration")
struct RetiredRecordingCleanupTests {
    private struct State: Codable {
        var schemaVersion = 2
        var baseProjection: SessionProjection
        var events: [EventEnvelope]
        var outbox: [EventEnvelope]
        var nextSequence: UInt64 = 100
    }

    private func envelope(_ operation: SessionOperation, sessionID: UUID, sequence: UInt64) throws -> EventEnvelope {
        EventEnvelope(sessionID: sessionID, sourceID: UUID(), sequence: sequence,
            timestamp: operation.occurredAt, type: EventEnvelope.operationType,
            payload: try JSONEncoder.anchor.encode(operation), schemaVersion: operation.envelopeSchemaVersion)
    }

    @Test("Migration removes seeded identities, preserves real work and backs up original bytes")
    func migration() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "session.json")
        let real = AnchorSession(goal: AnchorGoal(title: "My work", completionCriteria: "Verified"))
        let retired = AnchorSession(id: try #require(RetiredRecordingCleanup.sessionIDs.first),
            goal: AnchorGoal(title: "Retired", completionCriteria: ""))
        let realEvent = try envelope(.hostSession(real), sessionID: real.id, sequence: 1)
        let retiredEvent = try envelope(.hostSession(retired), sessionID: retired.id, sequence: 2)
        let original = try JSONEncoder.anchor.encode(State(baseProjection: .empty,
            events: [realEvent, retiredEvent], outbox: [realEvent, retiredEvent]))
        try original.write(to: url)
        let repository = LocalSessionRepository(storageURL: url)
        #expect(await repository.currentProjection().hostedSessions.map(\.id) == [real.id])
        #expect(await repository.retainedEvents().map(\.id) == [realEvent.id])
        #expect(await repository.pendingEvents().map(\.id) == [realEvent.id])
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "bak" }
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == original)
        let restarted = LocalSessionRepository(storageURL: url)
        #expect(await restarted.currentProjection().session?.id == real.id)
        try await restarted.applyRemote(retiredEvent)
        #expect(await restarted.currentProjection().hostedSessions.map(\.id) == [real.id])
        #expect(try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).count == 2)
    }

    @Test("Recording events and their presence changes are removed without deleting ordinary activity")
    func recordingEvents() throws {
        let id = UUID()
        let at = Date(timeIntervalSince1970: 1_800_000_000)
        let process = AnchorProcess(sessionID: id, sourceName: "演示工作计划", sourceSymbol: "P",
            sourceTone: "cyan", title: "Retired", status: .completed, updatedAt: at.addingTimeInterval(0.001))
        let observation = try envelope(.observeProcess(ProcessObservation(process: process)), sessionID: id, sequence: 1)
        let injected = try envelope(.updatePresence(status: .away, at: at, eventID: UUID()), sessionID: id, sequence: 2)
        let real = try envelope(.updatePresence(status: .away, at: at.addingTimeInterval(10), eventID: UUID()), sessionID: id, sequence: 3)
        #expect(RetiredRecordingCleanup.filteredEvents([observation, injected, real]) == [real])
        let session = AnchorSession(id: id, goal: AnchorGoal(title: "Real goal", completionCriteria: ""),
            processes: [process], notes: [AnchorNote(text: "Keep this note")])
        let clean = try #require(RetiredRecordingCleanup.clean(session))
        #expect(clean.processes.isEmpty)
        #expect(clean.goal == session.goal)
        #expect(clean.notes == session.notes)
    }
}
