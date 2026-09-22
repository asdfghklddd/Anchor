#if os(iOS)
import AnchorCore
import AnchorDesign
import Foundation
import SwiftUI

struct ProjectionStatusBanners: View {
    let projection: SessionProjection

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Present one prioritized status so related connection symptoms never stack.
        Group {
            if let errorMessage = projection.errorMessage {
                ProjectionStatusNotice(
                    title: L10n.actionFailed,
                    detail: errorMessage,
                    freshness: freshnessText,
                    symbol: "wifi.exclamationmark",
                    tint: .red
                )
                .id("error:\(errorMessage)")
                .transition(statusTransition)
            } else if hasPermissionIssue {
                ProjectionStatusNotice(
                    title: L10n.permissionDenied,
                    detail: L10n.permissionDeniedDetail,
                    freshness: freshnessText,
                    symbol: "hand.raised.fill",
                    tint: AnchorPalette.attention
                )
                .id("permission-denied")
                .transition(statusTransition)
            } else if projection.session?.presence == .unknown {
                ProjectionStatusNotice(
                    title: L10n.presenceDetectionPaused,
                    detail: L10n.presenceDetectionPausedDetail,
                    freshness: freshnessText,
                    symbol: "location.slash.fill",
                    tint: AnchorPalette.attention
                )
                .id("presence-unknown")
                .transition(statusTransition)
            } else if let freshnessText {
                Label(freshnessText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .padding(.horizontal, AnchorSpacing.xSmall)
                    .accessibilityIdentifier("status.data.freshness")
                    .id("stale")
                    .transition(statusTransition)
            }
        }
        .animation(statusAnimation, value: motionKey)
    }

    private var hasPermissionIssue: Bool {
        projection.connection == .permissionDenied || projection.proximity == .permissionDenied
    }

    private var freshnessText: String? {
        guard projection.isStale, let dataObservedAt = projection.dataObservedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeDate = formatter.localizedString(
            for: dataObservedAt,
            relativeTo: projection.generatedAt
        )
        return "\(L10n.lastUpdated) \(relativeDate)"
    }

    private var motionKey: String {
        "\(projection.errorMessage ?? "")|\(hasPermissionIssue)|\(projection.isStale)|\(projection.session?.presence == .unknown)"
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
