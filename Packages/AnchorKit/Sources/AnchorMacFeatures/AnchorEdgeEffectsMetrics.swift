#if os(macOS)
import Foundation

struct AnchorEdgeEffectsMetrics {
    static let ropeStartY: CGFloat = 74
    static let anchorCenterOffset: CGFloat = 13
    static let anchorHalfHeight: CGFloat = 17
    static let anchorExitDepth: CGFloat = 34
    static let waterlineInset: CGFloat = 3

    let height: CGFloat

    var anchorDestinationY: CGFloat {
        max(Self.ropeStartY, height + Self.anchorExitDepth)
    }

    var visibleWaterlineY: CGFloat {
        max(Self.ropeStartY, height - Self.waterlineInset)
    }

    var waterImpactTravel: CGFloat {
        let travelDistance = anchorDestinationY - Self.ropeStartY
        guard travelDistance > 0 else { return 1 }
        // Trigger on first contact; the remaining travel carries the anchor below water.
        let anchorBottomOffset = Self.anchorCenterOffset + Self.anchorHalfHeight
        let ropeYAtImpact = height - anchorBottomOffset
        return min(1, max(0, (ropeYAtImpact - Self.ropeStartY) / travelDistance))
    }

    func ropeEndY(at travel: CGFloat) -> CGFloat {
        Self.ropeStartY + (anchorDestinationY - Self.ropeStartY) * travel
    }

    var impactTime: CGFloat { sqrt(waterImpactTravel) * 0.88 }

    func travel(at time: CGFloat) -> CGFloat {
        let t = min(1, max(0, time))
        let contact = waterImpactTravel
        guard contact > 0, contact < 1 else { return t * t }
        if t <= impactTime {
            return contact * pow(t / impactTime, 2)
        }
        // Water drag absorbs the impact velocity while the anchor sinks out of view.
        let u = (t - impactTime) / (1 - impactTime)
        let damping = min(12, max(1, (2 * contact / impactTime) * (1 - impactTime) / (1 - contact)))
        let submerged = (1 - exp(-damping * u)) / (1 - exp(-damping))
        return contact + (1 - contact) * submerged
    }
}
#endif
