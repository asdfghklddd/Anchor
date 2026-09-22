#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProjectionStatusBanners: View {
    let projection: SessionProjection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AnchorSpacing.small) {
            if let errorMessage = projection.errorMessage {
                statusBanner(
                    title: errorMessage,
                    symbol: "wifi.exclamationmark",
                    tint: .red
                )
                .id("error:\(errorMessage)")
                .transition(statusTransition)
            } else if projection.isStale {
                statusBanner(
                    title: L10n.stale,
                    symbol: "clock.badge.exclamationmark",
                    tint: AnchorPalette.attention
                )
                .id("stale")
                .transition(statusTransition)
            }

            if projection.session?.presence == .unknown {
                statusBanner(
                    title: L10n.connectionUnknownDetail,
                    symbol: "location.slash.fill",
                    tint: AnchorPalette.attention
                )
                .id("presence-unknown")
                .transition(statusTransition)
            }
        }
        .animation(statusAnimation, value: motionKey)
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

    private var motionKey: String {
        "\(projection.errorMessage ?? "")|\(projection.isStale)|\(projection.session?.presence == .unknown)"
    }

    private var statusTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .scale(scale: 0.98, anchor: .top).combined(with: .opacity)
    }

    private var statusAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.panel
    }
}
#endif
