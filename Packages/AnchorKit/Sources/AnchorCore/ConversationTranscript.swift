import Foundation

/// The latest rounds of a conversation, read from its log on the Mac only to
/// write a return recap. Like other conversation text it is read transiently:
/// it is never stored, synced or shown; only the recap written from it travels.
public struct ConversationTranscript: Hashable, Sendable {
    /// What the person asked and the agent's last words in answer.
    public struct Round: Hashable, Sendable {
        public var request: String
        public var reply: String?
        /// Files the agent wrote in this round, as their paths.
        public var files: [String] = []
        /// Shell commands the agent ran in this round, each cut to its opening.
        public var commands: [String] = []
        /// The person stopped the round before it ended.
        public var interrupted = false

        public init(request: String, reply: String? = nil, files: [String] = [], commands: [String] = [],
                    interrupted: Bool = false) {
            self.request = request
            self.reply = reply
            self.files = files
            self.commands = commands
            self.interrupted = interrupted
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
    public static func read(at url: URL, limit: Int = roundLimit,
                            windows: [UInt64] = defaultWindows) -> ConversationTranscript? {
        var follower: Follower?
        return follow(url, with: &follower, limit: limit, windows: windows)
    }

    public static let defaultWindows: [UInt64] = [1 << 20, 8 << 20, 32 << 20]

    /// Like `read`, for a log read again and again as it grows: the first call
    /// reads its tail, and each later one only what was written since.
    public static func follow(_ url: URL, with follower: inout Follower?, limit: Int = roundLimit,
                              windows: [UInt64] = defaultWindows) -> ConversationTranscript? {
        // A harness status file is small and rewritten whole: read it again each time.
        if HarnessSessionStatus.isStatusFile(url) {
            return HarnessSessionStatus(contentsOf: url)?.transcript(limit: limit)
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        if var current = follower, current.offset <= size {
            guard (try? handle.seek(toOffset: current.offset)) != nil, let data = try? handle.readToEnd() else { return nil }
            current.consume(data)
            follower = current
            return current.transcript(limit: limit)
        }
        // Logs grow long with tool output; read more of the tail until enough rounds show.
        for window in windows {
            let start = size > window ? size - window : 0
            guard (try? handle.seek(toOffset: start)) != nil,
                  var data = try? handle.readToEnd() else { return nil }
            var skipped = 0
            if start > 0, let newline = data.firstIndex(of: 10) {
                skipped = data.distance(from: data.startIndex, to: newline) + 1
                data.removeSubrange(...newline)
            }
            var fresh = Follower(offset: start + UInt64(skipped))
            fresh.consume(data)
            if fresh.roundCount >= limit || start == 0 || window == windows.last {
                follower = fresh
                return fresh.transcript(limit: limit)
            }
        }
        return nil
    }

    static func rounds(in data: Data) -> [Round] {
        var follower = Follower(offset: 0)
        follower.consume(data + Data([10]))
        return follower.rounds
    }

    /// Reading state kept between reads of a growing log.
    public struct Follower: Sendable {
        /// Where the next read starts: just past the last whole line.
        private(set) var offset: UInt64
        private var eventRounds: [Round] = []
        // Codex writes each message twice, as an event and as a response item;
        // events are preferred, and items count only in logs without them.
        private var itemRounds: [Round] = []
        private var sawEvents = false
        /// Rounds kept: more than any reader asks for, so memory stays flat.
        private static let kept = 12

        init(offset: UInt64) {
            self.offset = offset
        }

        var rounds: [Round] { sawEvents || itemRounds.isEmpty ? eventRounds : itemRounds }
        var roundCount: Int { rounds.count }

        func transcript(limit: Int) -> ConversationTranscript? {
            rounds.isEmpty ? nil : ConversationTranscript(rounds: Array(rounds.suffix(limit)))
        }

        /// Reads whole lines; a line still being written waits for the next read.
        mutating func consume(_ data: Data) {
            guard let lastNewline = data.lastIndex(of: 10) else { return }
            let whole = data[data.startIndex...lastNewline]
            offset += UInt64(whole.count)
            for line in whole.split(separator: 10) {
                guard !ConversationTranscript.isToolOutput(line) else { continue }
                guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else { continue }
                // A reply can carry its tool calls in the same entry, so the line is read for both.
                if let tools = ConversationTranscript.toolUse(in: object) {
                    if !eventRounds.isEmpty { eventRounds[eventRounds.count - 1].absorb(tools) }
                    if !itemRounds.isEmpty { itemRounds[itemRounds.count - 1].absorb(tools) }
                }
                switch ConversationTranscript.message(in: object) {
                case let .request(text, isItem):
                    if isItem { itemRounds.append(Round(request: text)) } else { eventRounds.append(Round(request: text)) }
                    sawEvents = sawEvents || !isItem
                case let .reply(text, isItem):
                    if isItem {
                        if !itemRounds.isEmpty { itemRounds[itemRounds.count - 1].reply = text }
                    } else if !eventRounds.isEmpty {
                        eventRounds[eventRounds.count - 1].reply = text
                    }
                case nil:
                    continue
                }
            }
            if eventRounds.count > Self.kept { eventRounds.removeFirst(eventRounds.count - Self.kept) }
            if itemRounds.count > Self.kept { itemRounds.removeFirst(itemRounds.count - Self.kept) }
        }
    }

    private static let outputMarkers = [#""type":"function_call_output""#, #""type":"function_call_result""#,
                                        #""type":"custom_tool_call_output""#,
                                        #""type":"reasoning""#, #""type":"token_count""#, #""type":"tool_result""#]
        .map { Data($0.utf8) }

    /// Tool output, reasoning and token counts make up most of a log and say
    /// nothing here; their opening names them, so they are skipped unparsed.
    static func isToolOutput(_ line: Data.SubSequence) -> Bool {
        let head = line.prefix(2_048)
        return outputMarkers.contains { head.range(of: $0) != nil }
    }

    /// What one log line says the agent did, rather than said.
    struct ToolUse {
        var files: [String] = []
        var commands: [String] = []
        var interrupted = false
    }

    nonisolated(unsafe) private static let patchFile = /\*\*\* (?:Update|Add) File: ([^\s"\\]+)/
    nonisolated(unsafe) private static let codexCommand = /"cmd"\s*:\s*"((?:[^"\\]|\\.)*)"/
    static let commandLimit = 300

    /// Tool calls (written files, shell commands) and interruptions; `nil` for any other line.
    static func toolUse(in object: [String: Any]) -> ToolUse? {
        let type = object["type"] as? String
        // WorkBuddy: tool calls and stops are lines of their own.
        if type == "function_call" {
            let input = WorkBuddyLog.arguments(of: object)
            var use = ToolUse()
            switch object["name"] as? String {
            case "Edit", "Write", "MultiEdit", "NotebookEdit":
                if let path = input["file_path"] as? String { use.files.append(path) }
            case "Bash":
                if let command = input["command"] as? String { use.commands.append(String(command.prefix(commandLimit))) }
            default:
                break
            }
            return use.files.isEmpty && use.commands.isEmpty ? nil : use
        }
        if WorkBuddyLog.isInterruption(object) { return ToolUse(interrupted: true) }
        if type == "assistant", object["isSidechain"] as? Bool != true,
           let blocks = (object["message"] as? [String: Any])?["content"] as? [[String: Any]] {
            var use = ToolUse()
            for block in blocks where block["type"] as? String == "tool_use" {
                let input = block["input"] as? [String: Any] ?? [:]
                switch block["name"] as? String {
                case "Edit", "Write", "MultiEdit", "NotebookEdit":
                    if let path = input["file_path"] as? String { use.files.append(path) }
                case "Bash":
                    if let command = input["command"] as? String { use.commands.append(String(command.prefix(commandLimit))) }
                default:
                    break
                }
            }
            return use.files.isEmpty && use.commands.isEmpty ? nil : use
        }
        if type == "user", object["isSidechain"] as? Bool != true,
           let message = object["message"] as? [String: Any] {
            let text = (message["content"] as? String)
                ?? (message["content"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
            return text?.hasPrefix("[Request interrupted") == true ? ToolUse(interrupted: true) : nil
        }
        guard let payload = object["payload"] as? [String: Any] else { return nil }
        switch payload["type"] as? String {
        case "custom_tool_call", "function_call":
            let body = (payload["input"] as? String) ?? (payload["arguments"] as? String) ?? ""
            var use = ToolUse()
            use.files = body.matches(of: patchFile).map { String($0.1) }
            use.commands = body.matches(of: codexCommand).map { String($0.1.prefix(commandLimit)) }
            if use.commands.isEmpty, use.files.isEmpty { use.commands = [String(body.prefix(commandLimit))] }
            return use
        case "turn_aborted":
            return ToolUse(interrupted: true)
        default:
            return nil
        }
    }

    enum Message {
        /// `isItem`: Codex's response-item copy rather than its event.
        case request(String, isItem: Bool)
        case reply(String, isItem: Bool)
    }

    static func message(in object: [String: Any]) -> Message? {
        let type = object["type"] as? String
        if type == "message" {
            if let request = WorkBuddyLog.request(in: object) { return clipped(request).map { .request($0, isItem: false) } }
            return WorkBuddyLog.reply(in: object).flatMap(clipped).map { .reply($0, isItem: false) }
        }
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
    /// cut to its opening and its end.
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
        // The opening states the outcome and the end asks the person for what is next.
        guard joined.count > messageLimit else { return joined }
        let tail = messageLimit / 3
        return String(joined.prefix(messageLimit - tail - 1)) + "…\n" + String(joined.suffix(tail))
    }
}

extension ConversationTranscript.Round {
    mutating func absorb(_ use: ConversationTranscript.ToolUse) {
        files += use.files.filter { !files.contains($0) }
        commands += use.commands
        interrupted = interrupted || use.interrupted
    }
}
