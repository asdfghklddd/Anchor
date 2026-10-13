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
