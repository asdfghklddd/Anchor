#if os(macOS)
import AnchorDesign
import SwiftUI

struct MacSidebarRail: View {
    let isExpanded: Bool
    @Binding var requestsToggleFocus: Bool
    let onToggle: () -> Void
    let onCollapse: () -> Void

    @FocusState private var isToggleFocused: Bool

    var body: some View {
        VStack {
            Button {
                isToggleFocused = true
                onToggle()
            } label: {
                HarborAnchorGlyph(color: AnchorPalette.brandDeep)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .frame(width: 44, height: 44)
                    .macLiquidGlass(in: .circle)

            }
            .buttonStyle(.plain)
            .focused($isToggleFocused)
            .background {
                if isExpanded {
                    // Register Escape without placing a dismiss layer over the workspace.
                    Button(L10n.navigationCollapse, action: onCollapse)
                        .keyboardShortcut(.cancelAction)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .accessibilityHidden(true)
                }
            }
            // [VERIFY] The label follows the visible drawer state.
            .accessibilityLabel(L10n.navigationExpand)
            .accessibilityValue(isExpanded ? L10n.navigationExpanded : L10n.navigationCollapsed)
            .accessibilityInputLabels([L10n.appName, L10n.navigationExpand, L10n.navigationCollapse])
            .accessibilityIdentifier("mac.sidebar.toggle")
            .help(L10n.navigationExpand)

        }
        .frame(width: 44, height: 44)
        .onChange(of: requestsToggleFocus) { _, shouldFocus in
            guard shouldFocus else { return }
            isToggleFocused = true
            requestsToggleFocus = false
        }
    }
}
#endif
