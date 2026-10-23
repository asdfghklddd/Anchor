#if os(macOS)
import Foundation

/// Which screen edge the boat rests against.
public enum AnchorEdgeSide: String, Sendable {
    case leading
    case trailing

    /// +1 when the screen's middle lies to the right of the boat, −1 when it lies to the left.
    public var inward: CGFloat { self == .leading ? 1 : -1 }
}

/// Where the boat berths: a side, and how high up the screen. Like the iPhone's
/// floating ball, it can be dragged anywhere and always settles on the nearer side.
public struct AnchorEdgeDock: Equatable, Sendable {
    public var side: AnchorEdgeSide
    /// The boat's top edge, from the bottom (0) to the top (1) of the room it may use.
    public var height: CGFloat

    /// The lower-right berth the boat had before it could be moved.
    public static let standard = AnchorEdgeDock(side: .trailing, height: 0)

    public init(side: AnchorEdgeSide, height: CGFloat) {
        self.side = side
        self.height = min(1, max(0, height))
    }

    /// The vertical room for the boat's top edge. The water column under the
    /// boat stays above the Dock, and the boat stays below the menu bar.
    static func topRange(in visible: CGRect, controlSide: CGFloat, columnHeight: CGFloat) -> ClosedRange<CGFloat> {
        let low = visible.minY + max(columnHeight, controlSide)
        return low...max(low, visible.maxY)
    }

    /// The boat panel's frame for this berth.
    public func controlFrame(in visible: CGRect, controlSide: CGFloat, columnHeight: CGFloat) -> CGRect {
        let range = Self.topRange(in: visible, controlSide: controlSide, columnHeight: columnHeight)
        let top = range.lowerBound + (range.upperBound - range.lowerBound) * height
        let x = side == .leading ? visible.minX : visible.maxX - controlSide
        return CGRect(x: x, y: top - controlSide, width: controlSide, height: controlSide)
    }

    /// The berth nearest to where the person let go of the boat.
    public static func nearest(to frame: CGRect, in visible: CGRect, columnHeight: CGFloat) -> AnchorEdgeDock {
        let side: AnchorEdgeSide = frame.midX < visible.midX ? .leading : .trailing
        let range = topRange(in: visible, controlSide: frame.height, columnHeight: columnHeight)
        let span = range.upperBound - range.lowerBound
        let height = span > 0 ? (frame.maxY - range.lowerBound) / span : 0
        return AnchorEdgeDock(side: side, height: height)
    }

    // MARK: Saving

    private static let sideKey = "anchor.mac.edge.side"
    private static let heightKey = "anchor.mac.edge.height"

    public static func load(from defaults: UserDefaults) -> AnchorEdgeDock {
        guard let raw = defaults.string(forKey: sideKey), let side = AnchorEdgeSide(rawValue: raw) else {
            return .standard
        }
        return AnchorEdgeDock(side: side, height: defaults.double(forKey: heightKey))
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(side.rawValue, forKey: Self.sideKey)
        defaults.set(Double(height), forKey: Self.heightKey)
    }
}
#endif
