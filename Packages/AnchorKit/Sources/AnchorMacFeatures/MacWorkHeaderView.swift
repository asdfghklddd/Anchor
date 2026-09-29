#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkHeaderView: View {
    let projection: SessionProjection

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AnchorSpacing.large) {
                heading
                Spacer(minLength: AnchorSpacing.large)
                connectionStatus
            }

            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                heading
                connectionStatus
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
            Text(greeting)
                .font(.largeTitle.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
            Text(MacWorkCopy.subtitle)
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
        }
    }

    private var connectionStatus: some View {
        Label(connectionLabel, systemImage: connectionSymbol)
            .font(.callout.bold())
            .foregroundStyle(connectionColor)
            .padding(.horizontal, AnchorSpacing.small)
            .padding(.vertical, AnchorSpacing.xSmall)
            .background(AnchorPalette.fluoriteSurface, in: .capsule)
            .overlay {
                Capsule().stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
            }
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
