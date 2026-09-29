#if os(macOS)
import SwiftUI

/// One interpolated journey keeps position, heel and opacity in phase on reversal.
struct AnchorBoatSailingModifier: AnimatableModifier {
    var progress: CGFloat
    let reduceMotion: Bool
    let restingOpacity: Double

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let p = min(1, max(0, progress))
        let underway = sin(.pi * p)
        content
            .rotationEffect(.degrees(reduceMotion ? 0 : -3.2 * underway), anchor: .bottom)
            .offset(x: reduceMotion ? 0 : 44 * p, y: reduceMotion ? 0 : -1.4 * underway)
            // Keep the boat legible until it reaches its resting berth.
            .opacity(1 - (1 - restingOpacity) * Double(p * p))
    }
}
#endif
