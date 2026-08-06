#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation
import SwiftUI

struct MacFreshnessBanner: View {
    let observedAt: Date?
    let onRetry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.small) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.stale)
                        .font(.callout.weight(.semibold))
                    HStack(spacing: 4) {
                        Text(L10n.lastUpdated)
                        if let observedAt {
                            Text(observedAt, style: .relative)
                        } else {
                            Text(L10n.unknown)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(AnchorPalette.sourceInk("sand"))
            }

            Spacer(minLength: AnchorSpacing.small)

            if let onRetry {
                Button(L10n.retry, action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, AnchorSpacing.large)
        .padding(.vertical, AnchorSpacing.small)
        .frame(maxWidth: 900)
        .background(AnchorPalette.sand.opacity(0.14), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AnchorPalette.sand.opacity(0.36), lineWidth: 1)
        }
        .padding(.horizontal, AnchorSpacing.large)
        .padding(.top, AnchorSpacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.freshness.banner")
    }
}
#endif
