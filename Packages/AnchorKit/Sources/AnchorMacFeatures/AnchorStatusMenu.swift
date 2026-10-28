#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation
import Observation

/// The Mac's own Bluetooth, which the link's connection state folds into
/// "unavailable".
public enum MacBluetoothRadio: Sendable, Equatable {
    case unknown
    case on
    case off
    case notAllowed
}

@MainActor
@Observable
public final class MacBluetoothRadioState {
    public var radio = MacBluetoothRadio.unknown

    public init() {}
}

/// Where the phone link stands, the one thing that moves it forward when
/// it is down, and whether Anchor can read the agents' folders.
public struct AnchorStatusMenu: Sendable, Equatable {
    public enum Link: Sendable, Equatable {
        case connected(viaBluetooth: Bool)
        case searching
        case notPaired
        case bluetoothOff
        case bluetoothNotAllowed
        case failed
    }

    public enum Fix: Sendable, Equatable {
        case reconnect
        case openBluetoothSettings
        case openBluetoothPrivacy

        /// The System Settings pane that fixes it; reconnecting needs none.
        public var settingsURL: URL? {
            switch self {
            case .reconnect: nil
            case .openBluetoothSettings: URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")
            case .openBluetoothPrivacy:
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
            }
        }
    }

    public let link: Link
    public let codexReady: Bool
    public let claudeReady: Bool
    /// A detail reported by the authenticated phone, when the peer supports it.
    public let peerDeviceSummary: String?

    public init(
        projection: SessionProjection,
        radio: MacBluetoothRadio,
        pairing: DevicePairingStatus,
        codexReady: Bool,
        claudeReady: Bool
    ) {
        link = Self.link(connection: projection.connection, radio: radio, pairing: pairing)
        self.codexReady = codexReady
        self.claudeReady = claudeReady
        if case .connected = link {
            peerDeviceSummary = pairing.peerDeviceInfo?.shortDescription
        } else {
            peerDeviceSummary = nil
        }
    }

    static func link(connection: ConnectionState, radio: MacBluetoothRadio,
                     pairing: DevicePairingStatus) -> Link {
        // The local network can carry the link while Bluetooth is off.
        if connection == .connected { return .connected(viaBluetooth: pairing.route == .bluetooth) }
        if radio == .notAllowed || connection == .permissionDenied { return .bluetoothNotAllowed }
        if radio == .off { return .bluetoothOff }
        if pairing.phase == .verificationCodeRequired { return .notPaired }
        if connection == .failed { return .failed }
        return .searching
    }

    public var isConnected: Bool {
        if case .connected = link { true } else { false }
    }

    /// The one action that moves the link forward; pairing shows its code instead.
    public var fix: Fix? {
        switch link {
        case .connected, .notPaired: nil
        case .searching, .failed: .reconnect
        case .bluetoothOff: .openBluetoothSettings
        case .bluetoothNotAllowed: .openBluetoothPrivacy
        }
    }
}

public enum StatusMenuCopy {
    public static func link(_ link: AnchorStatusMenu.Link) -> String {
        switch link {
        case .connected(viaBluetooth: true):
            AnchorStrings.value("mac.status.connected.bluetooth", default: "Connected to iPhone · Bluetooth")
        case .connected(viaBluetooth: false):
            AnchorStrings.value("mac.status.connected.network", default: "Connected to iPhone · Wi-Fi")
        case .searching:
            AnchorStrings.value("mac.status.searching", default: "Looking for iPhone")
        case .notPaired:
            AnchorStrings.value("mac.status.not-paired", default: "Not paired")
        case .bluetoothOff:
            AnchorStrings.value("mac.status.bluetooth-off", default: "Bluetooth is off")
        case .bluetoothNotAllowed:
            AnchorStrings.value("mac.status.bluetooth-denied", default: "Bluetooth isn't allowed for Anchor")
        case .failed:
            AnchorStrings.value("mac.status.failed", default: "Couldn't connect to iPhone")
        }
    }

    public static func fix(_ fix: AnchorStatusMenu.Fix) -> String {
        switch fix {
        case .reconnect:
            AnchorStrings.value("mac.status.fix.reconnect", default: "Reconnect")
        case .openBluetoothSettings:
            AnchorStrings.value("mac.status.fix.bluetooth", default: "Open Bluetooth Settings…")
        case .openBluetoothPrivacy:
            AnchorStrings.value("mac.status.fix.privacy", default: "Allow Bluetooth in Privacy Settings…")
        }
    }

    public static let pairingCodeHint = AnchorStrings.value(
        "mac.status.pairing-code.hint", default: "Enter it in Anchor on your iPhone")
    public static let agentSourcesConnect = AnchorStrings.value(
        "mac.status.agent.sources.connect", default: "Connect Codex and Claude Code once…")
}
#endif
