#if os(macOS)
/// State transitions that can earn optional audio feedback.
public enum AnchorEdgeSoundCue: Sendable, Equatable, CaseIterable {
    /// The first anchor reaches the water.
    case anchorLanded
    /// Another task joins work that is already anchored.
    case anchorJoined
    /// One of several anchored tasks finishes; the anchor stays down.
    case anchorReleased
    /// The last anchor is stowed aboard.
    case anchorRetrieved

    public static let enabledDefaultsKey = "anchor.mac.edge.sound.enabled"
}
#endif
