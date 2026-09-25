#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

struct ConnectionPairingSection: View {
    let controller: any LocalLinkControlling
    @State private var pairingCode = ""
    @State private var pairingStatus = DevicePairingStatus.automatic
    @State private var errorMessage: String?

    var body: some View {
        Section(L10n.pairDevice) {
            switch pairingStatus.phase {
            case .automatic:
                Label(L10n.pairingAutomatically, systemImage: "icloud.and.arrow.down")
                    .accessibilityIdentifier("connections.pairing.automatic")
                Text(L10n.pairingAutomaticDetail)
                    .foregroundStyle(.secondary)
            case .verificationCodeRequired:
                Text(L10n.pairingFallbackDetail)
                    .foregroundStyle(.secondary)
                TextField(L10n.pairingCode, text: $pairingCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .accessibilityIdentifier("connections.pairing.code")
                Button(L10n.pairDevice, action: submitPairingCode)
                    .disabled(pairingCode.count != 6)
            case .connected:
                Label(connectedLabel, systemImage: "checkmark.shield.fill")
                    .foregroundStyle(AnchorPalette.mintInk)
                    .accessibilityIdentifier("connections.pairing.connected")
            }

            Button(L10n.retry, action: retryConnection)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
        .task {
            for await status in controller.pairingStatusUpdates() {
                apply(status)
            }
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

    private func submitPairingCode() {
        Task {
            do {
                try await controller.pair(using: pairingCode)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func retryConnection() {
        errorMessage = nil
        pairingCode = ""
        Task { await controller.retryConnection() }
    }

    private func apply(_ status: DevicePairingStatus) {
        guard pairingStatus != status else { return }
        pairingStatus = status
        if status.phase == .connected {
            errorMessage = nil
            pairingCode = ""
        }
        announce(status)
    }

    private func announce(_ status: DevicePairingStatus) {
        let message = switch status.phase {
        case .automatic: L10n.pairingAutomatically
        case .verificationCodeRequired: L10n.pairingFallbackDetail
        case .connected: connectedLabel
        }
        if #available(iOS 17, *) {
            AccessibilityNotification.Announcement(message).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
#endif
