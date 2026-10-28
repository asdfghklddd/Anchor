#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation

/// What the island shows, read from the projection: one dot per open task,
/// the task the person is on with its next step, the others with their newest
/// conversation, and the phone link.
public struct NotchIslandContent: Equatable, Sendable {
    /// Where a task's newest conversation stands, as its dot shows it.
    public enum Signal: Equatable, Sendable {
        case idle
        case running
        /// Failed, stuck, cut off or waiting for a reply: the iPhone's red light.
        case waiting
        case done
    }

    public struct Conversation: Equatable, Sendable {
        public let request: String?
        public let state: String
        public let updatedAt: Date
    }

    public struct Task: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let title: String
        /// Into the iPhone's task tab colors, so a task matches on both devices.
        public let colorIndex: Int
        public let conversation: Conversation?
        public let signal: Signal
    }

    public enum Plan: Equatable, Sendable {
        case none
        case step(number: Int, total: Int, text: String)
        case finished
    }

    public let current: Task?
    public let plan: Plan
    /// The next step as a ready-to-paste request.
    public let prompt: String?
    /// The other open tasks, most recently active first.
    public let others: [Task]
    public let link: AnchorStatusMenu.Link
    public let fix: AnchorStatusMenu.Fix?
    /// Neither agent's folder is readable yet, so nothing can reach the phone.
    public let needsSources: Bool
    public let peerDevice: String?

    public init(status: AnchorStatusMenu, projection: SessionProjection) {
        let menu = AnchorEdgeMenu(projection: projection)
        let rows = Dictionary(menu.rows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        current = menu.current.map { Self.task(rows[$0.id], fallback: $0) }
        if let step = menu.nextStep {
            plan = .step(number: step.number, total: step.total, text: step.text)
        } else if menu.current?.goal.userPlan?.isFinished == true {
            plan = .finished
        } else {
            plan = .none
        }
        prompt = menu.prompt
        others = menu.rows.filter { $0.id != menu.current?.id }.map { Self.task($0, fallback: $0.task) }
        link = status.link
        fix = status.fix
        needsSources = !status.codexReady && !status.claudeReady
        peerDevice = status.peerDeviceSummary
    }

    /// Every open task, the current one first: the dots beside the housing.
    public var tasks: [Task] {
        [current].compactMap { $0 } + others
    }

    public var isLinked: Bool {
        if case .connected = link { true } else { false }
    }

    /// The link or the agent folders need the person.
    public var linkNeedsAttention: Bool {
        switch link {
        case .bluetoothOff, .bluetoothNotAllowed, .failed: true
        case .connected, .searching, .notPaired: needsSources
        }
    }

    private static func task(_ row: AnchorEdgeMenu.Row?, fallback session: AnchorSession) -> Task {
        let conversation = row?.conversation ?? TaskConversationStack(task: session).front
        return Task(
            id: session.id,
            title: session.goal.title,
            colorIndex: session.taskColorIndex ?? 0,
            conversation: conversation.map {
                Conversation(request: $0.request, state: L10n.runState($0), updatedAt: $0.updatedAt)
            },
            signal: conversation.map(signal) ?? .idle
        )
    }

    static func signal(_ conversation: AnchorProcess) -> Signal {
        if conversation.needsRescue { return .waiting }
        switch conversation.status {
        case .running, .queued: return .running
        case .completed: return .done
        case .failed, .needsDecision, .blocked, .disconnected: return .idle
        }
    }
}
#endif
