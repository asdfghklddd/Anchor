import SwiftUI

/// A subtle physical response for card-like controls without delaying navigation.
public struct AnchorPressButtonStyle: ButtonStyle {
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
    }
}
