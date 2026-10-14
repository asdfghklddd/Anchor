#if os(iOS)
import CoreMotion
import Foundation
import Observation

/// Where "down" is on the screen, from the motion sensor, while the work
/// invitation is visible. It runs only between `start()` and `stop()`, never
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

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var sidewaysSince: Date?

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        isAvailable = true
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let gravity = motion?.gravity else { return }
            MainActor.assumeIsolated { self.receive(x: gravity.x, y: gravity.y) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        sidewaysSince = nil
        suggestsOrientationLock = false
    }

    private func receive(x: Double, y: Double) {
        // Ignore a phone lying flat: gravity then has almost no screen component.
        guard hypot(x, y) > 0.35 else { return }
        let raw = atan2(x, -y)
        // A light low-pass keeps the rope from trembling with the hand.
        angle += (raw - angle) * 0.18
        if abs(raw) > 1.2 {
            sidewaysSince = sidewaysSince ?? .now
            suggestsOrientationLock = Date.now.timeIntervalSince(sidewaysSince ?? .now) > 1.5
        } else {
            sidewaysSince = nil
            suggestsOrientationLock = false
        }
    }
}
#endif
