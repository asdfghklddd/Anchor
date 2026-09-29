#if os(macOS)
import AnchorDesign
import Foundation
import SwiftUI

/// Keeps the display timeline paused unless a pointer is actively over the boat.
struct AnchorEdgeBoatArtwork: View {
    let isWorking: Bool
    let isHovering: Bool
    let hoverBias: CGFloat
    let hoverStartedAt: Date
    var anchorTravel: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: !isHovering || reduceMotion
            )
        ) { timeline in
            let elapsed = max(0, timeline.date.timeIntervalSince(hoverStartedAt))
            let wave = isHovering && !reduceMotion
                ? CGFloat(sin(elapsed * 2 * .pi / 1.8))
                : 0

            let release = reduceMotion ? 0 : sin(.pi * anchorTravel) * (1 - anchorTravel)
            HarborBoatGlyph(wind: reduceMotion ? 0 : wave * 0.5 + hoverBias * 0.3)
            .frame(width: 64, height: 64)
            .offset(y: wave * 0.7 + release * 1.8)
            .rotationEffect(
                .degrees(
                    reduceMotion
                        ? 0
                        : Double(hoverBias) * 0.65 + Double(wave) * 0.45 + Double(release) * 2.4
                )
            )
            .animation(reduceMotion ? nil : AnchorMotion.micro, value: hoverBias)
        }
    }
}
#endif
