#if os(iOS)
import SwiftUI

/// Read environment values in an installed view, including when another style delegates here.
struct AnchorIOSButtonSurface: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AnchorIOSStyle.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AnchorIOSStyle.pageInset)
            .background(
                isEnabled ? AnchorIOSStyle.cyan : AnchorIOSStyle.border,
                in: .rect(cornerRadius: AnchorIOSStyle.cardRadius)
            )
            .opacity(configuration.isPressed ? 0.82 : isEnabled ? 1 : 0.62)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .animation(reduceMotion ? nil : configuration.isPressed ? AnchorMotion.press : AnchorMotion.release,
                       value: configuration.isPressed)
            // A main action is felt as the finger lands.
            .sensoryFeedback(trigger: configuration.isPressed) { _, now in
                now ? .impact(weight: .light, intensity: 0.7) : nil
            }
    }
}
#endif
