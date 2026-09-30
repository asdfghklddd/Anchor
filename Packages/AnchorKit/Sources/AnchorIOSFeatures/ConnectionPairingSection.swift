#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

struct ConnectionPairingSection: View {
    let controller: any LocalLinkControlling
    let connection: ConnectionState
    let proximity: ProximityState
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var pairingCode = ""
    @State private var pairingStatus = DevicePairingStatus.automatic
    @State private var isShowingManualCode = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            if connection == .connected {
                Label(connectedLabel, systemImage: "checkmark.circle.fill")
                    .accessibilityIdentifier("connections.pairing.connected")
            } else if connection == .permissionDenied || proximity == .permissionDenied {
                Label(L10n.permissionDenied, systemImage: "hand.raised.fill")
                Text(L10n.permissionDeniedDetail).font(.caption)
            } else if pairingStatus.phase == .verificationCodeRequired || isShowingManualCode {
                Text(L10n.pairingFallbackDetail).font(.caption)
                TextField(L10n.pairingCode, text: $pairingCode)
                    .keyboardType(.numberPad).textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("connections.pairing.code")
                    .onChange(of: pairingCode) { _, value in
                        pairingCode = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                    }
            } else {
                Label(connection == .failed ? L10n.actionFailed : L10n.pairingAutomatically,
                      systemImage: connection == .failed ? "exclamationmark.triangle" : "macbook.and.iphone")
                    .accessibilityIdentifier("connections.pairing.automatic")
                Text(L10n.pairingAutomaticDetail).font(.caption)
                Button(L10n.pairingCode, systemImage: "number") {
                    isShowingManualCode = true
                }
                .accessibilityIdentifier("connections.pairing.show.code")
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("connections.pairing.error")
            }
            // Keep diagnostics available without a separate settings page.
            Text(L10n.bluetoothProximity + " · " + proximityLabel)
                .font(.caption2).foregroundStyle(AnchorIOSStyle.secondaryText)
            HStack(spacing: 10) {
                if connection != .connected,
                   pairingStatus.phase == .verificationCodeRequired || isShowingManualCode {
                    Button(action: submitPairingCode) {
                        Text(L10n.pairDevice).frame(maxWidth: .infinity)
                            .foregroundStyle(AnchorIOSStyle.onAction)
                    }
                        .disabled(pairingCode.count != 6 || isSubmitting)
                        .accessibilityIdentifier("connections.pairing.submit")
                        .buttonStyle(.borderedProminent)
                }
                if connection == .connected {
                    Button(action: retryConnection) {
                        Text(L10n.retry).frame(maxWidth: .infinity)
                            .foregroundStyle(AnchorIOSStyle.action)
                    }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("connections.retry")
                }
                Button {
                    if connection == .connected { dismiss() } else { retryConnection() }
                } label: {
                    Text(connection == .connected ? L10n.done : L10n.retry)
                        .frame(maxWidth: .infinity).foregroundStyle(AnchorIOSStyle.action)
                }
                .accessibilityIdentifier("connections.primary")
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
            }
            .controlSize(.large).buttonBorderShape(.capsule)
            .frame(maxWidth: .infinity)
        }
        .font(.subheadline).multilineTextAlignment(.center)
        .foregroundStyle(AnchorIOSStyle.secondaryText)
        .tint(AnchorIOSStyle.action)
        // Animate only discrete status changes, never text entry or repeated discovery updates.
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: connection)
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: pairingStatus.phase)
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: errorMessage)
        .task {
            for await status in controller.pairingStatusUpdates() {
                apply(status)
            }
        }
    }

    private var proximityLabel: String {
        switch proximity {
        case .near: L10n.nearby
        case .far: L10n.away
        case .permissionDenied: L10n.permissionDenied
        case .unknown, .unavailable: L10n.unknown
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
        let code = pairingCode
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await controller.pair(using: code)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func retryConnection() {
        errorMessage = nil
        pairingCode = ""
        isShowingManualCode = false
        Task { await controller.retryConnection() }
    }

    private func apply(_ status: DevicePairingStatus) {
        guard pairingStatus != status else { return }
        pairingStatus = status
        if status.phase == .connected {
            errorMessage = nil
            pairingCode = ""
            isShowingManualCode = false
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
