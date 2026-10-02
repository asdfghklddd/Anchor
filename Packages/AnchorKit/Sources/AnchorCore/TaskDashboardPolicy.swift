import Foundation

/// The production apps observe task state. Legacy records remain readable by
/// the repository, but do not re-enable general app tracking or decision actions.
public enum TaskDashboardPolicy {
    public static func includes(_ process: AnchorProcess) -> Bool {
        process.sourceID != BuiltInProcessSourceID.macWorkspace
            && process.sourceID != BuiltInProcessSourceID.web
    }

    public static func presentation(of projection: SessionProjection) -> SessionProjection {
        var result = projection
        result.session = projection.session.map(presentation)
        result.additionalSessions = projection.additionalSessions.map(presentation)
        result.sourceHealth = projection.sourceHealth.filter {
            $0.key != BuiltInProcessSourceID.macWorkspace && $0.key != BuiltInProcessSourceID.web
        }
        return result
    }

    private static func presentation(of session: AnchorSession) -> AnchorSession {
        var result = session
        let excludedIDs = Set(session.processes.filter { !includes($0) }.map(\.id))
        result.processes = session.processes.filter(includes)
        result.decisions = []
        result.timeline = session.timeline.filter {
            $0.kind != .decisionRequired && $0.kind != .decisionResolved
                && $0.sourceID != BuiltInProcessSourceID.macWorkspace
                && $0.sourceID != BuiltInProcessSourceID.web
                && !($0.processID.map(excludedIDs.contains) ?? false)
        }
        if var summary = result.returnSummary {
            let removedEventIDs = Set(session.timeline.map(\.id)).subtracting(result.timeline.map(\.id))
            summary.changes.removeAll {
                $0.kind == .decisionRequired || $0.kind == .decisionResolved || removedEventIDs.contains($0.id)
            }
            summary.completedCount = summary.changes.filter { $0.kind == .completed || $0.kind == .outputReady }.count
            summary.failedCount = summary.changes.filter { $0.kind == .failed && $0.title != "Codex turn_aborted" }.count
            summary.newDecisionCount = 0
            if let id = summary.recommendedProcessID, excludedIDs.contains(id) {
                summary.recommendedProcessID = nil
            }
            result.returnSummary = summary
        }
        return result
    }

    static func allows(_ command: SessionCommand) -> Bool {
        switch command {
        case .resolveDecision: false
        case let .forSession(_, nested): allows(nested)
        default: true
        }
    }
}
