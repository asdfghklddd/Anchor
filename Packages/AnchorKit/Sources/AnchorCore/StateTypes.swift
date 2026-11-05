// Role: small status enums shared across the app, and the peer device info used on connection screens.
// Compatibility: raw values are stored and sent; do not rename them.

import Foundation

/// Lifecycle of a task.
public enum SessionStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case active
    case completed
    case archived
}

/// State of one conversation or command, as reported by its source.
public enum ProcessStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case needsDecision
    case blocked
    case completed
    case failed
    case disconnected
}

/// Retired with `Decision`; kept for decoding.
public enum DecisionStatus: String, Codable, CaseIterable, Sendable {
    case open
    case resolved
    case expired
    case cancelled
}

/// Where the person is, as `PresenceReducer` decided.
public enum PresenceStatus: String, Codable, CaseIterable, Sendable {
    case atDesk
    case handingOff
    case away
    case returning
    case unknown
}

/// State of the link to the other device.
public enum ConnectionState: String, Codable, CaseIterable, Sendable {
    case connected
    case pairing
    case disconnected
    case unavailable
    case permissionDenied
    case failed

    public var isAuthenticatedAndHealthy: Bool { self == .connected }
    public var isAmbiguous: Bool {
        switch self {
        case .unavailable, .permissionDenied, .failed, .pairing:
            true
        case .connected, .disconnected:
            false
        }
    }
}

/// Which path pairing or the link uses.
public enum DevicePairingRoute: String, Codable, CaseIterable, Sendable {
    case trustedDevice
    case iCloud
    case bluetooth
    case verificationCode
}

/// Where pairing currently stands.
public enum DevicePairingPhase: String, Codable, CaseIterable, Sendable {
    case automatic
    case verificationCodeRequired
    case connected
}

/// Brief information the authenticated peer chooses to share for the connection UI.
public struct PeerDeviceInfo: Codable, Hashable, Sendable {
    public let name: String
    public let model: String
    public let systemName: String
    public let systemVersion: String

    public init(name: String, model: String, systemName: String, systemVersion: String) {
        self.name = name
        self.model = model
        self.systemName = systemName
        self.systemVersion = systemVersion
    }

    public var shortDescription: String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSystem = systemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVersion = systemVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameIncludesModel = !cleanModel.isEmpty
            && cleanName.range(of: cleanModel, options: .caseInsensitive) != nil
        let device: String
        if cleanName.isEmpty {
            device = String(cleanModel.prefix(32))
        } else if cleanModel.isEmpty || nameIncludesModel {
            device = String(cleanName.prefix(48))
        } else {
            device = "\(cleanName.prefix(32)) · \(cleanModel.prefix(24))"
        }
        let software = [cleanSystem, cleanVersion].filter { !$0.isEmpty }.joined(separator: " ")
        return [device, software].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// The name the person gave the device, or its kind when it has none.
    public var displayName: String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((cleanName.isEmpty ? cleanModel : cleanName).prefix(48))
    }

    /// "iPhone · iOS 26.1", leaving out the kind when the name already says it.
    public var detail: String {
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let showsModel = !cleanModel.isEmpty
            && displayName.range(of: cleanModel, options: .caseInsensitive) == nil
        let software = [systemName, systemVersion]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }.joined(separator: " ")
        return [showsModel ? String(cleanModel.prefix(24)) : "", software]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// An SF Symbol for the kind of device.
    public var symbolName: String {
        let kind = (systemName + " " + model).lowercased()
        if kind.contains("mac") { return "laptopcomputer" }
        if kind.contains("ipad") { return "ipad" }
        return "iphone"
    }
}

/// The last paired device that introduced itself, kept so a disconnected
/// screen can still say which device it means.
public enum PeerDeviceMemory {
    static let key = "anchor.link.last-peer-device"

    public static func remember(_ info: PeerDeviceInfo, in defaults: UserDefaults = .standard) {
        guard last(in: defaults) != info, let data = try? JSONEncoder().encode(info) else { return }
        defaults.set(data, forKey: key)
    }

    public static func last(in defaults: UserDefaults = .standard) -> PeerDeviceInfo? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(PeerDeviceInfo.self, from: $0) }
    }
}

/// Pairing state for the UI.
public struct DevicePairingStatus: Codable, Hashable, Sendable {
    public let phase: DevicePairingPhase
    public let route: DevicePairingRoute?
    public let peerDeviceInfo: PeerDeviceInfo?

    public init(
        phase: DevicePairingPhase,
        route: DevicePairingRoute? = nil,
        peerDeviceInfo: PeerDeviceInfo? = nil
    ) {
        self.phase = phase
        self.route = route
        self.peerDeviceInfo = peerDeviceInfo
    }

    public static let automatic = DevicePairingStatus(phase: .automatic)
    public static let verificationCodeRequired = DevicePairingStatus(
        phase: .verificationCodeRequired,
        route: .verificationCode
    )
}

/// How near the other device is, from Bluetooth RSSI.
public enum ProximityState: String, Codable, CaseIterable, Sendable {
    case near
    case far
    case unknown
    case unavailable
    case permissionDenied

    public var isAmbiguous: Bool {
        switch self {
        case .unknown, .unavailable, .permissionDenied:
            true
        case .near, .far:
            false
        }
    }
}

/// State of the optional cloud path.
public enum DurableSyncState: String, Codable, CaseIterable, Sendable {
    case notConfigured
    case idle
    case syncing
    case available
    case offline
    case failed
}

/// How the phone is being held.
public enum DevicePosture: String, Codable, CaseIterable, Sendable {
    case portrait
    case landscape
    case unknown
}

/// Stored display size of a process tile; part of older stored data.
public enum ProcessTileSize: String, Codable, CaseIterable, Sendable {
    case compact
    case standard
    case wide
    case large
}

/// What sort of thing a `ProcessEvent` records.
public enum ProcessEventKind: String, Codable, CaseIterable, Sendable {
    case created
    case progress
    case outputReady
    case decisionRequired
    case decisionResolved
    case completed
    case failed
    case note
    case presence
    case connection
}
