#if os(macOS)
import Foundation
import Testing
@testable import AnchorMacFeatures

@Test(
    "The screen bottom is the water collision line and the anchor exits below it",
    arguments: [CGFloat(480), CGFloat(760), CGFloat(1_080)]
)
func waterlineCollisionGeometry(height: CGFloat) {
    let metrics = AnchorEdgeEffectsMetrics(height: height)
    let impactRopeY = metrics.ropeEndY(at: metrics.waterImpactTravel)
    let anchorBottom = impactRopeY
        + AnchorEdgeEffectsMetrics.anchorCenterOffset
        + AnchorEdgeEffectsMetrics.anchorHalfHeight
    let finalAnchorTop = metrics.ropeEndY(at: 1)
        + AnchorEdgeEffectsMetrics.anchorCenterOffset
        - AnchorEdgeEffectsMetrics.anchorHalfHeight

    #expect(abs(anchorBottom - height) < 0.001)
    #expect(metrics.waterImpactTravel > 0)
    #expect(metrics.waterImpactTravel < 1)
    #expect(finalAnchorTop > height)

    #expect(metrics.travel(at: 0) == 0)
    #expect(abs(metrics.travel(at: 1) - 1) < 0.001)
    #expect(abs(metrics.travel(at: metrics.impactTime) - metrics.waterImpactTravel) < 0.001)
    #expect(metrics.travel(at: metrics.impactTime - 0.01) < metrics.waterImpactTravel)
    // Drag must slow the submerged motion without reversing the rope.
    let samples = (0...100).map { metrics.travel(at: CGFloat($0) / 100) }
    #expect(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
}
#endif
