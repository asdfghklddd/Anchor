#if os(iOS)
import AnchorCore
import AnchorDesign
import Observation
import UIKit
import UserNotifications

/// The reminder that brings the person back when they leave Anchor while an
/// agent works on their task or a result waits for them. The phone schedules
/// it itself when Anchor goes to the background and withdraws it on return,
/// so it needs no connection, no push and no paid developer account. Its
/// words are true as of leaving; a result that lands later is not in it.
@MainActor
@Observable
final class DeskReminder {
    static let enabledKey = "anchor.deskReminder.enabled"
    static let minutesKey = "anchor.deskReminder.minutes"
    static let defaultMinutes = 2
    static let minuteChoices = [1, 2, 5]

    private static let identifier = "anchor.desk.reminder"

    private(set) var authorization: UNAuthorizationStatus = .notDetermined

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static var minutes: Int {
        let stored = UserDefaults.standard.integer(forKey: minutesKey)
        return minuteChoices.contains(stored) ? stored : defaultMinutes
    }

    func refresh() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asked only from an explicit button, never on its own: the system prompt
    /// cannot appear once Anchor is in the background, when the reminder is made.
    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await refresh()
    }

    /// Replaces any pending reminder with one for this hold.
    func schedule(_ hold: DeskHold, subtitle: String?) {
        guard Self.isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = DeskText.backToDesk
        if let subtitle { content.subtitle = subtitle }
        content.body = DeskText.reminderBody(hold)
        content.sound = .default
        content.threadIdentifier = Self.identifier
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(Self.minutes * 60), repeats: false)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger), withCompletionHandler: nil)
    }

    /// Back in Anchor: the reminder has nothing left to say.
    func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier])
    }

    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
#endif
