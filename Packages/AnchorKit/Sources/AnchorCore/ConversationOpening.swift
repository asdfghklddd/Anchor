import Foundation

/// The person's request, from the phone, to open a conversation on the Mac.
/// Like the day's activity it travels outside the event history: it acts
/// once, right away, or not at all, so a late delivery is dropped.
public struct ConversationOpenRequest: Codable, Hashable, Sendable {
    public static let envelopeType = "anchor.open.v1"
    /// Older than this, the person has moved on and opening it would surprise them.
    public static let freshFor: TimeInterval = 30

    /// The conversation, as its log's source (`AnchorProcess.conversationKey`).
    public let conversation: UUID
    public let requestedAt: Date

    public init(conversation: UUID, requestedAt: Date = .now) {
        self.conversation = conversation
        self.requestedAt = requestedAt
    }

    public func isFresh(at now: Date = .now) -> Bool {
        abs(now.timeIntervalSince(requestedAt)) <= Self.freshFor
    }

    public func envelope(sourceID: UUID) throws -> EventEnvelope {
        EventEnvelope(sessionID: UUID(), sourceID: sourceID, sequence: 0, timestamp: requestedAt,
                      type: Self.envelopeType, payload: try JSONEncoder.anchor.encode(self))
    }

    public init?(envelope: EventEnvelope) {
        guard envelope.type == Self.envelopeType,
              let request = try? JSONDecoder.anchor.decode(ConversationOpenRequest.self, from: envelope.payload)
        else { return nil }
        self = request
    }
}

/// Where an agent conversation opens on the Mac: Codex opens the thread
/// itself; the Claude app opens only its Code tab, so the command that
/// resumes the session comes with it, for the clipboard.
public struct ConversationLink: Hashable, Sendable {
    public let url: URL
    public let resumeCommand: String?

    public init(url: URL, resumeCommand: String? = nil) {
        self.url = url
        self.resumeCommand = resumeCommand
    }

    public init?(logAt fileURL: URL) {
        guard let metadata = CodexSessionMetadata.read(from: fileURL) else { return nil }
        self.init(metadata: metadata)
    }

    init?(metadata: CodexSessionMetadata) {
        guard let id = metadata.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed), !id.isEmpty else { return nil }
        if metadata.originator == HarnessSessionStatus.originator {
            // The harness opens no single conversation by link; it comes to the front.
            guard let url = URL(string: "dsh://open") else { return nil }
            self.init(url: url)
        } else if metadata.originator == WorkBuddyLog.originator {
            guard let url = URL(string: "workbuddy://chat/\(id)") else { return nil }
            self.init(url: url)
        } else if metadata.originator == CodexSessionMetadata.claudeCodeOriginator {
            guard let url = URL(string: "claude://code") else { return nil }
            self.init(url: url, resumeCommand: "claude --resume \(metadata.id)")
        } else {
            guard let url = URL(string: "codex://threads/\(id)") else { return nil }
            self.init(url: url)
        }
    }
}
