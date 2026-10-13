#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkHeaderView: View {
    let projection: SessionProjection
    var onOpenSettings: (() -> Void)?

    @AnchorReducedMotion private var reduceMotion
    @State private var isHoveringConnection = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AnchorSpacing.medium) {
                heading
                Spacer(minLength: AnchorSpacing.medium)
                connectionStatus
            }

            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                heading
                connectionStatus
            }
        }
    }

    private var heading: some View {
        // One compact line: the greeting no longer pushes the work below the fold.
        HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.small) {
            Text(greeting)
                .font(.title.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .accessibilityAddTraits(.isHeader)
            Text(MacWorkCopy.subtitle)
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        if let onOpenSettings {
            // The label looks like a control because it is one: it leads to the repair path.
            Button(action: onOpenSettings) {
                connectionLabelView(showsChevron: true)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : AnchorMotion.micro) {
                    isHoveringConnection = hovering
                }
            }
            .help(MacWorkCopy.connectionHelp)
            .accessibilityHint(MacWorkCopy.connectionHelp)
            .accessibilityIdentifier("mac.header.connection")
        } else {
            connectionLabelView(showsChevron: false)
        }
    }

    private func connectionLabelView(showsChevron: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: connectionSymbol)
                .foregroundStyle(connectionColor)
            Text(connectionLabel)
                .foregroundStyle(AnchorPalette.ink)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .accessibilityHidden(true)
            }
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isHoveringConnection ? AnchorPalette.softBlue.opacity(0.45) : AnchorPalette.fluoriteSurface,
            in: .capsule
        )
        .overlay {
            Capsule().strokeBorder(AnchorPalette.fluoriteBorder, lineWidth: 1)
        }
        .contentShape(.capsule)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<11: L10n.greetingMorning
        case 11..<18: L10n.greetingAfternoon
        default: L10n.greetingEvening
        }
    }

    private var connectionLabel: String {
        switch projection.connection {
        case .connected: L10n.connected
        case .pairing: L10n.pairDevice
        case .disconnected: MacWorkCopy.peerDisconnected
        case .unavailable: L10n.unknown
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        }
    }

    private var connectionSymbol: String {
        switch projection.connection {
        case .connected: "checkmark.circle.fill"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected: "wifi.slash"
        case .unavailable: "questionmark.circle"
        case .permissionDenied: "lock.slash"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionColor: Color {
        switch projection.connection {
        case .connected: AnchorPalette.mintInk
        case .pairing: AnchorPalette.sourceInk("sand")
        case .permissionDenied, .failed: AnchorPalette.sourceInk("coral")
        case .disconnected, .unavailable: AnchorPalette.secondaryInk
        }
    }
}
#endif
