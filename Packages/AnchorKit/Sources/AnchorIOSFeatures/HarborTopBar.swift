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

    var body: some View {
        HStack(spacing: AnchorSpacing.small) {
            Button(action: onProfile) {
                HarborClayAvatar()
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.profile)

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

            Spacer()

            if let auxiliaryLabel, let onAuxiliary {
                Button(action: onAuxiliary) {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(auxiliaryLabel)
            }

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
        .tint(AnchorPalette.ink)
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.vertical, 5)
        .frame(minHeight: 56)
        .background(AnchorPalette.paper)
        .shadow(color: AnchorPalette.ink.opacity(0.045), radius: 11, y: 7)
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
