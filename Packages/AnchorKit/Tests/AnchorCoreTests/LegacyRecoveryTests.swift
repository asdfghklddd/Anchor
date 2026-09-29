import Foundation
import Testing
@testable import AnchorCore

@Suite("Legacy recovery")
struct LegacyRecoveryTests {
    // An independent encoder preserves the historical event shape in this regression.
    private enum OldOperation: Encodable {
        case syncTaskStructure(task: AnchorTask, workItems: [AnchorWorkItem], at: Date)
    }

    @Test("Retired task structure survives replay without replacing current work")
    func restoresLegacyStructure() async throws {
        let url = URL.temporaryDirectory.appending(path: "anchor-legacy-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url)
        try await repository.send(.createSession(
            goal: AnchorGoal(title: "Current goal", completionCriteria: "Keep it"), processes: []
        ))
        let session = try #require(await repository.currentProjection().session)
        let task = AnchorTask(id: session.id, title: "Old title", completionCriteria: "Old", createdAt: session.startedAt)
        let payload = try JSONEncoder.anchor.encode(OldOperation.syncTaskStructure(
            task: task, workItems: [AnchorWorkItem(taskID: task.id, title: "Old item")], at: .now
        ))
        let event = EventEnvelope(sessionID: session.id, sourceID: UUID(), sequence: 1,
                                  type: EventEnvelope.operationType, payload: payload)
        try await repository.applyRemote(event)
        let restored = LocalSessionRepository(storageURL: url)
        let projection = await restored.currentProjection()
        #expect(projection.errorMessage == nil)
        #expect(projection.session?.goal.title == "Current goal")
        #expect(await restored.retainedEvents().contains(event))
        #expect(await restored.retainedEvents().first(where: { $0.id == event.id })?.payload == payload)
    }

    @Test("Legacy task structure rejects work items belonging to another task")
    func rejectsInvalidOwnership() throws {
        let session = AnchorSession(goal: AnchorGoal(title: "Goal", completionCriteria: "Done"))
        let task = AnchorTask(id: session.id, title: "Goal", completionCriteria: "Done")
        #expect(throws: SessionRepositoryError.self) {
            try SessionReducer.reduce(SessionProjection(session: session), operation: .syncTaskStructure(
                task: task, workItems: [AnchorWorkItem(taskID: UUID(), title: "Wrong owner")], at: .now
            ))
        }
    }

    @Test("Unknown events remain recoverable and still surface an error")
    func preservesUnknownEvents() async throws {
        let url = URL.temporaryDirectory.appending(path: "anchor-unknown-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url)
        try await repository.send(.createSession(
            goal: AnchorGoal(title: "Keep work", completionCriteria: "Done"), processes: []
        ))
        var saved = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var events = try #require(saved["events"] as? [[String: Any]])
        var unknown = try #require(events.first)
        unknown["id"] = UUID().uuidString
        unknown["sequence"] = 2
        unknown["payload"] = Data(#"{"futureOperation":{}}"#.utf8).base64EncodedString()
        events.append(unknown)
        saved["events"] = events
        let original = try JSONSerialization.data(withJSONObject: saved)
        try original.write(to: url)
        let restored = LocalSessionRepository(storageURL: url)
        #expect(await restored.currentProjection().errorMessage != nil)
        #expect(await restored.currentProjection().session?.goal.title == "Keep work")
        #expect(await restored.retainedEvents().count == 2)
        #expect(try Data(contentsOf: url) == original)
    }

    @Test("Only an explicit latest Codex abort suppresses failure attention")
    func interruptedPresentation() throws {
        let data = Data(#"{"timestamp":"2026-09-29T10:00:00Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1"}}"#.utf8)
        let record = try #require(CodexLifecycleRecord(json: data))
        let external = record.externalEvent(sessionID: UUID(), sourceID: UUID())
        var process = external.process
        process.events = [try #require(external.event)]
        #expect(process.isInterrupted)
        #expect(!process.requiresAttention)
        process.updatedAt = record.timestamp.addingTimeInterval(1)
        #expect(!process.isInterrupted)
        #expect(process.requiresAttention)
        process.status = .running
        #expect(!process.isInterrupted)
    }
}
