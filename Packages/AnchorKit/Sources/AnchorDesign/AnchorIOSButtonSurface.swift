#if os(iOS)
import SwiftUI

/// Read environment values in an installed view, including when another style delegates here.
struct AnchorIOSButtonSurface: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
    }
}
#endif
