import Foundation

public enum SessionStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case active
    case completed
    case archived
}

public enum ProcessStatus: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case needsDecision
    case blocked
    case completed
    case failed
    case disconnected
}

public enum DecisionStatus: String, Codable, CaseIterable, Sendable {
    case open
    case resolved
    case expired
    case cancelled
}

public enum PresenceStatus: String, Codable, CaseIterable, Sendable {
    case atDesk
    case handingOff
    case away
    case returning
    case unknown
}

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

public enum DevicePairingRoute: String, Codable, CaseIterable, Sendable {
    case trustedDevice
    case iCloud
    case bluetooth
    case verificationCode
}

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
}

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

public enum DurableSyncState: String, Codable, CaseIterable, Sendable {
    case notConfigured
    case idle
    case syncing
    case available
    case offline
    case failed
}

public enum DevicePosture: String, Codable, CaseIterable, Sendable {
    case portrait
    case landscape
    case unknown
}

public enum ProcessTileSize: String, Codable, CaseIterable, Sendable {
    case compact
    case standard
    case wide
    case large
}

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
