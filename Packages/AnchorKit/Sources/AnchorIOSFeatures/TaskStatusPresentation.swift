#if os(iOS)
import AnchorCore
import AnchorDesign

enum TaskStatusPresentation {
    static func text(for session: AnchorSession?) -> String {
        guard let session else { return "—" }
        let processes = session.processes
        let hasRunning = processes.contains { $0.status == .running }
        let needsAttention = processes.contains {
            $0.status == .needsDecision || $0.status == .blocked
        }
        let hasFailure = processes.contains { $0.status == .failed }

        if hasRunning && needsAttention {
            return "\(L10n.live) · \(L10n.attentionNeeded)"
        }
        if hasRunning && hasFailure {
            return "\(L10n.live) · \(L10n.sourceSetupTaskHasFailure)"
        }
        if hasRunning {
            return L10n.live
        }
        if needsAttention {
            return L10n.attentionNeeded
        }
        if hasFailure {
            return L10n.sourceSetupTaskFailed
        }
        if processes.contains(where: { $0.status == .disconnected }) {
            return L10n.stale
        }

        let observed = processes.filter { $0.sourceID != nil }
        if !observed.isEmpty && observed.allSatisfy({ $0.status == .completed }) {
            return L10n.sourceSetupTaskAwaitingConfirmation
        }
        if !processes.isEmpty && processes.allSatisfy({ $0.status == .completed }) {
            return L10n.status(.completed)
        }
        return L10n.preparing
    }
}
#endif
