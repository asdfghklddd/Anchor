#if os(macOS)
import AppKit
import Foundation

/// One Anchor per Mac. A newly opened copy asks any older one to quit and
/// waits for it, so two islands, radios and folder readers never run at once.
/// This is also how a reset restarts: the fresh copy takes over.
public enum MacSingleInstance {
    static let takeOverNotification = Notification.Name("com.andywang.anchor.mac.take-over")

    @MainActor private static var observer: (any NSObjectProtocol)?

    /// Asks older copies to quit and waits for them, before any store loads;
    /// from then on this copy quits as soon as a newer one does the same.
    @MainActor
    public static func claim(timeout: TimeInterval = 5) {
        let me = String(ProcessInfo.processInfo.processIdentifier)
        let center = DistributedNotificationCenter.default()
        center.postNotificationName(takeOverNotification, object: me, userInfo: nil, deliverImmediately: true)
        waitForOthers(timeout: timeout)
        observer = center.addObserver(forName: takeOverNotification, object: nil, queue: .main) { notification in
            guard (notification.object as? String) != me else { return }
            MainActor.assumeIsolated { quit() }
        }
    }

    /// Quits even with a sheet or modal alert up, which would otherwise stop
    /// AppKit from terminating and leave this copy running beside the new one.
    @MainActor
    public static func quit() {
        for window in NSApp.windows {
            while let sheet = window.attachedSheet { window.endSheet(sheet) }
        }
        if NSApp.modalWindow != nil { NSApp.abortModal() }
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exit(0) }
    }

    private static func waitForOthers(timeout: TimeInterval) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline,
              NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .contains(where: { $0.processIdentifier != me && !$0.isTerminated }) {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }
}
#endif
