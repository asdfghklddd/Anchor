#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacPairingControls: View {
    let controller: (any LocalLinkControlling)?
    @State private var pairingStatus = DevicePairingStatus.automatic
    @State private var pairingCode: String?

    var body: some View {
        Group {
            if controller != nil {
                switch pairingStatus.phase {
                case .automatic:
                    Label(L10n.pairingAutomatically, systemImage: "icloud.and.arrow.down")
                    Text(L10n.pairingAutomaticDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .verificationCodeRequired:
                    if let pairingCode {
                        MacPairingCodeView(pairingCode: pairingCode)
                    } else {
                        Label(L10n.pairingAutomatically, systemImage: "arrow.triangle.2.circlepath")
                    }
                case .connected:
                    Label(connectedLabel, systemImage: "checkmark.shield.fill")
                        .foregroundStyle(AnchorPalette.mintInk)
                }
            } else {
                Text(L10n.pairingUnavailable)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task {
            guard let controller else { return }
            await observe(controller)
        }
    }

    private var connectedLabel: String {
        switch pairingStatus.route {
        case .iCloud: L10n.pairingConnectedICloud
        case .bluetooth: L10n.pairingConnectedBluetooth
        case .verificationCode: L10n.pairingConnectedCode
        case .trustedDevice, nil: L10n.pairingConnectedTrusted
        }
    }

    private func apply(_ status: DevicePairingStatus, controller: any LocalLinkControlling) async {
        guard pairingStatus != status else { return }
        pairingStatus = status
        pairingCode = status.phase == .verificationCodeRequired
            ? await controller.currentPairingCode()
            : nil
        let message = switch status.phase {
        case .automatic: L10n.pairingAutomatically
        case .verificationCodeRequired: L10n.pairingHint
        case .connected: connectedLabel
        }
        if #available(macOS 14, *) {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

private extension MacPairingControls {
    func observe(_ controller: any LocalLinkControlling) async {
        for await status in controller.pairingStatusUpdates() {
            await apply(status, controller: controller)
        }
    }
}
#endif
