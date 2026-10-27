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
    /// When set, a quiet note beside the link says how fresh this copy is.
    var freshness: SyncFreshness? = nil
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
        .padding(.horizontal, 20)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)

    }

    private var standardContent: some View {
        HStack(spacing: 10) {
            profileButton
            brandBlock
            Spacer()
            auxiliaryButton
            settingsButton
        }
        .frame(minHeight: 47)
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
            ProfileAvatar(size: 47)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityLabel(L10n.profile)
        .accessibilityIdentifier("topbar.profile.button")
    }

    private var brandBlock: some View {
        Button { onConnection?() } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName).font(.system(size: 16, weight: .bold)).foregroundStyle(HomeStyle.ink)
                HStack(spacing: 29) {
                    // The link changing state crossfades its words in place.
                    Text(connectionLabel)
                        .contentTransition(.opacity)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(connectionColor)
                        .padding(.horizontal, 13.5)
                        .frame(height: 19)
                        .background(AnchorIOSStyle.surface, in: .capsule)
                        .shadow(color: HomeStyle.cardShadow.opacity(0.14), radius: 3, y: 2)
                        .fixedSize()
                        .animation(AnchorMotion.micro, value: connectionLabel)
                    if let freshness {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text(SyncText.short(for: freshness, now: context.date))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(HomeStyle.synced)
                                .lineLimit(1)
                                // A long note truncates rather than pushing settings to a second row.
                                .frame(maxWidth: 110, alignment: .leading)
                        }
                    }
                }
            }
            // Sits a little low, as in the mockup.
            .offset(y: 4)
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

    private var connectionColor: Color {
        switch connection {
        case .connected: HomeStyle.linked
        case .pairing: AnchorPalette.interaction
        // A sleeping or closed Mac is ordinary; only actionable problems get warm colors (P2).
        case .disconnected, .unavailable: AnchorIOSStyle.secondaryText
        case .permissionDenied: AnchorStateTone.attention.ink
        case .failed: AnchorStateTone.failed.ink
        }
    }
}
#endif
