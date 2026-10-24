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

/// Whether the person is at the desk. Bluetooth decides: being away is the
/// Bluetooth link to the Mac down for five minutes, and the return is the
/// authenticated Bluetooth link coming back. Until Bluetooth has connected
/// once (no radio, no permission), the effective link stands in for it.
public struct PresenceReducer: Codable, Hashable, Sendable {
    public private(set) var status: PresenceStatus
    public private(set) var absenceBeganAt: Date?
    public private(set) var handoffBeganAt: Date?
    private var lastConnectedAt: Date?
    private var previousLink: ConnectionState?
    private var bluetoothSeen: Bool?
    public var policy: PresencePolicy

    public init(status: PresenceStatus = .unknown, policy: PresencePolicy = PresencePolicy()) {
        self.status = status
        self.policy = policy
    }

    @discardableResult
    public mutating func reduce(_ signals: PresenceSignals) -> PresenceStatus {
        if signals.bluetoothConnection == .connected { bluetoothSeen = true }
        let link = self.link(signals)
        let reconnected = link == .connected && previousLink != .connected
        let longInterruption = absenceBeganAt.map {
            signals.observedAt.timeIntervalSince($0) >= policy.absenceConfirmation
        } ?? false
        defer {
            previousLink = link
            if link == .connected { lastConnectedAt = signals.observedAt }
        }
        if status == .returning { return status }

        // Returning needs an authenticated reconnection, never rotation or RSSI alone.
        if link == .connected {
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
        switch link(signals) {
        case .disconnected, .failed: return true
        case .pairing: return absenceBeganAt != nil
        case .connected, .unavailable, .permissionDenied: return false
        }
    }

    /// The link that says whether the person is near: Bluetooth once it has
    /// worked, since it follows the phone; Wi-Fi alone can reach across a building.
    private func link(_ signals: PresenceSignals) -> ConnectionState {
        if bluetoothSeen == true, let bluetooth = signals.bluetoothConnection,
           bluetooth != .unavailable, bluetooth != .permissionDenied {
            return bluetooth
        }
        return signals.connection
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
