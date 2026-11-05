// Role: real gravity for water and motion effects, through one shared `CMMotionManager`, started off main.

#if os(iOS)
import CoreMotion
import Foundation
import Observation

/// Where "down" is on the screen, from the motion sensor, while the work
/// invitation (or the setup wave) is visible. It runs only between `start()` and `stop()`, never
/// in the background, and needs no permission (device motion only).
@MainActor
@Observable
final class DeviceGravityMonitor {
    /// Angle of real gravity in screen coordinates, in radians: 0 is straight
    /// down in portrait; negative leans toward the left edge (the way to turn).
    private(set) var angle: Double = 0
    /// False on devices or simulators without device motion.
    private(set) var isAvailable = false
    /// The phone has been held sideways while the screen stayed portrait, which
    /// on iPhone means Portrait Orientation Lock is on.
    private(set) var suggestsOrientationLock = false

    @ObservationIgnored private var sidewaysSince: Date?
    @ObservationIgnored private var listening = false

    func start() {
        guard !listening, GravitySensor.shared.isAvailable else { return }
        listening = true
        isAvailable = true
        RotationTrace.note("gravity start requested")
        GravitySensor.shared.add(ObjectIdentifier(self)) { [weak self] x, y in
            Task { @MainActor in
                guard let self, self.listening else { return }
                self.receive(x: x, y: y)
            }
        }
    }

    func stop() {
        if listening { RotationTrace.note("gravity stop requested") }
        listening = false
        GravitySensor.shared.remove(ObjectIdentifier(self))
        sidewaysSince = nil
        if suggestsOrientationLock { suggestsOrientationLock = false }
    }

    private func receive(x: Double, y: Double) {
        // Ignore a phone lying flat: gravity then has almost no screen component.
        guard hypot(x, y) > 0.35 else { return }
        let raw = atan2(x, -y)
        // A light low-pass keeps the rope from trembling with the hand.
        angle += (raw - angle) * 0.18
        let lock: Bool
        if abs(raw) > 1.2 {
            sidewaysSince = sidewaysSince ?? .now
            lock = Date.now.timeIntervalSince(sidewaysSince ?? .now) > 1.5
        } else {
            sidewaysSince = nil
            lock = false
        }
        if lock != suggestsOrientationLock { suggestsOrientationLock = lock }
    }
}

/// The app's one motion manager, as Apple asks. Starting and stopping the
/// sensor can hold the calling thread, and turning the phone is exactly when
/// the invitation starts or stops it, so all of it happens on the sensor's own
/// queue, never on the main thread. Each monitor listens while it is started.
private final class GravitySensor: @unchecked Sendable {
    static let shared = GravitySensor()

    let isAvailable: Bool
    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "anchor.gravity"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private let lock = NSLock()
    private var listeners: [ObjectIdentifier: @Sendable (Double, Double) -> Void] = [:]

    private init() {
        isAvailable = manager.isDeviceMotionAvailable
        manager.deviceMotionUpdateInterval = 1.0 / 30
    }

    func add(_ id: ObjectIdentifier, _ listener: @escaping @Sendable (Double, Double) -> Void) {
        let first = lock.withLock {
            listeners[id] = listener
            return listeners.count == 1
        }
        guard first else { return }
        queue.addOperation { [self] in
            guard !manager.isDeviceMotionActive else { return }
            let began = Date.now
            manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
                guard let self, let gravity = motion?.gravity else { return }
                for listener in lock.withLock({ Array(listeners.values) }) { listener(gravity.x, gravity.y) }
            }
            RotationTrace.note("gravity sensor started", took: Date.now.timeIntervalSince(began))
        }
    }

    func remove(_ id: ObjectIdentifier) {
        let last = lock.withLock { () -> Bool in
            guard listeners.removeValue(forKey: id) != nil else { return false }
            return listeners.isEmpty
        }
        guard last else { return }
        queue.addOperation { [self] in
            // A monitor may have started again while this waited its turn.
            guard lock.withLock({ listeners.isEmpty }), manager.isDeviceMotionActive else { return }
            let began = Date.now
            manager.stopDeviceMotionUpdates()
            RotationTrace.note("gravity sensor stopped", took: Date.now.timeIntervalSince(began))
        }
    }
}
#endif
