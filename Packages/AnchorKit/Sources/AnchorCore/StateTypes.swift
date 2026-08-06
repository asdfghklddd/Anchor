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
