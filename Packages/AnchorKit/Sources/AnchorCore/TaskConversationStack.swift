import Foundation

/// A task's conversations as the desk's task library stacks them: the three
/// most recently active AI conversations (terminal commands are not
/// conversations), the ones behind in the order they joined the task so a
/// card's place stays a cue, and one in front that reads in full.
public struct TaskConversationStack: Hashable, Sendable {
    public static let capacity = 3

    /// A conversation the person brought to the front, and when.
    public struct Pick: Hashable, Sendable {
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

    /// The newest conversation is in front, unless the person picked another
    /// one since: their pick holds until some other conversation moves.
    public init(task: AnchorSession, pick: Pick? = nil) {
        let conversations = task.conversationsInJoiningOrder.filter(\.isConversation)
        let recent = Set(conversations.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.capacity).map(\.id))
        let shown = conversations.filter { recent.contains($0.id) }
        let newest = shown.max { $0.updatedAt < $1.updatedAt }
        let picked = pick.flatMap { pick in
            shown.contains { $0.id != pick.conversation && $0.updatedAt > pick.at } ? nil
                : shown.first { $0.id == pick.conversation }
        }
        guard let front = picked ?? newest else {
            cards = []
            return
        }
        cards = shown.filter { $0.id != front.id } + [front]
    }
}

public extension AnchorProcess {
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
