#if os(iOS)
import UIKit

/// Keeps the screen on while the desk board is up and the phone is charging,
/// so the board on its stand does not go dark mid-task; on battery the
/// system's own sleep timer stays in charge.
@MainActor
final class DeskKeepAwake {
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        UIDevice.current.isBatteryMonitoringEnabled = true
        apply(UIDevice.current.batteryState)
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.apply(UIDevice.current.batteryState) }
        }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        UIApplication.shared.isIdleTimerDisabled = false
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    private func apply(_ state: UIDevice.BatteryState) {
        UIApplication.shared.isIdleTimerDisabled = Self.keepsAwake(state)
    }

    nonisolated static func keepsAwake(_ state: UIDevice.BatteryState) -> Bool {
        state == .charging || state == .full
    }
}
#endif
