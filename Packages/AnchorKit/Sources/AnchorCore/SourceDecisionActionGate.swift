import Foundation

/// Claim only a newly resolved decision on the envelope's owning task.
/// Reconciliation and simultaneous radio deliveries must not repeat source actions.
public actor SourceDecisionActionGate {
    private struct Key: Hashable { let sessionID: UUID; let decisionID: UUID }
    private var claimed: Set<Key> = []

    public init() {}

    public func claim(operation: SessionOperation, sessionID: UUID,
                      before: SessionProjection, after: SessionProjection) -> (sourceID: UUID, action: SourceAction)? {
        guard let action = operation.sourceAction,
              case let .resolveDecision(decisionID, optionID) = action,
              let previous = before.hostedSessions.first(where: { $0.id == sessionID }),
              previous.decisions.contains(where: { $0.id == decisionID && $0.status == .open }),
              let current = after.hostedSessions.first(where: { $0.id == sessionID }),
              let decision = current.decisions.first(where: { $0.id == decisionID && $0.status == .resolved && $0.selectedOptionID == optionID }),
              let sourceID = current.processes.first(where: { $0.id == decision.processID })?.sourceID,
              claimed.insert(Key(sessionID: sessionID, decisionID: decisionID)).inserted else { return nil }
        return (sourceID, action)
    }
}
