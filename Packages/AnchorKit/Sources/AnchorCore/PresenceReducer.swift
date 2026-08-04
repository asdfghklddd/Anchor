import Foundation

public struct PresenceSignals: Codable, Hashable, Sendable {
    public var posture: DevicePosture
    public var connection: ConnectionState
    public var proximity: ProximityState
    public var observedAt: Date

    public init(
        posture: DevicePosture,
        connection: ConnectionState,
        proximity: ProximityState,
        observedAt: Date = .now
    ) {
        self.posture = posture
        self.connection = connection
        self.proximity = proximity
        self.observedAt = observedAt
    }
}

public struct PresencePolicy: Codable, Hashable, Sendable {
    public var absenceConfirmation: TimeInterval
    public var handoffDuration: TimeInterval

    public init(absenceConfirmation: TimeInterval = 60, handoffDuration: TimeInterval = 3) {
        self.absenceConfirmation = absenceConfirmation
        self.handoffDuration = handoffDuration
    }
}

public struct PresenceReducer: Codable, Hashable, Sendable {
    public private(set) var status: PresenceStatus
    public private(set) var absenceBeganAt: Date?
    public private(set) var handoffBeganAt: Date?
    public var policy: PresencePolicy

    public init(status: PresenceStatus = .unknown, policy: PresencePolicy = PresencePolicy()) {
        self.status = status
        self.policy = policy
    }

    @discardableResult
    public mutating func reduce(_ signals: PresenceSignals) -> PresenceStatus {
        if status == .returning {
            return status
        }

        if signals.posture == .landscape || signals.connection.isAuthenticatedAndHealthy {
            absenceBeganAt = nil
            handoffBeganAt = nil
            if status == .away || status == .handingOff {
                status = .returning
            } else {
                status = .atDesk
            }
            return status
        }

        if signals.connection.isAmbiguous || signals.proximity.isAmbiguous || signals.posture == .unknown {
            absenceBeganAt = nil
            handoffBeganAt = nil
            status = .unknown
            return status
        }

        if signals.proximity == .near {
            absenceBeganAt = nil
            handoffBeganAt = nil
            if status == .away || status == .handingOff {
                status = .returning
            } else {
                status = .atDesk
            }
            return status
        }

        guard signals.connection == .disconnected, signals.proximity == .far else {
            absenceBeganAt = nil
            handoffBeganAt = nil
            status = .unknown
            return status
        }

        if status == .away {
            return status
        }

        if status == .handingOff, handoffBeganAt == nil {
            handoffBeganAt = signals.observedAt
            return status
        }

        if absenceBeganAt == nil {
            absenceBeganAt = signals.observedAt
            status = .atDesk
            return status
        }

        let absentFor = signals.observedAt.timeIntervalSince(absenceBeganAt ?? signals.observedAt)
        guard absentFor >= policy.absenceConfirmation else {
            status = .atDesk
            return status
        }

        if handoffBeganAt == nil {
            handoffBeganAt = signals.observedAt
            status = .handingOff
            return status
        }

        let handingOffFor = signals.observedAt.timeIntervalSince(handoffBeganAt ?? signals.observedAt)
        status = handingOffFor >= policy.handoffDuration ? .away : .handingOff
        return status
    }

    public mutating func acknowledgeReturn() {
        status = .atDesk
        absenceBeganAt = nil
        handoffBeganAt = nil
    }

    public mutating func correct(to status: PresenceStatus) {
        self.status = status
        absenceBeganAt = nil
        handoffBeganAt = nil
    }
}
