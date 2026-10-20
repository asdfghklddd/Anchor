import Foundation

/// What the person can do while an agent works on the task they're on: the
/// next task that needs them, in the same reading order as every screen, or,
/// when no other task does, the step of this task to get ready next. Derived
/// on every read and never stored; it points the way and never switches tasks.
public enum TaskMeanwhile: Hashable, Sendable {
    /// Another task needs the person; its next action says for what.
    case other(task: UUID, title: String, action: TaskNextAction)
    /// Nothing else needs the person: get this task's next step ready, if it has
    /// one after the step the agent is on (`nil` when that is the last).
    case prepare(step: Int?, text: String?)

    /// `nil` unless the current task waits on a running agent.
    public init?(current: AnchorSession, among tasks: [AnchorSession]) {
        guard case .wait = TaskNextAction(task: current) else { return nil }
        // Ties go to the result that has waited longest, then to anchoring order.
        let candidates = tasks.enumerated().compactMap { offset, task -> Candidate? in
            guard task.id != current.id, let action = TaskNextAction(task: task), action.needsPerson else { return nil }
            return Candidate(task: task, action: action, since: Self.waitingSince(task) ?? .distantFuture, order: offset)
        }
        if let first = candidates.min(by: { ($0.action.urgency, $0.since, $0.order) < ($1.action.urgency, $1.since, $1.order) }) {
            self = .other(task: first.task.id, title: first.task.goal.title, action: first.action)
            return
        }
        self = Self.preparing(current)
    }

    /// The task this points at, when it is another one.
    public var taskID: UUID? {
        if case let .other(task, _, _) = self { task } else { nil }
    }

    private struct Candidate {
        let task: AnchorSession
        let action: TaskNextAction
        let since: Date
        let order: Int
    }

    /// The open step after the one the running agent works on: its matched
    /// step when the Mac recorded one, otherwise the plan's next open step.
    private static func preparing(_ task: AnchorSession) -> TaskMeanwhile {
        guard let plan = task.goal.userPlan else { return .prepare(step: nil, text: nil) }
        let running = task.taskProcesses.filter { $0.status == .running }.max { $0.updatedAt < $1.updatedAt }
        let agentStep = running?.stepID.flatMap(plan.index(of:)) ?? plan.nextStepIndex
        guard let agentStep,
              let next = plan.items.indices.first(where: { $0 > agentStep && !plan.isDone($0) }) else {
            return .prepare(step: nil, text: nil)
        }
        return .prepare(step: next, text: plan.steps[next])
    }

    /// When the oldest result the person has not looked at arrived, if any.
    private static func waitingSince(_ task: AnchorSession) -> Date? {
        task.resultsToLookAt.map(\.updatedAt).min()
    }
}

public extension AnchorSession {
    /// The work that waits for the person's look: a question, or a failure or
    /// finished run since they last answered for a step. A turn they stopped
    /// themselves is not news.
    var resultsToLookAt: [AnchorProcess] {
        let looked = goal.userPlan?.reviewedAt ?? .distantPast
        return taskProcesses.filter { process in
            switch process.status {
            case .needsDecision: true
            case .completed: process.updatedAt > looked
            case .failed: process.updatedAt > looked && !process.isInterrupted
            default: false
            }
        }
    }
}

/// Why the person should be back at the desk, if they are not: an agent is
/// working on the task they're on, or a result waits for them on some task.
/// The pick-up card and the desk reminder read the same answer.
public enum DeskHold: Hashable, Sendable {
    /// The current task's agent is working; `meanwhile` is what to do instead of the phone.
    case waiting(task: UUID, title: String, action: TaskNextAction, meanwhile: TaskMeanwhile)
    /// A task needs the person: an answer, a failure, or a finished result.
    case needsYou(task: UUID, title: String, action: TaskNextAction)

    /// `nil` when nothing is running for the current task and no result waits.
    public init?(current: AnchorSession?, among tasks: [AnchorSession]) {
        if let current, let action = TaskNextAction(task: current),
           let meanwhile = TaskMeanwhile(current: current, among: tasks) {
            self = .waiting(task: current.id, title: current.goal.title, action: action, meanwhile: meanwhile)
            return
        }
        // The current task comes first when it is the one with something to look at.
        let ordered = (current.map { [$0] } ?? []) + tasks.filter { $0.id != current?.id }
        let looks = ordered.enumerated().compactMap { offset, task -> (Int, Int, AnchorSession, TaskNextAction)? in
            guard let action = TaskNextAction(task: task), action.asksForALook else { return nil }
            return (action.urgency, offset, task, action)
        }
        guard let first = looks.min(by: { ($0.0, $0.1) < ($1.0, $1.1) }) else { return nil }
        self = .needsYou(task: first.2.id, title: first.2.goal.title, action: first.3)
    }
}
