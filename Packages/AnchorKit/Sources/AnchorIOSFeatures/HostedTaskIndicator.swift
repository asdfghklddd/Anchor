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
        // A finished run is not a finished task: with written steps, only the person's
        // own checkmarks (or finishing the anchor) complete it.
        let plan = task.goal.userPlan.flatMap { $0.steps.isEmpty ? nil : $0 }
        isComplete = task.status == .completed || task.status == .archived
            || (plan?.isFinished ?? (!processes.isEmpty && processes.allSatisfy { $0.status == .completed }))
        isRunning = !isComplete && (processes.contains { $0.status == .running }
            || (processes.isEmpty && task.status == .active))
        hasFailure = !isComplete && processes.contains { $0.status == .failed && !$0.isInterrupted }
        hasWarning = !isComplete && processes.contains {
            [.needsDecision, .blocked, .disconnected].contains($0.status) || $0.isInterrupted
        }
    }
}
