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

    public struct Progress: Equatable, Sendable {
        public let done: Int
        public let total: Int
        public var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
        public var isFinished: Bool { total > 0 && done >= total }
    }

    public enum Plan: Equatable, Sendable {
        case none
        case step(number: Int, total: Int, text: String)
        case finished
    }

    public let current: Task?
    public let plan: Plan
    /// How many of the current task's steps the person has marked done, for
    /// the ring beside the closed island; nil without a plan.
    public let progress: Progress?
    /// The next step as a ready-to-paste request.
    public let prompt: String?
    /// The other open tasks, most recently active first.
    public let others: [Task]
    public let link: AnchorStatusMenu.Link
    public let fix: AnchorStatusMenu.Fix?
    /// Neither agent's folder is readable yet, so nothing can reach the phone.
    public let needsSources: Bool
    public let peerDevice: String?
    /// The code to type on the phone, while it asks for one.
    public let pairingCode: String?
    /// Why connecting the agent folders failed, until the person tries again.
    public let sourcesError: String?
    /// Where each conversation is filed, to correct it from the island.
    public let filing: NotchFiling

    static let otherLimit = 2

    public init(status: AnchorStatusMenu, projection: SessionProjection,
                pairingCode: String? = nil, sourcesError: String? = nil, filing: NotchFiling = .empty) {
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
        if let steps = menu.current?.goal.userPlan, !steps.items.isEmpty {
            progress = Progress(done: steps.completedSteps.count, total: steps.items.count)
        } else {
            progress = nil
        }
        prompt = menu.prompt
        // The iPhone anchors three tasks at most; past that, a task waiting on the
        // person keeps its row before a quieter one, and rows keep their order.
        let all = menu.rows.filter { $0.id != menu.current?.id }.map { Self.task($0, fallback: $0.task) }
        let kept = Set((all.filter { $0.signal == .waiting } + all.filter { $0.signal != .waiting })
            .prefix(Self.otherLimit).map(\.id))
        others = all.filter { kept.contains($0.id) }
        link = status.link
        fix = status.fix
        needsSources = !status.codexReady && !status.claudeReady
        peerDevice = status.peerDeviceName
        self.pairingCode = status.link == .notPaired ? pairingCode : nil
        self.sourcesError = needsSources ? sourcesError : nil
        self.filing = filing
    }

    /// Every open task, the current one first: the dots beside the housing.
    public var tasks: [Task] {
        [current].compactMap { $0 } + others
    }

    public var isLinked: Bool {
        if case .connected = link { true } else { false }
    }

    /// Bluetooth is off or refused, or the link broke: worth showing even
    /// while the island is closed. A phone that is merely away is not this.
    public var linkTrouble: Bool {
        switch link {
        case .bluetoothOff, .bluetoothNotAllowed, .failed: true
        case .connected, .searching, .notPaired: false
        }
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
