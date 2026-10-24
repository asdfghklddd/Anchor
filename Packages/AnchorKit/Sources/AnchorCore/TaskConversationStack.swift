import Foundation

/// A task's conversations as the desk's task library stacks them: the three
/// most recently active AI conversations (terminal commands are not
/// conversations), the ones behind in the order they joined the task so a
/// card's place stays a cue, and one in front that reads in full. Each turn
/// arrives as its own process; a conversation is the turns from one log,
/// shown as its latest turn.
public struct TaskConversationStack: Hashable, Sendable {
    public static let capacity = 3

    /// A conversation the person brought to the front, and when.
    public struct Pick: Hashable, Sendable {
        /// The conversation's key (`AnchorProcess.conversationKey`).
        public let conversation: UUID
        public let at: Date

        public init(conversation: UUID, at: Date) {
            self.conversation = conversation
            self.at = at
        }
    }

    /// Top to bottom; the last card is the one in front.
    public let cards: [AnchorProcess]

    public var front: AnchorProcess? { cards.last }

    /// A conversation that needs rescuing comes to the front on its own; so
    /// does the newest otherwise. The person's pick holds until some other
    /// conversation moves.
    public init(task: AnchorSession, pick: Pick? = nil) {
        let conversations = Self.conversations(of: task)
        let recent = Set(conversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.capacity).map(\.conversationKey))
        let shown = conversations.filter { recent.contains($0.conversationKey) }
        let newest = shown.filter(\.needsRescue).max { $0.updatedAt < $1.updatedAt }
            ?? shown.max { $0.updatedAt < $1.updatedAt }
        let picked = pick.flatMap { pick in
            shown.contains { $0.conversationKey != pick.conversation && $0.updatedAt > pick.at } ? nil
                : shown.first { $0.conversationKey == pick.conversation }
        }
        guard let front = picked ?? newest else {
            cards = []
            return
        }
        cards = shown.filter { $0.conversationKey != front.conversationKey } + [front]
    }

    /// Every AI conversation of the task, each as its latest turn, in the order
    /// they joined. A turn that does not repeat the request keeps the one before.
    public static func conversations(of task: AnchorSession) -> [AnchorProcess] {
        var order: [UUID] = []
        var turns: [UUID: [AnchorProcess]] = [:]
        for process in task.conversationsInJoiningOrder where process.isConversation {
            if turns[process.conversationKey] == nil { order.append(process.conversationKey) }
            turns[process.conversationKey, default: []].append(process)
        }
        return order.compactMap { key in
            guard let group = turns[key], var latest = group.max(by: { $0.updatedAt < $1.updatedAt }) else { return nil }
            if latest.request == nil {
                latest.request = group.sorted { $0.updatedAt > $1.updatedAt }.lazy.compactMap(\.request).first
            }
            return latest
        }
    }
}

public extension AnchorProcess {
    /// The conversation a turn belongs to: its log's source, one per conversation.
    var conversationKey: UUID { sourceID ?? id }

    /// The old red light: the agent failed, is stuck or cut off, or waits for
    /// the person's answer. Such a card takes the task's color and an anchor,
    /// and comes to the front of its stack.
    var needsRescue: Bool {
        switch status {
        case .needsDecision, .blocked, .disconnected: true
        case .failed: !isInterrupted
        case .running, .queued, .completed: false
        }
    }

    /// Work an agent did in conversation with the person, not a terminal command.
    var isConversation: Bool {
        presentationGroup == .observedTask && sourceID != BuiltInProcessSourceID.file
    }

    /// What the agent last answered: its latest reply, or the error that ended
    /// the turn; `nil` while a turn runs, since an older reply would not answer
    /// the request shown above it.
    var latestReply: String? {
        guard status != .running, status != .queued else { return nil }
        let text = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
