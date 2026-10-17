import Foundation

/// The person's next move on one task, read from their own plan and from what
/// its sources reported since they last looked. It is a reading order, never an
/// action taken for them, and it never marks a step done.
public enum TaskNextAction: Hashable, Sendable {
    /// A source reported a failure the person has not looked at.
    case fix(process: String)
    /// A run finished since the person last looked: check it, then answer for the step.
    case review(process: String)
    /// A run is still working, so nothing needs the person yet.
    case wait(process: String, since: Date)
    /// The plan's next open step, with nothing running for it.
    case start(step: Int, text: String)
    /// Every step is marked done; finishing the anchor stays the person's call.
    case finish

    /// `nil` for a task without written steps, which has no plan to follow.
    public init?(task: AnchorSession) {
        guard let plan = task.goal.userPlan, !plan.steps.isEmpty else { return nil }
        let looked = plan.reviewedAt ?? .distantPast
        let processes = task.taskProcesses
        let unseen = processes.filter { $0.updatedAt > looked }
        if let failure = Self.latest(unseen.filter { $0.status == .failed && !$0.isInterrupted }) {
            self = .fix(process: failure.title)
        } else if let finished = Self.latest(unseen.filter { $0.status == .completed }) {
            self = .review(process: finished.title)
        } else if let running = Self.latest(processes.filter { $0.status == .running }) {
            let started = running.events.filter { $0.kind == .created }.map(\.occurredAt).max()
            self = .wait(process: running.title, since: started ?? running.updatedAt)
        } else if let next = plan.nextStepIndex {
            self = .start(step: next, text: plan.steps[next])
        } else {
            self = .finish
        }
    }

    /// Whether the person, rather than a running source, is the one expected to act.
    public var needsPerson: Bool {
        switch self {
        case .fix, .review, .start, .finish: true
        case .wait: false
        }
    }

    private static func latest(_ processes: [AnchorProcess]) -> AnchorProcess? {
        processes.max { ($0.updatedAt, $0.id.uuidString) < ($1.updatedAt, $1.id.uuidString) }
    }
}

public extension TaskNextAction {
    /// One reading order for every screen: fix, check, start, wait, finish.
    var urgency: Int {
        switch self {
        case .fix: 0
        case .review: 1
        case .start: 2
        case .wait: 3
        case .finish: 4
        }
    }

    /// A failure or a finished result the person has not looked at.
    var asksForALook: Bool { urgency <= 1 }
}
