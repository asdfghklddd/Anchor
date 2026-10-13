import Foundation

/// Separates user-owned task structure from observed runs and ambient app state.
public enum ProcessPresentationGroup: Hashable, Sendable {
    case planned
    case observedTask
    case environment
}

public extension AnchorProcess {
    /// Peers encode aborted Codex turns and stopped terminal commands as failed.
    /// Interpret the explicit lifecycle fact at presentation time without
    /// rewriting the wire history.
    var isInterrupted: Bool {
        guard status == .failed,
              let latest = events.max(by: { $0.occurredAt < $1.occurredAt }) else { return false }
        return latest.isInterruption && latest.occurredAt >= updatedAt
    }

    var requiresAttention: Bool {
        status == .needsDecision || status == .blocked || (status == .failed && !isInterrupted)
    }

    var presentationGroup: ProcessPresentationGroup {
        guard let sourceID else { return .planned }
        if sourceID == BuiltInProcessSourceID.macWorkspace {
            return .environment
        }
        return .observedTask
    }
}

public extension ProcessEvent {
    /// The person stopped the work: an aborted Codex turn, or a terminal command
    /// ended by Ctrl-C, Ctrl-\ or closing its terminal. Not a failure (D02).
    var isInterruption: Bool {
        guard kind == .failed else { return false }
        if title == "Codex turn_aborted" { return true }
        return sourceID == BuiltInProcessSourceID.file
            && metric.map(CLIProcessSignal.interruptionExitCodes.contains) == true
    }
}

public extension AnchorSession {
    var plannedProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup == .planned }
    }

    var observedTaskProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup == .observedTask }
    }

    var environmentProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup == .environment }
    }

    var taskProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup != .environment }
    }
}
