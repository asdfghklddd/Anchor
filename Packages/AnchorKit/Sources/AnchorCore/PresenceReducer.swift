import Foundation

public struct PresenceSignals: Codable, Hashable, Sendable {
    public var posture: DevicePosture
    public var connection: ConnectionState
    public var proximity: ProximityState
    /// Authenticated BLE channel, separate from the effective Wi-Fi/BLE link.
    public var bluetoothConnection: ConnectionState?
    public var observedAt: Date

    public init(
        posture: DevicePosture,
        connection: ConnectionState,
        proximity: ProximityState,
        observedAt: Date = .now,
        bluetoothConnection: ConnectionState? = nil
    ) {
        self.posture = posture
        self.connection = connection
        self.proximity = proximity
        self.observedAt = observedAt
        self.bluetoothConnection = bluetoothConnection
    }
}

public struct PresencePolicy: Codable, Hashable, Sendable {
    public var absenceConfirmation: TimeInterval
    public var handoffDuration: TimeInterval

    public init(absenceConfirmation: TimeInterval = 300, handoffDuration: TimeInterval = 3) {
        self.absenceConfirmation = absenceConfirmation
        self.handoffDuration = handoffDuration
    }
}

public struct PresenceReducer: Codable, Hashable, Sendable {
    public private(set) var status: PresenceStatus
    public private(set) var absenceBeganAt: Date?
    public private(set) var handoffBeganAt: Date?
    private var lastConnectedAt: Date?
    private var previousConnection: ConnectionState?
    private var previousBluetoothConnection: ConnectionState?
    public var policy: PresencePolicy

    public init(status: PresenceStatus = .unknown, policy: PresencePolicy = PresencePolicy()) {
        self.status = status
        self.policy = policy
    }

    @discardableResult
    public mutating func reduce(_ signals: PresenceSignals) -> PresenceStatus {
        let reconnected = Self.isReconnect(from: previousConnection, to: signals.connection)
            || Self.isReconnect(from: previousBluetoothConnection, to: signals.bluetoothConnection)
        let longInterruption = absenceBeganAt.map {
            signals.observedAt.timeIntervalSince($0) >= policy.absenceConfirmation
        } ?? false
        defer {
            previousConnection = signals.connection
            previousBluetoothConnection = signals.bluetoothConnection
            if signals.connection == .connected { lastConnectedAt = signals.observedAt }
        }
        if status == .returning { return status }

        // Returning needs an authenticated reconnection, never rotation or RSSI
        // alone. Either authenticated transport can keep the workspace connected.
        if signals.connection == .connected {
            if reconnected && (status == .away || status == .handingOff || longInterruption) {
                status = .returning
            } else if status != .away {
                status = .atDesk
            }
            absenceBeganAt = nil
            handoffBeganAt = nil
            return status
        }
        if status == .away { return status }

        guard canConfirmAbsence(signals) else {
            absenceBeganAt = nil
            handoffBeganAt = nil
            status = .unknown
            return status
        }
        if absenceBeganAt == nil {
            absenceBeganAt = signals.observedAt
            status = .atDesk
            return status
        }
        guard longInterruption else {
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

    public func canConfirmAbsence(_ signals: PresenceSignals) -> Bool {
        guard lastConnectedAt != nil else { return false }
        switch signals.connection {
        case .disconnected, .failed: return true
        case .pairing: return absenceBeganAt != nil
        case .connected, .unavailable, .permissionDenied: return false
        }
    }

    private static func isReconnect(from previous: ConnectionState?, to current: ConnectionState?) -> Bool {
        current == .connected && previous != .connected
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
