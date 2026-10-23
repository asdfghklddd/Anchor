#if os(iOS)
import AnchorDesign
import SwiftUI

/// One tinted swell over a task when a result for it arrives, then stillness:
/// the held state (its words and symbol) is the record, the swell only the news.
struct ResultSwell: View {
    let trigger: Int
    let tone: Color
    let cornerRadius: CGFloat
    let reduceMotion: Bool

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, rise in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tone.opacity(0.28 * rise))
                    .scaleEffect(reduceMotion ? 1 : 1 + 0.04 * rise)
            } keyframes: { _ in
                CubicKeyframe(1, duration: reduceMotion ? 0.12 : 0.24)
                LinearKeyframe(1, duration: 0.3)
                CubicKeyframe(0, duration: 0.8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
#endif
