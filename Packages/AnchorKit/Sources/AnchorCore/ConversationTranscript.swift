import Foundation

/// The latest rounds of a conversation, read from its log on the Mac only to
/// write a return recap. Like other conversation text it is read transiently:
/// it is never stored, synced or shown; only the recap written from it travels.
public struct ConversationTranscript: Hashable, Sendable {
    /// What the person asked and the agent's last words in answer.
    public struct Round: Hashable, Sendable {
        public var request: String
        public var reply: String?

        public init(request: String, reply: String? = nil) {
            self.request = request
            self.reply = reply
        }
    }

    /// Oldest first.
    public var rounds: [Round]

    public init(rounds: [Round]) {
        self.rounds = rounds
    }

    public static let roundLimit = 5
    /// Characters kept of each message: the opening states the ask and the
    /// outcome; the rest is detail the recap has no room for.
    static let messageLimit = 1_200

    /// The last `limit` rounds of the log at `url`, in either dialect; `nil`
    /// when the log holds no request yet.
    public static func read(at url: URL, limit: Int = roundLimit) -> ConversationTranscript? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        // Logs grow long with tool output; read more of the tail until enough rounds show.
        for window in [UInt64(1 << 20), 8 << 20, 32 << 20] {
            let start = size > window ? size - window : 0
            guard (try? handle.seek(toOffset: start)) != nil,
                  var data = try? handle.readToEnd() else { return nil }
            if start > 0, let newline = data.firstIndex(of: 10) { data.removeSubrange(...newline) }
            let rounds = Self.rounds(in: data)
            if rounds.count >= limit || start == 0 {
                return rounds.isEmpty ? nil : ConversationTranscript(rounds: Array(rounds.suffix(limit)))
            }
        }
        return nil
    }

    static func rounds(in data: Data) -> [Round] {
        var rounds: [Round] = []
        // Codex writes each message twice, as an event and as a response item;
        // events are preferred, and items count only in logs without them.
        var itemRounds: [Round] = []
        var sawEvents = false
        for line in data.split(separator: 10) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
            switch Self.message(in: object) {
            case let .request(text, isItem):
                if isItem { itemRounds.append(Round(request: text)) } else { rounds.append(Round(request: text)) }
                sawEvents = sawEvents || !isItem
            case let .reply(text, isItem):
                if isItem {
                    if !itemRounds.isEmpty { itemRounds[itemRounds.count - 1].reply = text }
                } else if !rounds.isEmpty {
                    rounds[rounds.count - 1].reply = text
                }
            case nil:
                continue
            }
        }
        return sawEvents || itemRounds.isEmpty ? rounds : itemRounds
    }

    private enum Message {
        /// `isItem`: Codex's response-item copy rather than its event.
        case request(String, isItem: Bool)
        case reply(String, isItem: Bool)
    }

    private static func message(in object: [String: Any]) -> Message? {
        let type = object["type"] as? String
        // Claude Code: prompts the person typed and the assistant's text, never sub-agents or tools.
        if type == "user" || type == "assistant" {
            guard object["isSidechain"] as? Bool != true, object["isMeta"] as? Bool != true,
                  let message = object["message"] as? [String: Any] else { return nil }
            let text = (message["content"] as? String)
                ?? (message["content"] as? [[String: Any]])?
                    .filter { $0["type"] as? String == "text" }.compactMap { $0["text"] as? String }
                    .joined(separator: "\n") ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if type == "assistant" { return clipped(trimmed).map { .reply($0, isItem: false) } }
            guard ClaudeCodeTurnReader.isPrompt(trimmed), !trimmed.hasPrefix("[Request interrupted") else { return nil }
            return clipped(trimmed).map { .request($0, isItem: false) }
        }
        guard let payload = object["payload"] as? [String: Any] else { return nil }
        if type == "event_msg" {
            switch payload["type"] as? String {
            case "user_message":
                return (payload["message"] as? String).flatMap(CodexAutoAssociation.userWords(in:))
                    .flatMap(clipped).map { .request($0, isItem: false) }
            case "agent_message":
                return (payload["message"] as? String).flatMap(clipped).map { .reply($0, isItem: false) }
            default:
                return nil
            }
        }
        guard type == "response_item", payload["type"] as? String == "message",
              let content = payload["content"] as? [[String: Any]] else { return nil }
        switch payload["role"] as? String {
        case "user":
            let words = content.filter { $0["type"] as? String == "input_text" }
                .compactMap { $0["text"] as? String }.compactMap(CodexAutoAssociation.userWords(in:))
                .joined(separator: "\n")
            return clipped(words).map { .request($0, isItem: true) }
        case "assistant":
            let words = content.filter { $0["type"] as? String == "output_text" }
                .compactMap { $0["text"] as? String }.joined(separator: "\n")
            return clipped(words).map { .reply($0, isItem: true) }
        default:
            return nil
        }
    }

    /// The message without code blocks, which say little a glance needs, and
    /// cut to its opening.
    static func clipped(_ text: String) -> String? {
        var lines: [Substring] = []
        var inCode = false
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                inCode.toggle()
                continue
            }
            if !inCode, !trimmed.isEmpty { lines.append(line) }
        }
        let joined = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { return nil }
        return joined.count > messageLimit ? String(joined.prefix(messageLimit - 1)) + "…" : joined
    }
}
