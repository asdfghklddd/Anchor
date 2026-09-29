#if os(macOS)
import AnchorDesign
import SwiftUI

struct AnchorSplashParticleView: View {
    let intensity: CGFloat
    let startedAt: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            AnchorSplashFrame(
                elapsed: timeline.date.timeIntervalSince(startedAt),
                intensity: intensity
            )
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
#endif
