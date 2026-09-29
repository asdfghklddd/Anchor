#if os(macOS)
import AnchorDesign
import SwiftUI

struct MacErrorBanner: View {
    let message: String
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.small) {
            Label {
                Text(displayMessage)
                    .font(.callout.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AnchorPalette.coral)
            }

            Spacer(minLength: AnchorSpacing.small)

            if let onRetry {
                Button(L10n.retry, action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.close)
        }
        .padding(.horizontal, AnchorSpacing.large)
        .padding(.vertical, AnchorSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorPalette.coral.opacity(0.12), in: .rect(cornerRadius: 12))
        // Tint sits over an opaque adaptive surface, never over page content.
        .background(AnchorPalette.fluoriteSurface, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AnchorPalette.coral.opacity(0.32), lineWidth: 1)
        }
        .padding(.horizontal, AnchorSpacing.xLarge)
        .padding(.top, AnchorSpacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.error.banner")
    }

    private var displayMessage: String {
        // Translate this recovery condition at the UI boundary without changing persisted state.
        if message.localizedCaseInsensitiveContains("could not be decoded"),
           message.localizedCaseInsensitiveContains("retained for recovery") {
            return L10n.recoveryReadError
        }
        return message
    }
}
#endif
