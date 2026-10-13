#if os(macOS)
import AnchorDesign

/// Mac-only copy keeps peer and progress semantics separate from the iPhone dashboard.
enum MacWorkCopy {
    static let subtitle = AnchorStrings.value("mac.work.subtitle", default: "Keep your current work in view.")
    static let peerDisconnected = AnchorStrings.value("mac.work.peer.disconnected", default: "Device disconnected")
    static let reportedProgress = AnchorStrings.value("mac.work.progress.reported", default: "Average reported process progress")
    static let progressUnavailable = AnchorStrings.value("mac.work.progress.unavailable", default: "No process has reported progress yet")
    static let draft = AnchorStrings.value("mac.work.status.draft", default: "Not started")
    static let active = AnchorStrings.value("mac.work.status.active", default: "In progress")
    static let completed = AnchorStrings.value("mac.work.status.completed", default: "Completed")
    static let archived = AnchorStrings.value("mac.work.status.archived", default: "Archived")
    static let metricRunning = AnchorStrings.value("mac.work.metric.running", default: "Running")
    static let metricAttention = AnchorStrings.value("mac.work.metric.attention", default: "Needs a look")
    static let metricDone = AnchorStrings.value("mac.work.metric.done", default: "Done")
    static let connectionHelp = AnchorStrings.value("mac.work.connection.help", default: "Open connection settings")
    static let processesEmptyTitle = AnchorStrings.value("mac.work.processes.empty.title", default: "No linked sessions yet")
    static let processesEmptyDetail = AnchorStrings.value(
        "mac.work.processes.empty.detail",
        default: "Authorize Codex sessions or connect terminal commands in Settings › Sources."
    )
    static let processesEmptyAction = AnchorStrings.value("mac.work.processes.empty.action", default: "Open Sources")
}
#endif
