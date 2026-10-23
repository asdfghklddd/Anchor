#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborTopBar: View {
    let connection: ConnectionState
    let auxiliaryLabel: String?
    let onProfile: () -> Void
    let onSettings: () -> Void
    let onAuxiliary: (() -> Void)?


    var onConnection: (() -> Void)? = nil
    @AppStorage("anchor.profile.name", store: ProfilePreferences.store) private var displayName = "Anchor"

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
        .tint(AnchorPalette.brandDeep)
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 4)

    }

    private var standardContent: some View {
        HStack(spacing: AnchorSpacing.small) {
            profileButton
            brandBlock
            Spacer()
            auxiliaryButton
            settingsButton
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
                settingsButton
            }
        }
    }

    private var profileButton: some View {
        Button(action: onProfile) {
            ProfileAvatar(size: 48)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityLabel(L10n.profile)
        .accessibilityIdentifier("topbar.profile.button")
    }

    private var brandBlock: some View {
        Button { onConnection?() } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(displayName).font(.headline.bold()).foregroundStyle(AnchorPalette.brandDeep)
                // The link changing state morphs in place: icon replaced, words crossfaded.
                Label {
                    Text(connectionLabel).contentTransition(.opacity)
                } icon: {
                    Image(systemName: connectionSymbol).contentTransition(.symbolEffect(.replace))
                }
                .font(.caption).foregroundStyle(connectionColor)
                .animation(AnchorMotion.micro, value: connectionLabel)
            }
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityIdentifier("workspace.connection.action")
    }

    @ViewBuilder
    private var auxiliaryButton: some View {
        if let auxiliaryLabel, let onAuxiliary {
            Button(action: onAuxiliary) {
                Image(systemName: "slider.horizontal.3")
                    .font(.body.bold())
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .tint(AnchorPalette.interaction)
            .frame(width: 44, height: 44)
            .accessibilityLabel(auxiliaryLabel)
        }
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape")
                .font(.body.bold())
                .frame(width: 18, height: 18)
        }
        .foregroundStyle(AnchorIOSStyle.action)
        .frame(width: 44, height: 44)
        .background(AnchorIOSStyle.surface, in: .circle)
        .overlay { Circle().strokeBorder(AnchorIOSStyle.border, lineWidth: 1) }
        .shadow(color: AnchorIOSStyle.heading.opacity(0.08), radius: 6, y: 3)
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityLabel(L10n.settings)
        .accessibilityIdentifier("topbar.settings.button")
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
        case .connected: "link"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected, .unavailable: "wifi.slash"
        case .permissionDenied: "hand.raised.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionColor: Color {
        switch connection {
        case .connected: AnchorIOSStyle.success
        case .pairing: AnchorPalette.interaction
        // A sleeping or closed Mac is ordinary; only actionable problems get warm colors (P2).
        case .disconnected, .unavailable: AnchorIOSStyle.secondaryText
        case .permissionDenied: AnchorStateTone.attention.ink
        case .failed: AnchorStateTone.failed.ink
        }
    }
}
#endif
