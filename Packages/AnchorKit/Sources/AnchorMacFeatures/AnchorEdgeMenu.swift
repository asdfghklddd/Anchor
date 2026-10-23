#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation

/// What the boat's buttons offer, read once when they open: the task the person
/// is on and its next step, and the open tasks for the list the Mac shows while
/// the phone is away.
public struct AnchorEdgeMenu: Sendable {
    /// One open task, with the conversation the desk would show in front.
    public struct Row: Identifiable, Sendable {
        public let task: AnchorSession
        public let conversation: AnchorProcess?
        public var id: UUID { task.id }
    }

    public struct NextStep: Sendable, Equatable {
        /// From 1.
        public let number: Int
        public let total: Int
        public let text: String
    }

    public let current: AnchorSession?
    public let nextStep: NextStep?
    /// The next step as a ready-to-paste request, carrying its goal.
    public let prompt: String?
    /// Open tasks, the current one first, then the most recently active.
    public let rows: [Row]
    public let isPhoneConnected: Bool

    public init(projection: SessionProjection) {
        let open = projection.hostedSessions.filter { $0.status == .active || $0.status == .draft }
        let current = projection.session.flatMap { session in open.first { $0.id == session.id } }
        self.current = current
        if let current, let plan = current.goal.userPlan, let index = plan.nextStepIndex {
            nextStep = NextStep(number: index + 1, total: plan.items.count, text: plan.steps[index])
            prompt = PlanText.prompt(goal: current.goal, step: index)
        } else {
            nextStep = nil
            prompt = nil
        }
        let others = open.filter { $0.id != current?.id }
            .sorted { Self.lastActive($0) > Self.lastActive($1) }
        rows = ([current].compactMap { $0 } + others).map(Self.row)
        isPhoneConnected = projection.connection == .connected
    }

    private static func row(_ task: AnchorSession) -> Row {
        Row(task: task, conversation: TaskConversationStack(task: task).front)
    }

    private static func lastActive(_ task: AnchorSession) -> Date {
        task.processes.map(\.updatedAt).max() ?? task.startedAt
    }
}

public enum EdgeMenuCopy {
    static let boatHint = AnchorStrings.value(
        "mac.edge.hint", default: "Click for your next step and quick actions; drag to move")
    static let copyNextStep = AnchorStrings.value("mac.edge.copy", default: "Copy next step")
    static let copied = AnchorStrings.value("mac.edge.copied", default: "Copied")
    static let copyUnavailable = AnchorStrings.value(
        "mac.edge.copy.none", default: "The task you're on has no open step to copy")
    static let switchTask = AnchorStrings.value("mac.edge.switch", default: "Switch task")
    static let catchUp = AnchorStrings.value("mac.edge.catch-up", default: "Catch me up")
    static let more = AnchorStrings.value("mac.edge.more", default: "More")
    static let current = AnchorStrings.value("mac.edge.current", default: "You're on")
    static let noTask = AnchorStrings.value("mac.edge.no-task", default: "No task yet. Drop an anchor on your phone.")
    static let noPlan = AnchorStrings.value("mac.edge.no-plan", default: "No steps yet")
    static let allDone = AnchorStrings.value("mac.edge.all-done", default: "All steps done")
    static let phoneConnected = AnchorStrings.value(
        "mac.edge.phone.on", default: "Phone connected · details are on the phone")
    static let phoneAway = AnchorStrings.value("mac.edge.phone.off", default: "Phone not connected")
    static let you = AnchorStrings.value("mac.edge.you", default: "You:")
    static let noConversation = AnchorStrings.value("mac.edge.no-conversation", default: "No conversation yet")
    public static let settings = AnchorStrings.value("menu.settings", default: "Settings…")
    public static let quit = AnchorStrings.value("menu.quit", default: "Quit Anchor")
    public static let openWindow = AnchorStrings.value("menu.open", default: "Open Anchor")

    static func step(_ step: AnchorEdgeMenu.NextStep) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.edge.step", default: "Step %1$lld of %2$lld · %3$@"),
            step.number, step.total, step.text)
    }

    static func more(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("mac.edge.more-tasks", default: "%lld more"), count)
    }

    static func age(since date: Date) -> String {
        date.formatted(.relative(presentation: .numeric, unitsStyle: .narrow)
            .locale(AnchorStrings.interfaceLocale))
    }
}
#endif
