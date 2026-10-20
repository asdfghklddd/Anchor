import AnchorCore
import Foundation

/// The words that bring the person back to the desk: the card shown when they
/// pick up the phone during work, and the reminder after they stay away.
public enum DeskText {
    public static let backToDesk = AnchorStrings.value("desk.back", default: "Back to the desk")
    public static let turnSideways = AnchorStrings.value(
        "desk.pickup.sideways", default: "Turn the phone sideways to go back to the desk")
    public static let useAnyway = AnchorStrings.value("desk.pickup.use-anyway", default: "Use the phone anyway")
    public static let remindMe = AnchorStrings.value("desk.pickup.remind", default: "Remind me if I stay away")
    public static let needsYou = AnchorStrings.value("desk.pickup.needs-you", default: "Needs you")

    public static func remindsAfter(_ minutes: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("desk.pickup.reminds", default: "Reminder after %lld min away"), minutes)
    }

    /// The reminder's text, true as of the moment the person left: past tense
    /// for a run that may have ended since, present for a result that waits until looked at.
    public static func reminderBody(_ hold: DeskHold) -> String {
        switch hold {
        case let .waiting(_, _, _, meanwhile):
            String.localizedStringWithFormat(
                AnchorStrings.value("desk.reminder.prepare", default: "Your agent was working when you left. Meanwhile: %@"),
                PlanText.meanwhileLine(meanwhile))
        case let .needsYou(_, title, action):
            String.localizedStringWithFormat(
                AnchorStrings.value("desk.reminder.needs-you", default: "%1$@ needs you · %2$@"),
                title, PlanText.line(for: action, compact: true))
        }
    }

    // MARK: Settings

    public static let settingsSection = AnchorStrings.value("desk.settings.section", default: "Desk reminder")
    public static let settingsToggle = AnchorStrings.value("desk.settings.toggle", default: "Remind me when I leave the desk")
    public static let settingsDelay = AnchorStrings.value("desk.settings.delay", default: "After")
    public static let settingsFooter = AnchorStrings.value(
        "desk.settings.footer",
        default: "If you leave Anchor while an agent works on your task or a result waits for you, a reminder comes after this long. It is made on this iPhone and needs no connection.")
    public static let settingsAllow = AnchorStrings.value("desk.settings.allow", default: "Allow reminders")
    public static let settingsDenied = AnchorStrings.value(
        "desk.settings.denied", default: "Notifications are off for Anchor. Turn them on in Settings.")
    public static let settingsOpen = AnchorStrings.value("desk.settings.open", default: "Open Settings")
}
