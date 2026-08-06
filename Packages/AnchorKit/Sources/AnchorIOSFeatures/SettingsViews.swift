#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ConnectionSettingsView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?
    @State private var pairingCode = ""
    @State private var displayedCode: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section(L10n.connections) {
                LabeledContent(L10n.macConnection) {
                    Label(connectionLabel, systemImage: connectionSymbol)
                }
                LabeledContent(L10n.bluetoothProximity) {
                    Label(proximityLabel, systemImage: "dot.radiowaves.left.and.right")
                }
            }
            if let controller {
                Section(L10n.pairDevice) {
                    if let displayedCode {
                        LabeledContent(L10n.pairingCode) {
                            Text(displayedCode)
                                .font(.title2.bold().monospacedDigit())
                                .textSelection(.enabled)
                        }
                    } else {
                        TextField(L10n.pairingCode, text: $pairingCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        Button(L10n.pairDevice) {
                            Task {
                                do {
                                    try await controller.pair(using: pairingCode)
                                    errorMessage = nil
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                        .disabled(pairingCode.count != 6)
                    }
                    Button(L10n.retry) {
                        Task { await controller.retryConnection() }
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            Section {
                Text(L10n.connectionUnknownDetail)
            }
        }
        .navigationTitle(L10n.connections)
        .task { displayedCode = await controller?.currentPairingCode() }
    }

    private var connectionLabel: String {
        switch projection.connection {
        case .connected: L10n.connected
        case .permissionDenied: L10n.permissionDenied
        case .disconnected: L10n.disconnected
        case .pairing: L10n.continueAction
        case .unavailable, .failed: L10n.unknown
        }
    }
    private var connectionSymbol: String {
        projection.connection == .connected ? "checkmark.circle.fill" : "wifi.exclamationmark"
    }
    private var proximityLabel: String {
        switch projection.proximity {
        case .near: L10n.connected
        case .permissionDenied: L10n.permissionDenied
        case .far: L10n.away
        case .unknown, .unavailable: L10n.unknown
        }
    }
}

struct SourceSettingsView: View {
    let projection: SessionProjection

    var body: some View {
        List {
            Section(L10n.sourceHealth) {
                ForEach(projection.session?.processes ?? []) { process in
                    HStack {
                        Text(process.sourceSymbol)
                            .font(.headline.bold())
                            .frame(width: 38, height: 38)
                            .background(
                                AnchorPalette.source(process.sourceTone).opacity(0.55),
                                in: .rect(cornerRadius: 11)
                            )
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(process.sourceName).font(.headline)
                            Text(process.updatedAt, style: .relative).font(.caption)
                        }
                        Spacer()
                        Label(L10n.status(process.status), systemImage: process.status == .disconnected ? "wifi.slash" : "checkmark.circle")
                            .labelStyle(.iconOnly)
                            .accessibilityLabel(L10n.status(process.status))
                    }
                    .frame(minHeight: 52)
                }
            }
        }
        .navigationTitle(L10n.sources)
    }
}

struct NotificationSettingsView: View {
    @State private var meaningfulChanges = true
    @State private var decisions = true

    var body: some View {
        Form {
            Section(L10n.notificationsSettings) {
                Toggle(L10n.notificationDecisions, isOn: $decisions)
                Toggle(L10n.notificationMeaningful, isOn: $meaningfulChanges)
            }
        }
        .navigationTitle(L10n.notificationsSettings)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                Label(L10n.localOnly, systemImage: "lock.shield.fill")
                    .font(.headline)
                Text(L10n.localOnlyDetail)
            }
            Section(L10n.sources) {
                Label(L10n.connections, systemImage: "network")
                Label(L10n.bluetoothProximity, systemImage: "dot.radiowaves.left.and.right")
            }
        }
        .navigationTitle(L10n.privacy)
    }
}

struct AccessibilitySettingsView: View {
    var body: some View {
        Form {
            Section {
                Label(L10n.displaySupport, systemImage: "accessibility")
                    .font(.headline)
                Text(L10n.displaySupportDetail)
            }
            Section {
                Label(L10n.voiceOver, systemImage: "speaker.wave.3")
                Label(L10n.dynamicType, systemImage: "textformat.size")
                Label(L10n.reduceMotion, systemImage: "figure.walk.motion")
                Label(L10n.increaseContrast, systemImage: "circle.lefthalf.filled")
                Label(L10n.reduceTransparency, systemImage: "square.on.square")
            }
        }
        .navigationTitle(L10n.accessibility)
    }
}

#endif
