import AnchorCore
import Foundation

/// RSSI is a noisy radio measurement, not a distance in metres. Separate
/// thresholds plus consecutive readings prevent one pocket/wall fluctuation
/// from changing the proximity indicator. These defaults still require on-device calibration.
struct BluetoothProximityFilter: Sendable {
    static let sampleInterval: TimeInterval = 2
    static let staleInterval: TimeInterval = 12
    // Discrete near/far classification. The gap retains the last confirmed
    // state; unavailable evidence stays unknown rather than pretending "far".
    private static let nearThreshold = -65
    private static let farThreshold = -75
    private static let confirmationSamples = 3
    private(set) var state: ProximityState = .unknown
    private var candidate: ProximityState = .unknown
    private var count = 0
    private var lastSampleAt: Date?

    mutating func sample(_ rssi: Int, at date: Date = .now) -> ProximityState {
        guard (-127 ... -1).contains(rssi) else { return reset() }
        if let lastSampleAt, date.timeIntervalSince(lastSampleAt) > Self.staleInterval { reset() }
        lastSampleAt = date
        let next: ProximityState = rssi >= Self.nearThreshold ? .near : (rssi <= Self.farThreshold ? .far : .unknown)
        guard next != .unknown else {
            candidate = .unknown
            count = 0
            return state
        }
        count = candidate == next ? count + 1 : 1
        candidate = next
        if count >= Self.confirmationSamples { state = next }
        return state
    }

    @discardableResult
    mutating func reset() -> ProximityState {
        state = .unknown
        candidate = .unknown
        count = 0
        lastSampleAt = nil
        return state
    }
}
