import Foundation

/// Describes whether the foreground projection can be presented as current.
/// Historical process values remain unchanged; presentation decides whether
/// they are live or only the last state observed from a peer.
public enum ProjectionAvailability: Hashable, Sendable {
    case empty
    case syncing(lastObservedAt: Date?)
    case live(lastObservedAt: Date)
    case lastKnown(lastObservedAt: Date?)

    public var isLive: Bool {
        if case .live = self { return true }
        return false
    }

    public var isLastKnown: Bool {
        if case .lastKnown = self { return true }
        return false
    }

    public var lastObservedAt: Date? {
        switch self {
        case .empty:
            nil
        case let .syncing(lastObservedAt), let .lastKnown(lastObservedAt):
            lastObservedAt
        case let .live(lastObservedAt):
            lastObservedAt
        }
    }
}
