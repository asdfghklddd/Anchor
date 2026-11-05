// Role: press feel. `.card` (0.98, no haptic, since scrolls start on cards) and `.control` (0.9, light tap on touch-down).

import SwiftUI

/// A physical response to a press, without delaying navigation: it gives quickly
/// under the finger and springs back when let go.
public struct AnchorPressButtonStyle: ButtonStyle {
    /// Which physical response a press gets.
    public enum Feel: Sendable {
        /// Cards and rows: a slight give and nothing to feel, since scrolls often start on them.
        case card
        /// Small controls: a clearer press, with a light tap as the finger lands.
        case control
    }

    @AnchorReducedMotion private var reduceMotion
    private let feel: Feel

    public init(_ feel: Feel = .card) {
        self.feel = feel
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(reduceMotion || !pressed ? 1 : feel == .card ? 0.98 : 0.9)
            .opacity(pressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : pressed ? AnchorMotion.press : AnchorMotion.release, value: pressed)
            .sensoryFeedback(trigger: pressed) { _, now in
                now && feel == .control ? .impact(weight: .light, intensity: 0.55) : nil
            }
    }
}
