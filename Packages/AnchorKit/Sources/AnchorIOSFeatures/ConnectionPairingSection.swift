#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

/// The card's lower half: which Mac, and what the person can do about it.
struct ConnectionPairingSection: View {
    let controller: any LocalLinkControlling
    let connection: ConnectionState
    /// Whether the card shows the link as up, which follows the hero's check.
    let isConnected: Bool
    let isDenied: Bool
    let entersCode: Bool
    @Binding var pairingStatus: DevicePairingStatus
    @Binding var showsManualCode: Bool

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var pairingCode = ""
    @State private var errorMessage: String?
    /// The Mac last seen, so a dropped link still names which one it means.
    @State private var lastDevice = PeerDeviceMemory.last()

    var body: some View {
        VStack(spacing: 12) {
            if let device = pairingStatus.peerDeviceInfo ?? lastDevice, !entersCode {
                deviceLine(device)
            }
            if isDenied, !isConnected {
                Text(L10n.permissionDeniedDetail).font(.caption)
            }
            if entersCode {
                Text(L10n.pairingFallbackDetail).font(.caption)
                codeField
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
                    .accessibilityIdentifier("connections.pairing.error")
            }
            buttons
        }
        .font(.subheadline).multilineTextAlignment(.center)
        .foregroundStyle(AnchorIOSStyle.secondaryText)
        .tint(AnchorIOSStyle.action)
        // Animate only discrete status changes, never text entry or repeated discovery updates.
        .animation(reduceMotion ? nil : AnchorMotion.panel, value: isConnected)
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: entersCode)
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: errorMessage)
        .task {
            for await status in controller.pairingStatusUpdates() {
                apply(status)
            }
        }
    }

    private func deviceLine(_ device: PeerDeviceInfo) -> some View {
        let route = isConnected ? pairingStatus.route.map(PeerDeviceCopy.route) : nil
        return HStack(spacing: 8) {
            Image(systemName: device.symbolName)
                .foregroundStyle(isConnected ? AnchorPalette.mintInk : AnchorIOSStyle.secondaryText)
                .accessibilityHidden(true)
            Text([device.displayName, route].compactMap { $0 }.joined(separator: " · "))
                .lineLimit(1)
                .foregroundStyle(isConnected ? AnchorPalette.ink : AnchorIOSStyle.secondaryText)
                .contentTransition(.opacity)
        }
        .font(.subheadline.weight(.medium))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pairing.peer-device")
    }

    private var codeField: some View {
        TextField(L10n.pairingCode, text: $pairingCode, prompt: Text(verbatim: "000000"))
            .keyboardType(.numberPad).textContentType(.oneTimeCode)
            .font(.title3.weight(.semibold).monospacedDigit())
            .kerning(6)
            .multilineTextAlignment(.center)
            .foregroundStyle(AnchorPalette.ink)
            .padding(.vertical, 11)
            .background(AnchorIOSStyle.border.opacity(0.32), in: .capsule)
            .accessibilityIdentifier("connections.pairing.code")
            .onChange(of: pairingCode) { _, value in
                pairingCode = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
            }
    }

    @ViewBuilder private var buttons: some View {
        HStack(spacing: 10) {
            if isConnected {
                Button(action: dismiss.callAsFunction) {
                    Text(L10n.done).frame(maxWidth: .infinity)
                        .foregroundStyle(AnchorIOSStyle.onAction)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("connections.primary")
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            } else {
                if !entersCode, !isDenied {
                    Button(L10n.pairingCode, systemImage: "number") {
                        showsManualCode = true
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("connections.pairing.show.code")
                }
                Button(action: retryConnection) {
                    Text(L10n.retry).frame(maxWidth: .infinity)
                        .foregroundStyle(AnchorIOSStyle.action)
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
                .accessibilityIdentifier("connections.primary")
                if entersCode {
                    Button(action: submitPairingCode) {
                        Text(L10n.pairDevice).frame(maxWidth: .infinity)
                            .foregroundStyle(pairingCode.count == 6 ? AnchorIOSStyle.onAction : AnchorIOSStyle.secondaryText)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pairingCode.count != 6 || isSubmitting)
                    .accessibilityIdentifier("connections.pairing.submit")
                }
            }
        }
        .controlSize(.large).buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity)
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
        showsManualCode = false
        Task { await controller.retryConnection() }
    }

    private func apply(_ status: DevicePairingStatus) {
        guard pairingStatus != status else { return }
        pairingStatus = status
        if let device = status.peerDeviceInfo { lastDevice = device }
        if status.phase == .connected {
            errorMessage = nil
            pairingCode = ""
            showsManualCode = false
        }
        announce(status)
    }

    private func announce(_ status: DevicePairingStatus) {
        let message = switch status.phase {
        case .automatic: L10n.pairingAutomatically
        case .verificationCodeRequired: L10n.pairingFallbackDetail
        case .connected: status.peerDeviceInfo.map { "\(PeerDeviceCopy.connected), \($0.displayName)" } ?? connectedLabel
        }
        if #available(iOS 17, *) {
            AccessibilityNotification.Announcement(message).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
#endif
