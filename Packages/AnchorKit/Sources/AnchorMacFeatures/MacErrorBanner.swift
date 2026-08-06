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
                Text(message)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
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
        .frame(maxWidth: 900)
        .background(AnchorPalette.coral.opacity(0.12), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AnchorPalette.coral.opacity(0.32), lineWidth: 1)
        }
        .padding(.horizontal, AnchorSpacing.large)
        .padding(.top, AnchorSpacing.small)
        .accessibilityElement(children: .contain)
    }
}
#endif
