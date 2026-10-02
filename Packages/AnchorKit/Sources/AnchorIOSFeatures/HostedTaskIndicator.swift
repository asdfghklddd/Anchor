import AnchorCore

/// Presentation only: never infers a stalled task from elapsed time or changes
/// the source-owned status, completion confirmation, or archive lifecycle.
struct HostedTaskIndicator {
    let isComplete: Bool
    let isRunning: Bool
    let hasFailure: Bool
    let hasWarning: Bool

    init(task: AnchorSession) {
        let processes = task.taskProcesses
        isComplete = task.status == .completed || task.status == .archived
            || (!processes.isEmpty && processes.allSatisfy { $0.status == .completed })
        isRunning = !isComplete && (processes.contains { $0.status == .running }
            || (processes.isEmpty && task.status == .active))
        hasFailure = !isComplete && processes.contains { $0.status == .failed && !$0.isInterrupted }
        hasWarning = !isComplete && processes.contains {
            [.needsDecision, .blocked, .disconnected].contains($0.status) || $0.isInterrupted
        }
    }
}
