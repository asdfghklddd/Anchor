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
}
#endif
