#if os(macOS)
import AnchorDesign
import SwiftUI

public struct AnchorEdgeEffectsView: View {
    private let presentation: AnchorEdgePresentationModel
    @AnchorReducedMotion private var reduceMotion

    private static let ropeAbove = Color(red: 0.12, green: 0.52, blue: 0.88)
    private static let ropeBelow = Color(red: 0.44, green: 0.85, blue: 0.94)

    public init(presentation: AnchorEdgePresentationModel) {
        self.presentation = presentation
    }

    public var body: some View {
        let metrics = AnchorEdgeEffectsMetrics()
        let travel = presentation.anchorTravel
        let cast = reduceMotion ? CGSize.zero : presentation.throwOffset
        let sway = reduceMotion ? 0 : presentation.anchorSway + cast.width
        let bend = reduceMotion ? 0 : presentation.ropeBend + cast.width * 0.45
        let start = AnchorEdgeEffectsMetrics.ropeStart
        let end = CGPoint(
            x: metrics.anchorX(at: travel) + sway,
            y: metrics.ropeEndY(at: travel) + cast.height
        )
        let waterlineY = AnchorEdgeEffectsMetrics.waterlineY
        // Where the rope meets the surface; ripples and splashes gather here.
        let entryX = start.x + (end.x - start.x)
            * min(1, max(0, (waterlineY - start.y) / max(1, end.y - start.y)))

        ZStack(alignment: .topLeading) {
            if presentation.phase.showsAnchor {
                ZStack(alignment: .topLeading) {
                    AnchorEdgeRopeShape(start: start, end: end, bend: bend)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Self.ropeAbove, location: 0),
                                    .init(color: Self.ropeAbove, location: Self.unit(waterlineY - 1)),
                                    .init(color: Self.ropeBelow, location: Self.unit(waterlineY + 3)),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                        )
                    AnchorEdgeAnchorGlyph()
                        .frame(
                            width: AnchorEdgeEffectsMetrics.anchorSize.width,
                            height: AnchorEdgeEffectsMetrics.anchorSize.height
                        )
                        .rotationEffect(
                            .degrees(Double(sway) * -0.9),
                            anchor: UnitPoint(x: 0.5, y: 1 / AnchorEdgeEffectsMetrics.anchorSize.height)
                        )
                        .position(x: end.x, y: end.y + AnchorEdgeEffectsMetrics.anchorCenterOffset)
                        .opacity(reduceMotion ? 1 : min(1, max(presentation.throwProgress * 5, travel * 8)))
                }
                // Everything below the surface fades with depth, so the settled anchor
                // rests out of sight with only its rope leading into the water.
                .mask(Self.depthMask)

                AnchorEdgeWaterSurface()
                    .frame(width: 48, height: 10)
                    .position(x: entryX, y: waterlineY + 1)
                    .opacity(presentation.waterVisibility)

                if presentation.showsSplashParticles, !reduceMotion {
                    AnchorSplashParticleView(
                        intensity: presentation.waterImpactIntensity,
                        startedAt: presentation.splashStartedAt ?? .now
                    )
                    .id(presentation.splashTrigger)
                    .frame(width: 96, height: 56)
                    .position(
                        x: metrics.anchorX(at: metrics.waterImpactTravel) + presentation.waterImpactXOffset,
                        y: waterlineY - 24
                    )
                }
            }
        }
        .frame(width: AnchorEdgeEffectsMetrics.panelWidth, height: AnchorEdgeEffectsMetrics.height,
               alignment: .topLeading)
        .clipped()
        // On the left edge the whole berth is mirrored, so the rope still leaves the stern.
        .scaleEffect(x: presentation.side == .leading ? -1 : 1)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private static var depthMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: unit(AnchorEdgeEffectsMetrics.waterlineY)),
                .init(color: .black.opacity(0.55), location: unit(AnchorEdgeEffectsMetrics.waterlineY + 6)),
                .init(color: .black.opacity(0.12),
                      location: unit(AnchorEdgeEffectsMetrics.waterlineY + AnchorEdgeEffectsMetrics.sinkDepth * 0.40)),
                .init(color: .clear,
                      location: unit(AnchorEdgeEffectsMetrics.waterlineY + AnchorEdgeEffectsMetrics.sinkDepth * 0.72)),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private static func unit(_ y: CGFloat) -> CGFloat {
        min(1, max(0, y / AnchorEdgeEffectsMetrics.height))
    }
}
#endif
