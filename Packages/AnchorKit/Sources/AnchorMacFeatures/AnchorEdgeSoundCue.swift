#if os(macOS)
/// State transitions that can earn optional audio feedback.
public enum AnchorEdgeSoundCue: Sendable, Equatable {
    case anchorLanded
    case anchorRetrieved

    public static let enabledDefaultsKey = "anchor.mac.edge.sound.enabled"
}
#endif
