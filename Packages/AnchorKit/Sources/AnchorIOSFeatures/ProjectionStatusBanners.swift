#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProjectionStatusBanners: View {
    let projection: SessionProjection

    var body: some View {
        VStack(spacing: AnchorSpacing.small) {
            if let errorMessage = projection.errorMessage {
                statusBanner(
                    title: errorMessage,
                    symbol: "wifi.exclamationmark",
                    tint: .red
                )
            } else if projection.isStale {
                statusBanner(
                    title: L10n.stale,
                    symbol: "clock.badge.exclamationmark",
                    tint: AnchorPalette.attention
                )
            }

            if projection.session?.presence == .unknown {
                statusBanner(
                    title: L10n.connectionUnknownDetail,
                    symbol: "location.slash.fill",
                    tint: AnchorPalette.attention
                )
            }
        }
    }

    private func statusBanner(title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.bold())
            .foregroundStyle(AnchorPalette.brandDeep)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, AnchorSpacing.medium)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tint.opacity(0.34), lineWidth: 1)
            }
    }
}
#endif
