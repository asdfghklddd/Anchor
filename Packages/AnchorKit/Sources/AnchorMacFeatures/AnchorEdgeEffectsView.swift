#if os(macOS)
import SwiftUI

public struct AnchorEdgeEffectsView: View {
    private let presentation: AnchorEdgePresentationModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(presentation: AnchorEdgePresentationModel) {
        self.presentation = presentation
    }

    public var body: some View {
        GeometryReader { geometry in
            let metrics = AnchorEdgeEffectsMetrics(height: geometry.size.height)
            let x = geometry.size.width - 44
            let cast = reduceMotion ? CGSize.zero : presentation.throwOffset
            let y = metrics.ropeEndY(at: presentation.anchorTravel) + cast.height
            let sway = reduceMotion ? 0 : presentation.anchorSway + cast.width
            let bend = reduceMotion ? 0 : presentation.ropeBend + cast.width * 0.45
            ZStack(alignment: .topLeading) {
                if presentation.phase.showsAnchor {
                    AnchorEdgeRopeShape(
                        start: CGPoint(x: x, y: AnchorEdgeEffectsMetrics.ropeStartY),
                        end: CGPoint(x: x + sway, y: y),
                        bend: bend
                    )
                    .stroke(Color(red: 0.49, green: 0.70, blue: 0.93).opacity(0.65),
                            style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    AnchorEdgeAnchorGlyph()
                        .frame(width: 30, height: 34)
                        .rotationEffect(.degrees(Double(sway) * -0.65), anchor: UnitPoint(x: 0.5, y: 4.0 / 34.0))
                        .position(x: x + sway, y: y + 13)
                        .opacity(reduceMotion ? 1 : min(1, max(presentation.throwProgress * 5, presentation.anchorTravel * 8)))
                    AnchorEdgeWaterSurface()
                        .frame(width: 64, height: 14)
                        .position(x: x, y: metrics.visibleWaterlineY)
                        .opacity(presentation.waterVisibility)
                    if presentation.showsSplashParticles, !reduceMotion {
                        AnchorSplashParticleView(
                            intensity: presentation.waterImpactIntensity,
                            startedAt: presentation.splashStartedAt ?? .now
                        )
                        .id(presentation.splashTrigger)
                        .frame(width: 104, height: 72)
                        .position(
                            x: x + presentation.waterImpactXOffset,
                            y: metrics.visibleWaterlineY - 32
                        )
                    }
                }
            }
            .onAppear {
                presentation.updateEffectsHeight(geometry.size.height)
            }
            .onChange(of: geometry.size.height) { _, height in
                presentation.updateEffectsHeight(height)
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
#endif
