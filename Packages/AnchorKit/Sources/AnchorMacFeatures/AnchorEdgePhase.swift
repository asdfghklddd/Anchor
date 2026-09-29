#if os(macOS)
public enum AnchorEdgePhase: Sendable, Equatable {
    case harbored
    case deploying
    case deployed
    case retrieving

    public var showsAnchor: Bool {
        self != .harbored
    }

    public var isWorking: Bool {
        self != .harbored
    }
}
#endif
