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
                    tint: AnchorPalette.coral
                )
            } else if projection.isStale {
                statusBanner(
                    title: L10n.stale,
                    symbol: "clock.badge.exclamationmark",
                    tint: AnchorPalette.sand
                )
            }

            if projection.session?.presence == .unknown {
                statusBanner(
                    title: L10n.connectionUnknownDetail,
                    symbol: "location.slash.fill",
                    tint: AnchorPalette.sand
                )
            }
        }
    }

    private func statusBanner(title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.bold())
            .foregroundStyle(AnchorPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, AnchorSpacing.medium)
            .background(tint.opacity(0.22), in: .rect(cornerRadius: 18, style: .continuous))
    }
}
#endif
