#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The pairing card, laid out like the iPhone's AirPods card: what is happening
/// on top, the anchor in the middle, what to do at the bottom.
struct ConnectionSettingsView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?

    @AnchorReducedMotion private var reduceMotion
    /// Follows the hero: the words change as the check lands, not when the turn starts.
    @State private var revealedConnected: Bool
    @State private var pairingStatus = DevicePairingStatus.automatic
    @State private var showsManualCode = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    init(projection: SessionProjection, controller: (any LocalLinkControlling)?, startsWithCode: Bool = false) {
        self.projection = projection
        self.controller = controller
        _showsManualCode = State(initialValue: startsWithCode)
        _revealedConnected = State(initialValue: projection.connection == .connected)
    }

    private var isCompact: Bool { verticalSizeClass == .compact }
    private var isDenied: Bool { projection.connection == .permissionDenied || projection.proximity == .permissionDenied }
    private var entersCode: Bool {
        !revealedConnected && !isDenied && (showsManualCode || pairingStatus.phase == .verificationCodeRequired)
    }

    private var title: String {
        if revealedConnected { return PeerDeviceCopy.connected }
        if controller == nil { return L10n.disconnected }
        if isDenied { return L10n.permissionDenied }
        if entersCode { return L10n.pairingCode }
        return projection.connection == .failed ? L10n.actionFailed : L10n.pairingAutomatically
    }

    var body: some View {
        let layout = isCompact
            ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 14))
        let heroSize: CGFloat = isCompact ? 118 : 176
        let heroScale: CGFloat = entersCode ? 0.58 : 1
        ScrollView {
            VStack(spacing: isCompact ? 4 : 10) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
                    // One title dissolves into the next, rather than two overlapping.
                    .id(title)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(revealedConnected ? "connections.pairing.connected" : "connections.pairing.automatic")
                    .overlay(alignment: .trailing) {
                        Button(action: dismiss.callAsFunction) {
                            Image(systemName: "xmark").font(.caption.bold())
                                .frame(width: 28, height: 28)
                                .background(AnchorIOSStyle.border.opacity(0.5), in: .circle)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L10n.close)
                        .accessibilityIdentifier("connections.close")
                    }
                layout {
                    ConnectionHero(isConnected: projection.connection == .connected,
                                   size: heroSize,
                                   revealed: $revealedConnected)
                        .scaleEffect(heroScale)
                        .frame(width: isCompact ? heroSize * heroScale : nil, height: heroSize * heroScale)
                    if let controller {
                        ConnectionPairingSection(controller: controller,
                                                 connection: projection.connection,
                                                 isConnected: revealedConnected,
                                                 isDenied: isDenied,
                                                 entersCode: entersCode,
                                                 pairingStatus: $pairingStatus,
                                                 showsManualCode: $showsManualCode)
                    } else {
                        Text(L10n.connectionUnknownDetail)
                            .font(.caption)
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
            .frame(maxWidth: 500).frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : AnchorMotion.panel, value: entersCode)
            .animation(reduceMotion ? nil : AnchorMotion.panel, value: title)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollDismissesKeyboard(.interactively)
        .background(AnchorIOSStyle.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("connections.screen")
    }
}

extension View {
    /// The card's size and surface, wherever it opens from. A caption above it needs a little more room.
    func connectionCardPresentation(hasCaption: Bool = false) -> some View {
        modifier(ConnectionCardPresentation(hasCaption: hasCaption))
    }
}

private struct ConnectionCardPresentation: ViewModifier {
    let hasCaption: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    func body(content: Content) -> some View {
        let height: CGFloat = verticalSizeClass == .compact ? (hasCaption ? 340 : 260) : (hasCaption ? 440 : 350)
        content
            .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(height)])
            .presentationDragIndicator(.hidden)
            .presentationCompactAdaptation(.none)
            .presentationBackground(AnchorIOSStyle.surface)
            .presentationCornerRadius(32)
    }
}
#endif
