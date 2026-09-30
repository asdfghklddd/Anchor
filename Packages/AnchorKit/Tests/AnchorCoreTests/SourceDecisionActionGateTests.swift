import Foundation
import Testing
@testable import AnchorCore

@Suite("Inbound decision actions")
struct SourceDecisionActionGateTests {
    @Test("An inactive task receives its own action only once even on simultaneous redelivery")
    func ownerAndDuplicate() async throws {
        let process = AnchorProcess(sourceID: UUID(), sourceName: "Source", sourceSymbol: "S", sourceTone: "cyan", title: "Work", status: .needsDecision)
        let option = DecisionOption(title: "Continue", detail: "")
        let decision = Decision(processID: process.id, title: "Choose", prompt: "Next", options: [option])
        let owner = AnchorSession(goal: AnchorGoal(title: "Owner", completionCriteria: "Done"), processes: [process], decisions: [decision])
        let selected = AnchorSession(goal: AnchorGoal(title: "Other task", completionCriteria: "Done"))
        let before = SessionProjection(session: selected, additionalSessions: [owner])
        let operation = SessionOperation.scoped(sessionID: owner.id, operation: .resolveDecision(decisionID: decision.id, optionID: option.id, resolvedAt: .now, eventID: UUID()))
        let after = try SessionReducer.reduce(before, operation: operation, targetSessionID: owner.id, now: .now)
        let gate = SourceDecisionActionGate()
        let claim = await gate.claim(operation: operation, sessionID: owner.id, before: before, after: after)
        #expect(claim?.sourceID == process.sourceID)
        #expect(await gate.claim(operation: operation, sessionID: owner.id, before: before, after: after) == nil)
        let restarted = SourceDecisionActionGate()
        #expect(await restarted.claim(operation: operation, sessionID: owner.id, before: after, after: after) == nil)
        #expect(await restarted.claim(operation: operation, sessionID: selected.id, before: before, after: after) == nil)
    }
}
