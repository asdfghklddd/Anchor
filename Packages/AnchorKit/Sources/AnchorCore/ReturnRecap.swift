import Foundation

/// One conversation as the return page shows it: its short name and what it
/// is about, what its latest rounds did and where it stands, in at most 60
/// characters.
public struct ConversationRecap: Identifiable, Codable, Hashable, Sendable {
    /// The conversation's process.
    public let id: UUID
    public var name: String
    public var text: String

    public init(id: UUID, name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}

/// A task's conversations, recapped by the Mac when the person came back. It
/// belongs to one return, named by the moment the phone noticed it, and stays
/// with the task afterwards as part of its history.
public struct ReturnRecap: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    /// The return it answers: the current task's `ReturnSummary.generatedAt`.
    public let returnedAt: Date
    public let writtenAt: Date
    /// The task's newest conversations, newest first; at most three.
    public var conversations: [ConversationRecap]

    public init(id: UUID = UUID(), returnedAt: Date, writtenAt: Date = .now, conversations: [ConversationRecap]) {
        self.id = id
        self.returnedAt = returnedAt
        self.writtenAt = writtenAt
        self.conversations = conversations
    }

    /// How many recaps a task keeps.
    public static let kept = 20
}

public extension AnchorSession {
    /// The recap written for this return, once the Mac has sent it.
    func returnRecap(for returnedAt: Date) -> ReturnRecap? {
        returnRecaps?.last { $0.returnedAt == returnedAt }
    }

    /// Recaps of the conversations as the task's returns found them, oldest first.
    mutating func keep(_ recap: ReturnRecap) {
        var recaps = (returnRecaps ?? []).filter { $0.returnedAt != recap.returnedAt }
        recaps.append(recap)
        returnRecaps = Array(recaps.sorted { $0.returnedAt < $1.returnedAt }.suffix(ReturnRecap.kept))
    }
}

public extension SessionProjection {
    /// The return under way, named by when the phone noticed it; `nil` at the desk.
    var returnMoment: Date? {
        guard let session, session.presence == .returning else { return nil }
        return session.returnSummary?.generatedAt
    }
}
