#if os(macOS)
import AnchorDesign
import Foundation

/// Fixed berth geometry shared by the control and effects panels.
///
/// Coordinates are top-left in the effects panel. The control panel shares its top
/// and right edges, so the boat, its waterline and the short water column below
/// it line up without depending on screen height.
struct AnchorEdgeEffectsMetrics {
    static let controlSide: CGFloat = 88
    static let boatSide: CGFloat = 64
    static let panelWidth: CGFloat = 140
    /// How deep the anchor sinks below the waterline before it fades from view.
    static let sinkDepth: CGFloat = 84
    static let anchorSize = CGSize(width: 14, height: 17)
    /// The rope ties to the anchor's ring, just below the glyph's top edge.
    static let anchorCenterOffset: CGFloat = 7.5
    static let anchorHalfHeight: CGFloat = 8.5

    static var boatOrigin: CGPoint {
        let inset = (controlSide - boatSide) / 2
        return CGPoint(x: panelWidth - controlSide + inset, y: inset)
    }

    static var ropeStart: CGPoint {
        CGPoint(
            x: boatOrigin.x + HarborBoatGlyph.ropePoint.x * boatSide,
            y: boatOrigin.y + HarborBoatGlyph.ropePoint.y * boatSide
        )
    }

    static var waterlineY: CGFloat {
        boatOrigin.y + HarborBoatGlyph.waterlineY * boatSide
    }

    /// The anchor is lifted over the transom before it is thrown.
    static var stowedRopeEndY: CGFloat { ropeStart.y - 14 }
    static var anchorDestinationY: CGFloat { waterlineY + sinkDepth }
    /// The mask has faded the anchor out before it reaches the destination, so the
    /// column ends there instead of reserving room for its body.
    static var height: CGFloat { (anchorDestinationY + 4).rounded(.up) }

    /// Normalized fall time at which the anchor's lowest point meets the water.
    let impactTime: CGFloat = 0.16

    var waterImpactTravel: CGFloat {
        let travelDistance = Self.anchorDestinationY - Self.stowedRopeEndY
        let ropeYAtImpact = Self.waterlineY - Self.anchorCenterOffset - Self.anchorHalfHeight
        return min(1, max(0, (ropeYAtImpact - Self.stowedRopeEndY) / travelDistance))
    }

    func ropeEndY(at travel: CGFloat) -> CGFloat {
        Self.stowedRopeEndY + (Self.anchorDestinationY - Self.stowedRopeEndY) * travel
    }

    /// The anchor drifts slightly away from the hull as it pays out rope.
    func anchorX(at travel: CGFloat) -> CGFloat {
        Self.ropeStart.x - 2 - 9 * travel
    }

    func travel(at time: CGFloat) -> CGFloat {
        let t = min(1, max(0, time))
        let contact = waterImpactTravel
        guard contact > 0, contact < 1 else { return t * t }
        if t <= impactTime {
            return contact * pow(t / impactTime, 2)
        }
        // The anchor plunges, then the paying-out rope slows it as it settles out of sight.
        let u = (t - impactTime) / (1 - impactTime)
        return contact + (1 - contact) * (1 - pow(1 - u, 2.6))
    }
}

/// Panel sizes the app target needs to place the berth.
public enum AnchorEdgeBerth {
    public static let controlSide = AnchorEdgeEffectsMetrics.controlSide
    public static let effectsSize = CGSize(
        width: AnchorEdgeEffectsMetrics.panelWidth,
        height: AnchorEdgeEffectsMetrics.height
    )
}
#endif
