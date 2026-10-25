#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Settings › Connections: which Mac, how close it is, how to reach it again,
/// and when the link came and went.
struct ConnectionDetailView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?

    @State private var pairingStatus = DevicePairingStatus.automatic
    @State private var lastDevice = PeerDeviceMemory.last()
    @State private var history = ConnectionHistory.entries()
    @State private var pairingCode = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isConnected: Bool { projection.connection == .connected }
    private var isDenied: Bool { projection.connection == .permissionDenied || projection.proximity == .permissionDenied }

    var body: some View {
        List {
            Section {
                if let device = pairingStatus.peerDeviceInfo ?? lastDevice {
                    PeerDeviceRow(info: device, route: isConnected ? pairingStatus.route : nil, isConnected: isConnected)
                } else {
                    Label(L10n.disconnected, systemImage: "wifi.slash")
                }
                if isDenied {
                    Label(L10n.permissionDenied, systemImage: "hand.raised.fill")
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                }
                LabeledContent(L10n.bluetoothProximity, value: proximityLabel)
            }
            .listRowBackground(AnchorIOSStyle.surface)

            if !isConnected, controller != nil {
                pairingSection
            }

            if !history.isEmpty {
                Section(ConnectionCopy.history) {
                    ForEach(history) { ConnectionHistoryRow(entry: $0) }
                }
                .listRowBackground(AnchorIOSStyle.surface)
            }
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.connections)
        .accessibilityIdentifier("connections.detail")
        .onChange(of: projection.connection) { _, _ in history = ConnectionHistory.entries() }
        .task {
            guard let controller else { return }
            for await status in controller.pairingStatusUpdates() {
                pairingStatus = status
                if let device = status.peerDeviceInfo { lastDevice = device }
                history = ConnectionHistory.entries()
            }
        }
    }

    private var pairingSection: some View {
        Section {
            HStack {
                TextField(L10n.pairingCode, text: $pairingCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .accessibilityIdentifier("connections.pairing.code")
                    .onChange(of: pairingCode) { _, value in
                        pairingCode = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                    }
                if pairingCode.count == 6 {
                    Button(L10n.pairDevice, action: submitPairingCode)
                        .buttonStyle(.borderless)
                        .disabled(isSubmitting)
                        .accessibilityIdentifier("connections.pairing.submit")
                }
            }
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            Button(ConnectionCopy.reconnect, systemImage: "arrow.clockwise", action: reconnect)
                .disabled(isSubmitting)
                .accessibilityIdentifier("connections.retry")
        } footer: {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
                    .accessibilityIdentifier("connections.pairing.error")
            }
        }
        .listRowBackground(AnchorIOSStyle.surface)
        .tint(AnchorIOSStyle.action)
    }

    private var proximityLabel: String {
        switch projection.proximity {
        case .near: L10n.nearby
        case .far: ConnectionCopy.far
        case .permissionDenied: L10n.permissionDenied
        case .unknown, .unavailable: L10n.unknown
        }
    }

    private func submitPairingCode() {
        guard let controller else { return }
        let code = pairingCode
        isSubmitting = true
        Task {
            defer { isSubmitting = false }
            do {
                try await controller.pair(using: code)
                errorMessage = nil
                pairingCode = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func reconnect() {
        errorMessage = nil
        Task { await controller?.retryConnection() }
    }
}

/// One line of the log: what happened, with which Mac over which route, and when.
private struct ConnectionHistoryRow: View {
    let entry: ConnectionHistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.kind == .connected ? AnchorPalette.mintInk : AnchorIOSStyle.secondaryText.opacity(0.4))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind == .connected ? PeerDeviceCopy.connected : ConnectionCopy.disconnected)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AnchorPalette.ink)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(AnchorIOSStyle.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        [entry.device?.displayName, entry.route.map(PeerDeviceCopy.route)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var time: String {
        Calendar.current.isDateInToday(entry.date)
            ? entry.date.formatted(date: .omitted, time: .shortened)
            : entry.date.formatted(.dateTime.month().day().hour().minute())
    }
}

enum ConnectionCopy {
    static let history = AnchorStrings.value("connection.history", default: "History")
    static let disconnected = AnchorStrings.value("connection.history.disconnected", default: "Disconnected")
    static let reconnect = AnchorStrings.value("connection.reconnect", default: "Reconnect")
    static let far = AnchorStrings.value("connection.far", default: "Far")
}
#endif
