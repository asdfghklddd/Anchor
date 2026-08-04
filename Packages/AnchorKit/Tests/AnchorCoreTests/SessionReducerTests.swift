import Foundation
import Testing
@testable import AnchorCore

@Suite("Session reducer")
struct SessionReducerTests {
    @Test("Replayed event envelope is idempotent")
    func envelopeDeduplication() throws {
        let sessionID = UUID()
        let processID = UUID()
        let process = AnchorProcess(
            id: processID,
            sourceName: "Test",
            sourceSymbol: "T",
            sourceTone: "cyan",
            title: "Test process",
            status: .running
        )
        let session = AnchorSession(
            id: sessionID,
            goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
            processes: [process]
        )
        let event = ProcessEvent(
            processID: processID,
            kind: .progress,
            title: "Halfway"
        )
        let envelope = EventEnvelope(
            sessionID: sessionID,
            sourceID: UUID(),
            sequence: 1,
            type: "process.progress",
            payload: Data()
        )
        let initial = SessionProjection(session: session)
        let once = try SessionReducer.reduce(initial, command: .applyEnvelope(envelope, event: event))
        let twice = try SessionReducer.reduce(once, command: .applyEnvelope(envelope, event: event))

        #expect(once.session?.timeline.count == 1)
        #expect(twice.session?.timeline.count == 1)
    }

    @Test("Resolving a decision updates its process")
    func decisionResolution() throws {
        let processID = UUID()
        let option = DecisionOption(title: "Choose me")
        let decision = Decision(
            processID: processID,
            title: "Choose",
            prompt: "Pick one",
            options: [option]
        )
        let process = AnchorProcess(
            id: processID,
            sourceName: "Test",
            sourceSymbol: "T",
            sourceTone: "sand",
            title: "Await choice",
            status: .needsDecision
        )
        let session = AnchorSession(
            goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
            processes: [process],
            decisions: [decision]
        )
        let result = try SessionReducer.reduce(
            SessionProjection(session: session),
            command: .resolveDecision(decisionID: decision.id, optionID: option.id)
        )

        #expect(result.session?.decisions.first?.status == .resolved)
        #expect(result.session?.processes.first?.status == .running)
    }
}
