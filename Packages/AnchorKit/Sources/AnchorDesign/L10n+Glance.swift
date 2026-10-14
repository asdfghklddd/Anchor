import AnchorCore
import Foundation

/// Copy for the home glance (tide), task cards and the ambient clock.
public extension L10n {
    static let glanceTitle = AnchorStrings.value("home.glance.title", default: "Now")
    static let glanceEmpty = AnchorStrings.value("home.glance.empty", default: "A quiet harbor")
    static let glanceEmptyDetail = AnchorStrings.value(
        "home.glance.empty.detail",
        default: "Drop an anchor and its AI conversations and terminal commands will appear here."
    )
    static let glanceAwaiting = AnchorStrings.value("home.glance.awaiting", default: "Waiting for the first record")
    static let glanceAwaitingDetail = AnchorStrings.value(
        "home.glance.awaiting.detail",
        default: "Start a Codex conversation or a terminal command on your Mac."
    )
    static let glanceAllDone = AnchorStrings.value("home.glance.done", default: "All done")
    static let glanceQuiet = AnchorStrings.value("home.glance.quiet", default: "Nothing running")
    static let glanceRunning = AnchorStrings.value("home.glance.running", default: "running")
    static let glanceAttention = AnchorStrings.value("home.glance.attention", default: "need a look")
    static let glanceFailed = AnchorStrings.value("home.glance.failed", default: "failed")
    static let glanceCompleted = AnchorStrings.value("home.glance.completed", default: "done")
    static let glanceNow = AnchorStrings.value("home.glance.now", default: "now")
    static let glanceSavedRecords = AnchorStrings.value("home.glance.saved", default: "Saved records")
    static let glanceNoRecords = AnchorStrings.value("home.glance.no.records", default: "No records yet")
    static let glanceLatest = AnchorStrings.value("home.glance.latest", default: "Latest")

    static func glanceMore(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("home.glance.more", default: "+%lld more anchors"), count
        )
    }

    /// The left edge of the tide window, exact rather than rounded ("90 min ago").
    static func glanceWindowStart(_ span: TimeInterval) -> String {
        let minutes = Int(span / 60)
        if minutes < 120 || minutes % 60 != 0 {
            return String.localizedStringWithFormat(
                AnchorStrings.value("home.glance.window.minutes", default: "%lld min ago"), minutes)
        }
        return String.localizedStringWithFormat(
            AnchorStrings.value("home.glance.window.hours", default: "%lld h ago"), minutes / 60)
    }

    /// One verb per lifecycle fact. Never claims more than the source reported.
    static func eventVerb(_ kind: ProcessEventKind, interrupted: Bool) -> String {
        if interrupted { return AnchorStrings.value("event.verb.interrupted", default: "stopped") }
        switch kind {
        case .created: return AnchorStrings.value("event.verb.started", default: "started")
        case .progress: return AnchorStrings.value("event.verb.progress", default: "made progress")
        case .outputReady: return AnchorStrings.value("event.verb.output", default: "has new output")
        case .decisionRequired: return AnchorStrings.value("event.verb.waiting", default: "is waiting for input")
        case .decisionResolved: return AnchorStrings.value("event.verb.resumed", default: "resumed")
        case .completed: return AnchorStrings.value("event.verb.completed", default: "finished")
        case .failed: return AnchorStrings.value("event.verb.failed", default: "failed")
        case .note: return AnchorStrings.value("event.verb.note", default: "saved a note")
        case .presence, .connection: return AnchorStrings.value("event.verb.updated", default: "updated")
        }
    }

    static func tideState(_ state: TideState) -> String {
        switch state {
        // Same word as the glance headline ("运行中"), so one screen never names
        // the running state two ways.
        case .running: AnchorStrings.value("tide.running", default: "Running")
        case .attention: AnchorStrings.value("status.attention", default: "Needs a look")
        case .failed: AnchorStrings.value("status.failed", default: "Failed")
        case .interrupted: AnchorStrings.value("status.interrupted", default: "Interrupted")
        case .completed: AnchorStrings.value("status.completed", default: "Completed")
        }
    }

    static let cardAwaitingSource = AnchorStrings.value("card.awaiting.source", default: "Waiting for a source")
    static let cardProgressUnreported = AnchorStrings.value("card.progress.unreported", default: "Progress not reported")
    static func cardStateSummary(running: Int, attention: Int, failed: Int, interrupted: Int) -> String {
        var parts: [String] = []
        if failed > 0 { parts.append("\(failed) " + glanceFailed) }
        if attention > 0 { parts.append("\(attention) " + glanceAttention) }
        if interrupted > 0 { parts.append("\(interrupted) " + AnchorStrings.value("home.glance.interrupted", default: "stopped")) }
        if running > 0 { parts.append("\(running) " + glanceRunning) }
        return parts.joined(separator: " · ")
    }

    /// Read by VoiceOver for the wordless landscape invitation.
    static let workInvitation = AnchorStrings.value(
        "work.invitation", default: "Turn your phone to the left to open the work desk."
    )
    static let workInvitationLock = AnchorStrings.value(
        "work.invitation.lock", default: "Orientation lock is on. Turn it off in Control Center, then turn your phone."
    )
    static let ambientElapsed = AnchorStrings.value("ambient.elapsed", default: "Since start")
    static let ambientElapsedHint = AnchorStrings.value(
        "ambient.elapsed.hint",
        default: "Time since the selected task started, including breaks."
    )
    static func minutesShort(_ minutes: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("ambient.minutes", default: "%lld min"), minutes)
    }
}
