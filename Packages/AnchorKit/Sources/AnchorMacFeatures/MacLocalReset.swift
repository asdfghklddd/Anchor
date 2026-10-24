#if os(macOS)
import AnchorDesign
import AppKit
import Foundation

/// Starts the Mac over: everything read from agent folders goes, folder
/// access stays. The wipe runs on the next launch, before any store loads,
/// so no running reader can write old state back.
public enum MacLocalReset {
    static let pendingKey = "anchor.mac.reset.pending"

    /// Marks the reset and relaunches Anchor to carry it out.
    @MainActor
    public static func requestAndRelaunch(defaults: UserDefaults) {
        defaults.set(true, forKey: pendingKey)
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            // If the new copy failed to open, the reset still runs at the next launch.
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    /// Whether this launch should start over; clears the request.
    public static func takePending(defaults: UserDefaults) -> Bool {
        guard defaults.bool(forKey: pendingKey) else { return false }
        defaults.removeObject(forKey: pendingKey)
        return true
    }

    /// Waits for the copy that asked for the relaunch to finish quitting.
    public static func waitForPreviousInstance(timeout: TimeInterval = 10) {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline,
              NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .contains(where: { $0.processIdentifier != me && !$0.isTerminated }) {
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    /// Removes read positions and the task-run mirror, and forgets placements.
    public static func wipe(files: [URL], defaults: UserDefaults) {
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        MacSourceSetupModel.forgetConversationState(in: defaults)
    }
}

enum MacLocalResetCopy {
    static let title = AnchorStrings.value("mac.reset.title", default: "Reset Mac Data…")
    static let detail = AnchorStrings.value(
        "mac.reset.detail",
        default: "Clears every conversation Anchor has read and how it filed them, here and on your iPhone. Folder access and pairing stay. Anchor restarts and reads the folders again.")
    static let confirmTitle = AnchorStrings.value("mac.reset.confirm.title", default: "Reset Anchor on this Mac?")
    static let confirmMessage = AnchorStrings.value(
        "mac.reset.confirm.message",
        default: "Conversations disappear from your tasks on this Mac and your iPhone, then come back as Anchor reads the folders again. Conversations you ignored or moved will be filed afresh.")
    static let confirm = AnchorStrings.value("mac.reset.confirm", default: "Reset and Restart")
}
#endif
