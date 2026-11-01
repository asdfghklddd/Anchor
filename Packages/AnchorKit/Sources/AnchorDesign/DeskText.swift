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

    // MARK: Task library (the landscape desk)

    public static let library = AnchorStrings.value("home.task.library", default: "Task library")
    public static let openTask = AnchorStrings.value("desk.library.open", default: "Tap to open the task")
    public static let noConversations = AnchorStrings.value(
        "desk.library.empty", default: "Conversations the Mac files under this task appear here")
    public static let noReply = AnchorStrings.value("desk.library.no-reply", default: "No reply yet")
    public static let noOtherTask = AnchorStrings.value("desk.library.no-other-task", default: "No other task")
    /// "7 对话": how many conversations the desk's tasks hold.
    public static func conversationCount(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("desk.library.conversations", default: "%lld conversations"), count)
    }
    public static let showConversation = AnchorStrings.value(
        "desk.library.show", default: "Brings this conversation to the front")
    public static let you = AnchorStrings.value("desk.library.you", default: "You")
    public static let reply = AnchorStrings.value("desk.library.reply", default: "Reply")

    // MARK: Recall card (a conversation, opened from the desk)

    public static let recallWaitingAnswer = AnchorStrings.value("desk.recall.waiting.answer", default: "Waiting for your answer")
    public static let recallWaitingAct = AnchorStrings.value("desk.recall.waiting.act", default: "Waiting for you to do")
    public static let recallRunning = AnchorStrings.value("desk.recall.running", default: "Still working")
    public static let recallIdle = AnchorStrings.value("desk.recall.idle", default: "Nothing waits on you")
    public static let recallPlanDone = AnchorStrings.value("desk.recall.plan-done", default: "Every step is done")
    public static let recallNew = AnchorStrings.value("desk.recall.new", default: "New")
    public static let recallOpened = AnchorStrings.value("desk.recall.opened", default: "Opened on the Mac")
    public static let recallNotConnected = AnchorStrings.value("desk.recall.not-connected", default: "The Mac isn't connected")
    public static let recallOpenOnMac = AnchorStrings.value("desk.recall.open-on-mac", default: "Open on the Mac")
    public static let recallClose = AnchorStrings.value("desk.recall.close", default: "Close")
    public static let recallHint = AnchorStrings.value(
        "desk.recall.hint", default: "Swipe up to open it on the Mac, down to close")

    public static func recallNextStep(_ step: String) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("desk.recall.next-step", default: "Next: %@"), step)
    }

    public static func recallDecided(_ decision: String) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("desk.recall.decided", default: "You decided: %@"), decision)
    }

    /// A fact about where the work stands, as a short chip.
    public static func recallFact(_ fact: ConversationDigest.Fact) -> String {
        switch fact {
        case let .committed(hash?):
            String.localizedStringWithFormat(AnchorStrings.value("desk.recall.fact.committed", default: "Committed %@"), hash)
        case .committed(nil):
            AnchorStrings.value("desk.recall.fact.committed-plain", default: "Committed")
        case .pushed: AnchorStrings.value("desk.recall.fact.pushed", default: "Pushed")
        case .notPushed: AnchorStrings.value("desk.recall.fact.not-pushed", default: "Not pushed")
        case .testsPassed: AnchorStrings.value("desk.recall.fact.tests-passed", default: "Tests passed")
        case .testsMostlyPassed: AnchorStrings.value("desk.recall.fact.tests-mostly", default: "Tests mostly passed")
        case .testsFailed: AnchorStrings.value("desk.recall.fact.tests-failed", default: "Tests failed")
        case .testsRan: AnchorStrings.value("desk.recall.fact.tests-ran", default: "Tests ran")
        case .unverified: AnchorStrings.value("desk.recall.fact.unverified", default: "Not tried on a device")
        case .interrupted: AnchorStrings.value("desk.recall.fact.interrupted", default: "You stopped it")
        case .stoppedByError: AnchorStrings.value("desk.recall.fact.error", default: "Stopped by an error")
        case let .filesChanged(count):
            String.localizedStringWithFormat(AnchorStrings.value("desk.recall.fact.files", default: "%lld files changed"), count)
        }
    }
}
