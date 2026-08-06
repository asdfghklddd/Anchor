import AnchorCore
import Foundation

public enum L10n {
    public static let appName = AnchorStrings.value("app.name", default: "Anchor")
    public static let actionFailed = AnchorStrings.value(
        "action.failed",
        default: "Action not completed"
    )
    public static let workspace = AnchorStrings.value("workspace", default: "Workspace")
    public static let currentGoal = AnchorStrings.value("current.goal", default: "CURRENT GOAL")
    public static let processes = AnchorStrings.value("processes", default: "Processes")
    public static let recentEvent = AnchorStrings.value("recent.event", default: "Latest event")
    public static let recentActivity = AnchorStrings.value("activity.recent", default: "Recent activity")
    public static let notifications = AnchorStrings.value("notifications", default: "Notifications")
    public static let profile = AnchorStrings.value("profile", default: "My Anchor")
    public static let personalAnchor = AnchorStrings.value("profile.personal", default: "PERSONAL ANCHOR")
    public static let contextSyncStable = AnchorStrings.value("profile.sync.stable", default: "Context sync is stable")
    public static let macOnline = AnchorStrings.value("profile.mac.online", default: "Mac online")
    public static let guardedFocus = AnchorStrings.value("profile.focus.guarded", default: "Focus protected")
    public static let savedContexts = AnchorStrings.value("profile.contexts.saved", default: "Saved contexts")
    public static let completedAnchors = AnchorStrings.value("profile.anchors.completed", default: "Completed anchors")
    public static let thisSessionData = AnchorStrings.value("profile.session.data", default: "THIS SESSION")
    public static let runningWork = AnchorStrings.value("profile.work.running", default: "Work in progress")
    public static let memoryTrace = AnchorStrings.value("profile.memory.trace", default: "MEMORY TRACE")
    public static let recentlyHeld = AnchorStrings.value("profile.memory.recent", default: "Recently held by Anchor")
    public static let workStyle = AnchorStrings.value("profile.work.style", default: "WORK STYLE")
    public static let insights = AnchorStrings.value("insights", default: "Work context")
    public static let history = AnchorStrings.value("history", default: "History")
    public static let settings = AnchorStrings.value("settings", default: "Settings")
    public static let editGoal = AnchorStrings.value("goal.edit", default: "Edit goal")
    public static let layout = AnchorStrings.value("layout", default: "Task layout")
    public static let finish = AnchorStrings.value("finish", default: "Finish session")
    public static let cancel = AnchorStrings.value("cancel", default: "Cancel")
    public static let save = AnchorStrings.value("save", default: "Save")
    public static let done = AnchorStrings.value("done", default: "Done")
    public static let continueAction = AnchorStrings.value("continue", default: "Continue")
    public static let retry = AnchorStrings.value("retry", default: "Try again")
    public static let close = AnchorStrings.value("close", default: "Close")
    public static let add = AnchorStrings.value("add", default: "Add")
    public static let delete = AnchorStrings.value("delete", default: "Delete")
    public static let goalTitle = AnchorStrings.value("goal.title", default: "What are you finishing?")
    public static let completionCriteria = AnchorStrings.value("goal.criteria", default: "What does done look like?")
    public static let contextNote = AnchorStrings.value("goal.context", default: "Context worth keeping")
    public static let establishAnchor = AnchorStrings.value("setup.title", default: "Establish an anchor")
    public static let setupIntro = AnchorStrings.value("setup.intro", default: "Name the outcome, then add the work already in motion.")
    public static let beginSession = AnchorStrings.value("setup.begin", default: "Begin this session")
    public static let processName = AnchorStrings.value("process.name", default: "Process or source name")
    public static let addProcess = AnchorStrings.value("process.add", default: "Add process")
    public static let setupHint = AnchorStrings.value("setup.dictation.hint", default: "Use the microphone on the system keyboard whenever dictation is helpful.")
    public static let setupNewWork = AnchorStrings.value("setup.new.work", default: "New work")
    public static let setupMantra = AnchorStrings.value("setup.mantra", default: "Remember why first,\nthen decide what to do.")
    public static let setupGoalLabel = AnchorStrings.value("setup.goal.label", default: "What are you completing this time?")
    public static let setupCriteriaLabel = AnchorStrings.value("setup.criteria.label", default: "What should completion look like?")
    public static let parallelProcesses = AnchorStrings.value("process.parallel", default: "PARALLEL PROCESSES")
    public static let readyProcesses = AnchorStrings.value("process.ready", default: "Work ready to sync")
    public static let completionReady = AnchorStrings.value("setup.completion.ready", default: "Completion criteria")
    public static let addAnotherProcess = AnchorStrings.value("process.add.another", default: "Add another process")
    public static let startAnchoring = AnchorStrings.value("setup.start.anchoring", default: "Start anchoring")
    public static let keyboardDictation = AnchorStrings.value("setup.keyboard.dictation", default: "Use keyboard dictation")
    public static let anchorNote = AnchorStrings.value("note.anchor", default: "Drop an anchor")
    public static let anchorNotePrompt = AnchorStrings.value("note.prompt", default: "Capture a judgment, next step, or context marker.")
    public static let anchorCaptureHeadline = AnchorStrings.value("note.capture.headline", default: "Remember this moment, then keep moving.")
    public static let currentWorkKicker = AnchorStrings.value("work.current", default: "CURRENT WORK")
    public static let currentSnapshot = AnchorStrings.value("work.snapshot", default: "Work snapshot")
    public static let momentToRemember = AnchorStrings.value("note.moment", default: "What should be remembered now")
    public static let notePlaceholder = AnchorStrings.value("note.placeholder", default: "A judgment, next step, or context worth preserving")
    public static let recentAnchor = AnchorStrings.value("note.recent", default: "Most recent anchor")
    public static let dropAnchor = AnchorStrings.value("note.drop", default: "Drop anchor")
    public static let noteSaved = AnchorStrings.value("note.saved", default: "Anchor saved")
    public static let attentionNeeded = AnchorStrings.value("attention", default: "Needs your judgment")
    public static let noAttentionNeeded = AnchorStrings.value("attention.none", default: "Nothing needs your attention")
    public static let chooseDirection = AnchorStrings.value("decision.choose", default: "Choose an option")
    public static let confirmChoice = AnchorStrings.value("decision.confirm", default: "Confirm choice")
    public static let chooseVisualDirection = AnchorStrings.value("decision.visual.direction", default: "Choose a visual direction")
    public static let goChooseDirection = AnchorStrings.value("process.choose.direction", default: "Choose direction")
    public static let runNow = AnchorStrings.value("process.action.run.now", default: "Run now")
    public static let viewOutput = AnchorStrings.value("process.action.view.output", default: "View output")
    public static let taskProgress = AnchorStrings.value("task.progress", default: "Task progress")
    public static let currentStatus = AnchorStrings.value("task.current.status", default: "CURRENT STATUS")
    public static let activityLog = AnchorStrings.value("task.activity.log", default: "ACTIVITY LOG")
    public static let activity = AnchorStrings.value("activity", default: "Activity")
    public static let estimated = AnchorStrings.value("estimated", default: "Estimate")
    public static let overallProgress = AnchorStrings.value("progress.overall", default: "Overall progress")
    public static let focusSession = AnchorStrings.value("focus.session", default: "FOCUS SESSION")
    public static let greetingMorning = AnchorStrings.value("greeting.morning", default: "Good morning")
    public static let greetingAfternoon = AnchorStrings.value("greeting.afternoon", default: "Good afternoon")
    public static let greetingEvening = AnchorStrings.value("greeting.evening", default: "Good evening")
    public static let focusHeadline = AnchorStrings.value("focus.headline", default: "Keep your attention for judgment.")
    public static let currentAnchorMap = AnchorStrings.value("goal.anchor.map", default: "ANCHOR MAP · CURRENT GOAL")
    public static let liveProcesses = AnchorStrings.value("process.live", default: "LIVE PROCESSES")
    public static let happeningNow = AnchorStrings.value("process.happening.now", default: "What is happening now")
    public static let live = AnchorStrings.value("status.live", default: "LIVE")
    public static let processFlow = AnchorStrings.value("process.flow", default: "Process flow")
    public static let parallelEfficiency = AnchorStrings.value("process.parallel.efficiency", default: "Parallel efficiency 2.4×")
    public static let macConnected = AnchorStrings.value("connection.mac.connected", default: "Mac connected")
    public static let remoteSyncing = AnchorStrings.value("connection.remote.syncing", default: "Remote syncing")
    public static let generating = AnchorStrings.value("status.generating", default: "Generating")
    public static let rendering = AnchorStrings.value("status.rendering", default: "Rendering")
    public static let confirmed = AnchorStrings.value("status.confirmed", default: "Confirmed")
    public static let preparing = AnchorStrings.value("status.preparing", default: "Preparing")
    public static let waitingConfirmation = AnchorStrings.value("status.waiting.confirmation", default: "Waiting for you")
    public static let focusTime = AnchorStrings.value("focus.time", default: "Focus time")
    public static let focusActive = AnchorStrings.value("focus.active", default: "In focus")
    public static let confirmDirection = AnchorStrings.value("decision.confirm.direction", default: "Confirm direction")
    public static let ambient = AnchorStrings.value("ambient", default: "Ambient workspace")
    public static let ambientActive = AnchorStrings.value("ambient.active", default: "ANCHOR ACTIVE")
    public static let latestProgress = AnchorStrings.value("ambient.latest.progress", default: "LATEST PROGRESS")
    public static func latestDecisionProgress(source: String, metric: String, metricLabel: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value(
                "ambient.latest.decision",
                default: "%1$@ · %2$@ %3$@ awaiting judgment"
            ),
            source,
            metric,
            metricLabel
        )
    }
    public static func latestCompletedProgress(source: String, title: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value(
                "ambient.latest.completed",
                default: "%1$@ · Completed %@"
            ),
            source,
            title
        )
    }
    public static let allProcessesRunning = AnchorStrings.value("ambient.all.running", default: "All processes keep running")
    public static let ambientClearHeadline = AnchorStrings.value("ambient.clear.headline", default: "No action needed")
    public static func ambientClearSummary(running: Int, queued: Int) -> String {
        if queued > 0 {
            return String.localizedStringWithFormat(
                AnchorStrings.value("ambient.clear.summary.queued", default: "%1$lld automatic · %2$lld queued"),
                running,
                queued
            )
        }
        return String.localizedStringWithFormat(
            AnchorStrings.value("ambient.clear.summary", default: "%lld automatic"),
            running
        )
    }
    public static let selectedProcess = AnchorStrings.value("process.selected", default: "Selected process")
    public static let handoff = AnchorStrings.value("handoff", default: "Securing your context…")
    public static let handoffSecured = AnchorStrings.value("handoff.secured", default: "Secured. You can step away.")
    public static let handoffDetail = AnchorStrings.value("handoff.detail", default: "Anchor is gathering every process around the same goal.")
    public static let away = AnchorStrings.value("away", default: "Your work is still moving")
    public static let awayDetail = AnchorStrings.value("away.detail", default: "Anchor is holding the goal and watching for meaningful changes.")
    public static let remoteProcesses = AnchorStrings.value("away.processes", default: "REMOTE PROCESSES")
    public static let synchronizedWork = AnchorStrings.value("away.synchronized.work", default: "Work that keeps syncing")
    public static let currentAnchor = AnchorStrings.value("away.current.anchor", default: "CURRENT ANCHOR · CURRENT GOAL")
    public static let atDeskCorrection = AnchorStrings.value("presence.at.desk", default: "I’m still at my desk")
    public static let returning = AnchorStrings.value("return.title", default: "Welcome back")
    public static let returnDetail = AnchorStrings.value("return.detail", default: "Here is what changed while you were away.")
    public static let returnHeadline = AnchorStrings.value("return.headline", default: "Your work was held safely.")
    public static let returnImpact = AnchorStrings.value("return.impact", default: "IMPACT WHILE AWAY")
    public static let returnChanges = AnchorStrings.value("return.changes", default: "Changes while you were away")
    public static let yourNextStep = AnchorStrings.value("return.next.step", default: "YOUR NEXT STEP")
    public static let continueWorking = AnchorStrings.value("return.continue", default: "Continue working")
    public static let recommendedNext = AnchorStrings.value("return.recommended", default: "Recommended next")
    public static let connectionUnknown = AnchorStrings.value("connection.unknown", default: "Presence is unknown")
    public static let connectionUnknownDetail = AnchorStrings.value("connection.unknown.detail", default: "Anchor cannot confirm that you left. Check Mac, local network, and Bluetooth access.")
    public static let disconnected = AnchorStrings.value("disconnected", default: "Mac disconnected")
    public static let stale = AnchorStrings.value("stale", default: "Data may be out of date")
    public static let emptyTitle = AnchorStrings.value("empty.title", default: "No active anchor")
    public static let emptyDetail = AnchorStrings.value("empty.detail", default: "Start with one clear outcome and the processes supporting it.")
    public static let sessionSummary = AnchorStrings.value("summary", default: "Session summary")
    public static let completeSession = AnchorStrings.value("complete.session", default: "Complete and preserve")
    public static let finishConfirmTitle = AnchorStrings.value(
        "finish.confirm.title",
        default: "Finish and preserve this session?"
    )
    public static let finishConfirmDetail = AnchorStrings.value(
        "finish.confirm.detail",
        default: "Anchor will save the goal, processes, decisions, and notes. You can resume this session later."
    )
    public static let completed = AnchorStrings.value("completed", default: "Session complete")
    public static let resume = AnchorStrings.value("resume", default: "Resume session")
    public static let notes = AnchorStrings.value("notes", default: "Anchor notes")
    public static let decisions = AnchorStrings.value("decisions", default: "Decisions")
    public static let completedWork = AnchorStrings.value("work.completed", default: "Completed work")
    public static let taskManagement = AnchorStrings.value("task.management", default: "Manage processes")
    public static let reorderProcesses = AnchorStrings.value("task.reorder", default: "Reorder")
    public static let moveUp = AnchorStrings.value("task.move.up", default: "Move up")
    public static let moveDown = AnchorStrings.value("task.move.down", default: "Move down")
    public static let moveHint = AnchorStrings.value("task.move.hint", default: "Reorder the processes or change their dashboard footprint.")
    public static let connections = AnchorStrings.value("connections", default: "Connections")
    public static let sources = AnchorStrings.value("sources", default: "Sources")
    public static let privacy = AnchorStrings.value("privacy", default: "Privacy")
    public static let accessibility = AnchorStrings.value("accessibility", default: "Accessibility")
    public static let nearby = AnchorStrings.value("connection.nearby", default: "Nearby")
    public static let outOfRange = AnchorStrings.value("connection.out.of.range", default: "Out of range")
    public static let notificationsSettings = AnchorStrings.value("notifications.settings", default: "Notifications")
    public static let macConnection = AnchorStrings.value("connection.mac", default: "Mac connection")
    public static let bluetoothProximity = AnchorStrings.value("connection.bluetooth", default: "Bluetooth proximity")
    public static let localOnly = AnchorStrings.value("privacy.local", default: "Local by default")
    public static let localOnlyDetail = AnchorStrings.value("privacy.local.detail", default: "Raw work content stays on your devices unless you explicitly connect a source.")
    public static let notificationMeaningful = AnchorStrings.value("notifications.meaningful", default: "Meaningful changes")
    public static let notificationDecisions = AnchorStrings.value("notifications.decisions", default: "Decision requests")
    public static let notificationPermissionDetail = AnchorStrings.value(
        "notifications.permission.detail",
        default: "Allow notifications in System Settings to receive decision requests."
    )
    public static let displaySupport = AnchorStrings.value("accessibility.display", default: "Display accommodations")
    public static let displaySupportDetail = AnchorStrings.value("accessibility.display.detail", default: "Anchor follows Dynamic Type, VoiceOver, Reduce Motion, Increase Contrast, and Reduce Transparency automatically.")
    public static let sourceHealth = AnchorStrings.value("source.health", default: "Source health")
    public static let connectedSources = AnchorStrings.value("source.connected", default: "Connected sources")
    public static let sourceDetails = AnchorStrings.value("source.details", default: "Source details")
    public static let sourceProgress = AnchorStrings.value("source.progress", default: "Source progress")
    public static let sourceActivity = AnchorStrings.value("source.activity", default: "Recent source activity")
    public static let openSourceDetails = AnchorStrings.value("source.open.details", default: "Open source details")
    public static let connected = AnchorStrings.value("connected", default: "Connected")
    public static let unknown = AnchorStrings.value("unknown", default: "Unknown")
    public static let permissionDenied = AnchorStrings.value("permission.denied", default: "Permission denied")
    public static let permissionDeniedDetail = AnchorStrings.value(
        "permission.denied.detail",
        default: "Allow Local Network and Bluetooth access in System Settings, then try again."
    )
    public static let disconnectedDetail = AnchorStrings.value(
        "disconnected.detail",
        default: "The Mac is offline. Work already synced remains available."
    )
    public static let connectionFailedDetail = AnchorStrings.value(
        "connection.failed.detail",
        default: "Anchor could not reach the Mac service. Check the local connection and try again."
    )
    public static let lastUpdated = AnchorStrings.value("last.updated", default: "Last updated")
    public static let noEvents = AnchorStrings.value("events.none", default: "No events yet")
    public static let openDetails = AnchorStrings.value("mac.open.details", default: "Open Anchor")
    public static let openCurrentProcess = AnchorStrings.value("mac.open.current", default: "Open current process")
    public static let currentWork = AnchorStrings.value("mac.current.work", default: "Current work")
    public static let timeline = AnchorStrings.value("timeline", default: "Timeline")
    public static let historyNoSnapshots = AnchorStrings.value(
        "history.no.snapshots",
        default: "No saved snapshots yet"
    )
    public static let historyNoSnapshotsDetail = AnchorStrings.value(
        "history.no.snapshots.detail",
        default: "Anchor will save a context snapshot when you step away, return, or preserve this session."
    )
    public static let historyEmptyDetail = AnchorStrings.value(
        "history.empty.detail",
        default: "Start a session to build a clear record of your work and decisions."
    )
    public static let timelineEmptyDetail = AnchorStrings.value(
        "timeline.empty.detail",
        default: "When work moves, Anchor will keep the decision trail here."
    )
    public static let pairDevice = AnchorStrings.value("pair.device", default: "Pair device")
    public static let pairingCode = AnchorStrings.value("pair.code", default: "Pairing code")
    public static let pairingHint = AnchorStrings.value(
        "pair.hint",
        default: "Enter this six-digit code in Anchor on your iPhone."
    )
    public static let copyPairingCode = AnchorStrings.value(
        "pair.copy",
        default: "Copy pairing code"
    )
    public static let pairingCodeCopied = AnchorStrings.value(
        "pair.copied",
        default: "Pairing code copied"
    )
    public static let pairingUnavailable = AnchorStrings.value(
        "pair.unavailable",
        default: "Device pairing is unavailable in this build."
    )
    public static let startAtLogin = AnchorStrings.value("start.login", default: "Open at login")
    public static let quit = AnchorStrings.value("quit", default: "Quit Anchor")
    public static let openSystemSettings = AnchorStrings.value(
        "system.settings.open",
        default: "Open System Settings"
    )
    public static let voiceOver = AnchorStrings.value("accessibility.voiceover", default: "VoiceOver")
    public static let dynamicType = AnchorStrings.value("accessibility.dynamic.type", default: "Dynamic Type")
    public static let reduceMotion = AnchorStrings.value("accessibility.reduce.motion", default: "Reduce Motion")
    public static let increaseContrast = AnchorStrings.value("accessibility.increase.contrast", default: "Increase Contrast")
    public static let reduceTransparency = AnchorStrings.value("accessibility.reduce.transparency", default: "Reduce Transparency")

    public static func processCount(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("process.count", default: "%lld processes"), count)
    }

    public static func noteCount(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("note.count", default: "%lld notes"), count)
    }

    public static func decisionCount(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("decision.count", default: "%lld decisions"), count)
    }

    public static func minuteCount(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("minute.count", default: "%lldm"), count)
    }

    public static func focusSummary(running: Int, attention: Int) -> String {
        if attention > 0 {
            String.localizedStringWithFormat(
                AnchorStrings.value("focus.summary.attention", default: "%1$lld processes moving, %2$lld waiting for you"),
                running,
                attention
            )
        } else {
            String.localizedStringWithFormat(
                AnchorStrings.value("focus.summary", default: "%lld processes moving"),
                running
            )
        }
    }

    public static func routesRunning(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("process.routes.running", default: "%lld routes running"),
            count
        )
    }

    public static func anchoredCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("note.anchored.count", default: "%lld anchors dropped"),
            count
        )
    }

    public static func focusDuration(_ minutes: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("focus.duration", default: "%lldm"),
            minutes
        )
    }

    public static func awayDuration(_ minutes: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("away.duration", default: "Away for %lld minutes"),
            minutes
        )
    }

    public static func runningAndWaiting(running: Int, attention: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("snapshot.running.waiting", default: "%1$lld running · %2$lld waiting"),
            running,
            attention
        )
    }

    public static func processAttentionSummary(processes: Int, attention: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("process.attention.summary", default: "%1$lld processes · %2$lld waiting"),
            processes,
            attention
        )
    }

    public static func returnProgress(_ percent: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("return.progress", default: "The work moved forward %lld%%"),
            percent
        )
    }

    public static func startedAt(_ time: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("session.started.at", default: "Started %@"),
            time
        )
    }

    public static func tileSize(_ size: ProcessTileSize) -> String {
        switch size {
        case .compact: AnchorStrings.value("tile.compact", default: "Compact")
        case .standard: AnchorStrings.value("tile.standard", default: "Standard")
        case .wide: AnchorStrings.value("tile.wide", default: "Wide")
        case .large: AnchorStrings.value("tile.large", default: "Large")
        }
    }

    public static func status(_ status: ProcessStatus) -> String {
        switch status {
        case .queued: AnchorStrings.value("status.queued", default: "Queued")
        case .running: AnchorStrings.value("status.running", default: "Running")
        case .needsDecision: AnchorStrings.value("status.decision", default: "Needs decision")
        case .blocked: AnchorStrings.value("status.blocked", default: "Blocked")
        case .completed: AnchorStrings.value("status.completed", default: "Completed")
        case .failed: AnchorStrings.value("status.failed", default: "Failed")
        case .disconnected: AnchorStrings.value("status.disconnected", default: "Disconnected")
        }
    }

    public static func compactStatus(_ status: ProcessStatus) -> String {
        switch status {
        case .queued: AnchorStrings.value("status.compact.queued", default: "Queued")
        case .running: AnchorStrings.value("status.compact.running", default: "Running")
        case .needsDecision: AnchorStrings.value("status.compact.decision", default: "Decision")
        case .blocked: AnchorStrings.value("status.compact.blocked", default: "Blocked")
        case .completed: AnchorStrings.value("status.compact.completed", default: "Done")
        case .failed: AnchorStrings.value("status.compact.failed", default: "Failed")
        case .disconnected: AnchorStrings.value("status.compact.disconnected", default: "Offline")
        }
    }

}
