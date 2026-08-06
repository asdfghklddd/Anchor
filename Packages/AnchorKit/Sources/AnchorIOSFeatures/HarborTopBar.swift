#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborTopBar: View {
    let connection: ConnectionState
    let unreadCount: Int
    let auxiliaryLabel: String?
    let onProfile: () -> Void
    let onNotifications: () -> Void
    let onAuxiliary: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityContent
            } else {
                ViewThatFits(in: .horizontal) {
                    standardContent
                    accessibilityContent
                }
            }
        }
        .tint(AnchorPalette.ink)
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 5)
        .background(AnchorPalette.paper)
        .shadow(color: AnchorPalette.ink.opacity(0.045), radius: 11, y: 7)
    }

    private var standardContent: some View {
        HStack(spacing: AnchorSpacing.small) {
            profileButton
            brandBlock
            Spacer()
            auxiliaryButton
            notificationsButton
        }
        .frame(minHeight: 56)
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: AnchorSpacing.small) {
                profileButton
                brandBlock
                Spacer(minLength: 0)
            }

            HStack(spacing: AnchorSpacing.small) {
                Spacer(minLength: 0)
                auxiliaryButton
                notificationsButton
            }
        }
    }

    private var profileButton: some View {
        Button(action: onProfile) {
            HarborClayAvatar()
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.profile)
    }

    private var brandBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.appName)
                .font(.headline.bold())
                .foregroundStyle(AnchorPalette.ink)
            Label(connectionLabel, systemImage: connectionSymbol)
                .font(.caption2)
                .foregroundStyle(connectionColor)
                .accessibilityIdentifier("topbar.connection")
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var auxiliaryButton: some View {
        if let auxiliaryLabel, let onAuxiliary {
            Button(action: onAuxiliary) {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(auxiliaryLabel)
        }
    }

    private var notificationsButton: some View {
        Button(action: onNotifications) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                if unreadCount > 0 {
                    Circle()
                        .fill(AnchorPalette.sand)
                        .frame(width: 8, height: 8)
                        .overlay { Circle().stroke(AnchorPalette.paper, lineWidth: 2) }
                        .offset(x: -4, y: 4)
                }
            }
        }
        .accessibilityLabel(L10n.notifications)
        .accessibilityValue(unreadCount == 0 ? "" : "\(unreadCount)")
    }

    private var connectionLabel: String {
        switch connection {
        case .connected: L10n.macConnected
        case .pairing: L10n.remoteSyncing
        case .disconnected, .unavailable: L10n.disconnected
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        }
    }

    private var connectionSymbol: String {
        switch connection {
        case .connected: "circle.fill"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected, .unavailable: "wifi.slash"
        case .permissionDenied: "hand.raised.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionColor: Color {
        switch connection {
        case .connected: AnchorPalette.mintInk
        case .pairing: AnchorPalette.link
        case .disconnected, .unavailable, .permissionDenied, .failed: AnchorPalette.coral
        }
    }
}
#endif
