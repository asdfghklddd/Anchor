import Foundation

/// The one thing the Mac edge says beyond "anchored or not": something
/// happened since you last looked. Ordered by how much it asks of you.
public enum EdgeBuoySignal: Int, Comparable, Hashable, Sendable {
    case finished
    case attention
    case failed

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The strongest unseen fact across hosted tasks, or nil when there is
    /// nothing new. A stop the person made themselves is never a signal, and
    /// a start is not news.
    public static func unseen(in tasks: [AnchorSession], since seenAt: Date) -> EdgeBuoySignal? {
        var strongest: EdgeBuoySignal?
        for process in tasks.flatMap(\.taskProcesses) {
            for event in process.events where event.occurredAt > seenAt {
                guard let signal = signal(for: event) else { continue }
                strongest = max(strongest ?? signal, signal)
            }
        }
        return strongest
    }

    private static func signal(for event: ProcessEvent) -> EdgeBuoySignal? {
        switch event.kind {
        case .failed: event.isInterruption ? nil : .failed
        case .decisionRequired: .attention
        case .completed: .finished
        case .created, .progress, .outputReady, .decisionResolved, .note, .presence, .connection: nil
        }
    }
}

/// What the edge buoy says: how many tasks need the person, in the color of
/// the most pressing reason (one needs-you signal, M5).
public struct EdgeBuoy: Hashable, Sendable {
    public let signal: EdgeBuoySignal
    public let count: Int

    public init(signal: EdgeBuoySignal, count: Int) {
        self.signal = signal
        self.count = count
    }

    /// Tasks with something new since the person last looked at Anchor that
    /// asks for them: a failure, a question, or a finished result. Answering
    /// for the step on either device counts as having looked at that task.
    public static func needsYou(in tasks: [AnchorSession], since seenAt: Date) -> EdgeBuoy? {
        var strongest: EdgeBuoySignal?
        var count = 0
        for task in tasks {
            let looked = max(seenAt, task.goal.userPlan?.reviewedAt ?? .distantPast)
            guard let signal = EdgeBuoySignal.unseen(in: [task], since: looked) else { continue }
            count += 1
            strongest = max(strongest ?? signal, signal)
        }
        return strongest.map { EdgeBuoy(signal: $0, count: count) }
    }

    /// More tasks, or a more pressing reason, than before.
    public func isNews(after previous: EdgeBuoy?) -> Bool {
        guard let previous else { return true }
        return signal > previous.signal || count > previous.count
    }
}
