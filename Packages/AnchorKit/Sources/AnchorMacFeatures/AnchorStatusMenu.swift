#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation
import Observation

/// How Anchor shows itself on the Mac: a menu bar icon by default, or the
/// floating boat at the screen edge. Chosen in Settings.
public enum MacInterfaceStyle: String, CaseIterable, Sendable {
    case menuBar
    case boat

    public static let defaultsKey = "anchor.mac.interface-style"

    public static func current(in defaults: UserDefaults) -> MacInterfaceStyle {
        defaults.string(forKey: defaultsKey).flatMap(Self.init(rawValue:)) ?? .menuBar
    }
}

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

/// What the menu bar item shows, read fresh each time the menu opens: is the
/// phone connected, the one thing that fixes it when not, which agents Anchor
/// can read, and the next step to copy.
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
    }

    public enum Icon: Sendable, Equatable {
        case connected
        case away
        case needsAttention
    }

    public let link: Link
    /// Saved updates waiting for the phone.
    public let unsent: Int
    public let codexReady: Bool
    public let claudeReady: Bool
    /// A detail reported by the authenticated phone, when the peer supports it.
    public let peerDeviceSummary: String?
    /// The next step as a ready-to-paste request, when the task you're on has one.
    public let prompt: String?
    /// "Step 2 of 5 · …", shown under the copy item.
    public let nextStepLine: String?

    public init(
        projection: SessionProjection,
        radio: MacBluetoothRadio,
        pairing: DevicePairingStatus,
        codexReady: Bool,
        claudeReady: Bool
    ) {
        link = Self.link(connection: projection.connection, radio: radio, pairing: pairing)
        unsent = projection.unsentChanges
        self.codexReady = codexReady
        self.claudeReady = claudeReady
        if case .connected = link {
            peerDeviceSummary = pairing.peerDeviceInfo?.shortDescription
        } else {
            peerDeviceSummary = nil
        }
        let edgeMenu = AnchorEdgeMenu(projection: projection)
        prompt = edgeMenu.prompt
        nextStepLine = edgeMenu.nextStep.map(EdgeMenuCopy.step)
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

    public var icon: Icon {
        switch link {
        case .bluetoothOff, .bluetoothNotAllowed, .failed: return .needsAttention
        case .connected, .searching, .notPaired: break
        }
        // With no agent folder, nothing reaches the phone.
        if !codexReady && !claudeReady { return .needsAttention }
        if case .connected = link { return .connected }
        return .away
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

    public static let reconnectHint = AnchorStrings.value(
        "mac.status.fix.reconnect.hint", default: "Open Anchor on your iPhone nearby")

    public static func unsent(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.status.unsent", default: "Not sent yet: %lld · syncs when connected"),
            count)
    }

    public static func pairingCode(_ code: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.status.pairing-code", default: "Pairing code: %@"), code)
    }

    public static let pairingCodeHint = AnchorStrings.value(
        "mac.status.pairing-code.hint", default: "Enter it in Anchor on your iPhone")

    public static let agentSourcesReady = AnchorStrings.value(
        "mac.status.agent.sources.ready", default: "Codex and Claude Code connected ✓")
    public static let agentSourcesConnect = AnchorStrings.value(
        "mac.status.agent.sources.connect", default: "Connect Codex and Claude Code once…")
    public static let agentSourcesConnectHint = AnchorStrings.value(
        "mac.status.agent.sources.connect.hint",
        default: "Choose both conversation folders in one step")

    public static let copyNextStep = EdgeMenuCopy.copyNextStep
    public static let copyUnavailable = EdgeMenuCopy.copyUnavailable
    public static let nextStepCopied = AnchorStrings.value("mac.edge.copied", default: "Copied")
    public static let copyFailed = AnchorStrings.value(
        "mac.status.copy.failed", default: "Couldn't copy the next step")
    public static let loginEnabled = AnchorStrings.value(
        "mac.status.login.enabled", default: "Anchor will open at login")
    public static let loginDisabled = AnchorStrings.value(
        "mac.status.login.disabled", default: "Anchor won't open at login")
    public static let openConnectionSettings = AnchorStrings.value(
        "mac.status.open.connection", default: "Click to view connection settings")
    public static let openSourcesSettings = AnchorStrings.value(
        "mac.status.open.sources", default: "Click to manage connected folders")
    public static func loginFailed(_ reason: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.status.login.failed", default: "Couldn't change login setting: %@"),
            reason)
    }
    public static let openAtLogin = L10n.startAtLogin
    public static let settings = EdgeMenuCopy.settings
    public static let quit = EdgeMenuCopy.quit

    public static let styleTitle = AnchorStrings.value("mac.style.title", default: "Show Anchor as")
    public static let styleMenuBar = AnchorStrings.value("mac.style.menu-bar", default: "Menu bar icon")
    public static let styleBoat = AnchorStrings.value("mac.style.boat", default: "Floating boat")
    public static let styleDetail = AnchorStrings.value(
        "mac.style.detail",
        default: "The menu bar icon shows the connection and little else. The boat floats at the screen edge with quick actions.")
}
#endif
