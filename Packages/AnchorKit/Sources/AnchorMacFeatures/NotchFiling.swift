#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation

/// Where each agent conversation is filed, for correcting it from the island:
/// a task's own conversations, the ones Anchor could not place, and the tasks
/// a conversation can move to.
public struct NotchFiling: Equatable, Sendable {
    public struct Conversation: Identifiable, Equatable, Sendable {
        /// The conversation's log ID, as `MacSourceSetupModel` files it.
        public let id: String
        public let title: String
        public let taskID: UUID?
        /// Tasks its words leaned towards, best first; only for unsorted ones.
        public let leaning: [UUID]
    }

    public struct Target: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let title: String
    }

    /// As many as a task's stack on the phone shows.
    static let perTask = TaskConversationStack.capacity

    public let filed: [UUID: [Conversation]]
    public let unsorted: [Conversation]
    /// Every open task, in the island's order.
    public let targets: [Target]

    public static let empty = NotchFiling(filed: [:], unsorted: [], targets: [])

    init(filed: [UUID: [Conversation]], unsorted: [Conversation], targets: [Target]) {
        self.filed = filed
        self.unsorted = unsorted
        self.targets = targets
    }

    public init(conversations: [CodexConversationSummary], placements: [String: UUID],
                unsorted: [CodexConversationSummary], candidates: [String: [UUID]],
                tasks: [AnchorSession]) {
        let open = Set(tasks.map(\.id))
        var filed: [UUID: [Conversation]] = [:]
        for summary in Self.newestFirst(conversations) {
            guard let task = placements[summary.id], open.contains(task),
                  filed[task, default: []].count < Self.perTask else { continue }
            filed[task, default: []].append(Self.conversation(summary, task: task, leaning: []))
        }
        self.filed = filed
        self.unsorted = Self.newestFirst(unsorted).map {
            Self.conversation($0, task: nil, leaning: candidates[$0.id] ?? [])
        }
        targets = tasks.map { Target(id: $0.id, title: $0.goal.title) }
    }

    public func conversations(of task: UUID) -> [Conversation] {
        filed[task] ?? []
    }

    /// The tasks a conversation can go to: never its own, the ones its words
    /// leaned towards first.
    public func targets(for conversation: Conversation) -> [Target] {
        let rank = { (target: Target) in conversation.leaning.firstIndex(of: target.id) ?? Int.max }
        return targets.filter { $0.id != conversation.taskID }.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    private static func conversation(_ summary: CodexConversationSummary, task: UUID?,
                                     leaning: [UUID]) -> Conversation {
        Conversation(id: summary.id,
                     title: summary.title ?? summary.candidate.workspaceName ?? NotchIslandCopy.conversation,
                     taskID: task, leaning: leaning)
    }

    private static func newestFirst(_ summaries: [CodexConversationSummary]) -> [CodexConversationSummary] {
        summaries.sorted { lhs, rhs in
            let left = lastMoved(lhs), right = lastMoved(rhs)
            return left == right ? lhs.id < rhs.id : left > right
        }
    }

    private static func lastMoved(_ summary: CodexConversationSummary) -> Date {
        switch summary.state {
        case let .running(since): since
        case let .completed(at, _), let .failed(at, _), let .interrupted(at): at
        case .unknown: summary.candidate.createdAt ?? summary.candidate.modifiedAt
        }
    }
}
#endif
