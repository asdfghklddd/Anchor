#if os(macOS)
import Foundation
import Testing
@testable import AnchorMacFeatures

@Test("The anchor meets the boat's waterline, then sinks a fixed depth out of sight")
func waterlineCollisionGeometry() {
    let metrics = AnchorEdgeEffectsMetrics()
    let waterline = AnchorEdgeEffectsMetrics.waterlineY
    let impactRopeY = metrics.ropeEndY(at: metrics.waterImpactTravel)
    let anchorBottom = impactRopeY
        + AnchorEdgeEffectsMetrics.anchorCenterOffset
        + AnchorEdgeEffectsMetrics.anchorHalfHeight
    let stowedAnchorBottom = metrics.ropeEndY(at: 0)
        + AnchorEdgeEffectsMetrics.anchorCenterOffset
        + AnchorEdgeEffectsMetrics.anchorHalfHeight

    #expect(abs(anchorBottom - waterline) < 0.001)
    #expect(stowedAnchorBottom < waterline)
    #expect(metrics.waterImpactTravel > 0)
    #expect(metrics.waterImpactTravel < 1)
    // The drop stays inside the berth's short water column, never the full screen.
    #expect(abs(metrics.ropeEndY(at: 1) - waterline - AnchorEdgeEffectsMetrics.sinkDepth) < 0.001)
    #expect(AnchorEdgeEffectsMetrics.height < 200)
    #expect(AnchorEdgeEffectsMetrics.height >= metrics.ropeEndY(at: 1))

    #expect(metrics.travel(at: 0) == 0)
    #expect(abs(metrics.travel(at: 1) - 1) < 0.001)
    #expect(abs(metrics.travel(at: metrics.impactTime) - metrics.waterImpactTravel) < 0.001)
    #expect(metrics.travel(at: metrics.impactTime - 0.01) < metrics.waterImpactTravel)
    // The rope pays out without reversing.
    let samples = (0...100).map { metrics.travel(at: CGFloat($0) / 100) }
    #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
}
#endif
