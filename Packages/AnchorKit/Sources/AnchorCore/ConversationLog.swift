import Foundation

/// Which agent wrote a conversation log. Everything downstream (matching,
/// binding, syncing, pings) is shared; only reading the lines differs.
public enum ConversationDialect: String, Codable, Hashable, Sendable {
    /// Codex CLI, editors and the desktop app (`~/.codex/sessions`).
    case codex
    /// Claude Code (`~/.claude/projects/<project>/<session>.jsonl`).
    case claudeCode

    /// Codex opens with `session_meta`; Claude Code entries carry a `sessionId`.
    public static func of(_ url: URL) -> ConversationDialect {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .codex }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 16 * 1_024) else { return .codex }
        let head = String(decoding: data, as: UTF8.self)
        if head.contains(#""type":"session_meta""#) { return .codex }
        return head.contains(#""sessionId""#) ? .claudeCode : .codex
    }
}

/// One turn lifecycle record read from a log, with what its end reported.
struct TurnLogRecord: Sendable {
    let record: CodexLifecycleRecord
    var end: CodexTurnEnd? = nil
    var tests: TestOutcome? = nil
    var waitingForReply = false
}

/// Reads a conversation log line by line, in either dialect, into turn
/// lifecycle records. Message bodies are read transiently; only lifecycle,
/// the opening of a final reply, the test verdict and an open question remain.
struct ConversationLogReader: Sendable {
    let dialect: ConversationDialect
    private var codex = CodexTurnFacts()
    private(set) var claude: ClaudeCodeTurnReader

    init(dialect: ConversationDialect, resuming checkpoint: ClaudeCodeTurnReader.Checkpoint? = nil) {
        self.dialect = dialect
        claude = ClaudeCodeTurnReader(resuming: checkpoint)
    }

    private static let codexMarkers = CodexLifecycleRecord.CodexLifecycle.allCases.map { Data($0.rawValue.utf8) }

    mutating func read(_ line: Data) -> [TurnLogRecord] {
        switch dialect {
        case .claudeCode:
            return claude.read(line)
        case .codex:
            // Most lines are tool output; only a line naming a lifecycle is decoded as one.
            guard Self.codexMarkers.contains(where: { line.range(of: $0) != nil }),
                  let record = CodexLifecycleRecord(json: line) else {
                codex.consume(line)
                return []
            }
            switch record.lifecycle {
            case .started:
                codex.turnStarted()
                return [TurnLogRecord(record: record)]
            case .completed:
                let end = CodexTurnEnd(json: line)
                return [TurnLogRecord(record: record, end: end, tests: codex.tests(duration: end?.duration),
                                      waitingForReply: codex.isWaitingForReply(turnEnded: true))]
            case .aborted:
                return [TurnLogRecord(record: record)]
            }
        }
    }

    /// Records held back until the rest of a reply was read.
    mutating func flush() -> [TurnLogRecord] {
        dialect == .claudeCode ? claude.flush() : []
    }

    /// For a turn still running: its test results so far.
    var testsSoFar: TestOutcome? {
        dialect == .claudeCode ? claude.testsSoFar : codex.tests(duration: nil)
    }

    /// For a turn still running: a question that holds it until answered.
    var isHeldByQuestion: Bool {
        dialect == .claudeCode ? claude.isHeldByQuestion : codex.isWaitingForReply(turnEnded: false)
    }

    /// The conversation's own name, when the log records one.
    var title: String? { dialect == .claudeCode ? claude.title : nil }
}

/// Turns of a Claude Code session. A prompt the person typed opens a turn; the
/// assistant's `end_turn` or stop sequence completes it, an API error fails
/// it, and "[Request interrupted by user]" stops it. A message typed while a
/// turn runs joins it. Sub-agent (sidechain) entries are skipped.
struct ClaudeCodeTurnReader: Sendable {
    /// What a checkpoint keeps, so a resumed read still closes the open turn.
    struct Checkpoint: Codable, Hashable, Sendable {
        var turnID: String
        var startedAt: Date
    }

    private(set) var openTurn: Checkpoint?
    private(set) var title: String?
    private var sawTurnStart = false
    private var reply: String?
    private var testRuns = 0
    private var lastTestFailed: Bool?
    private var pendingTests: Set<String> = []
    private var pendingQuestions: Set<String> = []
    /// One reply is written as several entries (thinking, then text), each
    /// marked as ending the turn; the completion waits for the rest of it.
    private var heldCompletion: TurnLogRecord?
    private var endedMessageID: String?

    init(resuming checkpoint: Checkpoint? = nil) {
        openTurn = checkpoint
    }

    var testsSoFar: TestOutcome? { verdict(duration: nil) }
    var isHeldByQuestion: Bool { !pendingQuestions.isEmpty }

    mutating func read(_ line: Data) -> [TurnLogRecord] {
        let head = String(decoding: line.prefix(2_048), as: UTF8.self)
        let isUser = head.contains(#""type":"user""#)
        // Assistant entries put their message (which opens with its role) before their type.
        let isAssistant = head.contains(#""role":"assistant""#) || head.contains(#""type":"assistant""#)
        guard isUser || isAssistant || head.contains(#""type":"custom-title""#) else { return flush() }
        // A tool result matters only while a test or a question waits on it.
        if isUser, head.contains(#""tool_result""#), pendingTests.isEmpty, pendingQuestions.isEmpty { return flush() }
        guard let entry = try? JSONDecoder().decode(Entry.self, from: line), entry.isSidechain != true else { return [] }
        if entry.type == "assistant", let id = entry.message?.id, id == endedMessageID {
            // The rest of the reply that ended the turn: its text is the reply.
            if let text = entry.message?.blocks.last(where: { $0.type == "text" })?.text, var held = heldCompletion {
                reply = text
                if let end = held.end {
                    held.end = CodexTurnEnd(reply: text, hasError: end.hasError, errorMessage: end.errorMessage,
                                            duration: end.duration)
                }
                heldCompletion = held
            }
            return []
        }
        var records = flush()
        switch entry.type {
        case "custom-title":
            if let name = entry.customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { title = name }
        case "user":
            records += user(entry)
        case "assistant":
            records += assistant(entry)
        default:
            break
        }
        return records
    }

    mutating func flush() -> [TurnLogRecord] {
        guard let held = heldCompletion else { return [] }
        heldCompletion = nil
        return [held]
    }

    private mutating func user(_ entry: Entry) -> [TurnLogRecord] {
        let blocks = entry.message?.blocks ?? []
        let results = blocks.filter { $0.type == "tool_result" }
        if !results.isEmpty {
            for result in results {
                guard let id = result.toolUseID else { continue }
                if pendingTests.remove(id) != nil { lastTestFailed = result.isError == true }
                pendingQuestions.remove(id)
            }
            return []
        }
        let text = (entry.message?.text ?? blocks.filter { $0.type == "text" }.compactMap(\.text).joined(separator: "\n"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("[Request interrupted by user") {
            guard let turn = openTurn, let date = entry.date else { return [] }
            close()
            return [TurnLogRecord(record: CodexLifecycleRecord(timestamp: date, lifecycle: .aborted, turnID: turn.turnID))]
        }
        guard entry.isMeta != true, Self.isPrompt(text) else { return [] }
        // A message typed while a turn runs joins that turn; it may answer its question.
        guard openTurn == nil else {
            pendingQuestions.removeAll()
            return []
        }
        guard let date = entry.date else { return [] }
        return [open(id: entry.uuid ?? String(date.timeIntervalSince1970), at: date, fromStart: true)]
    }

    private mutating func assistant(_ entry: Entry) -> [TurnLogRecord] {
        guard let date = entry.date, let message = entry.message else { return [] }
        var records: [TurnLogRecord] = []
        // A read that began mid-turn opens it at the first reply it sees.
        if openTurn == nil { records.append(open(id: entry.uuid ?? String(date.timeIntervalSince1970), at: date, fromStart: false)) }
        for block in message.blocks {
            switch block.type {
            case "text":
                if let text = block.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { reply = text }
            case "tool_use":
                if block.name == "AskUserQuestion", let id = block.id {
                    pendingQuestions.insert(id)
                } else if block.name == "Bash", let command = block.input?.command, CodexTurnFacts.runsTests(command) {
                    testRuns += 1
                    if let id = block.id { pendingTests.insert(id) }
                }
            default:
                break
            }
        }
        guard let turn = openTurn else { return records }
        let failed = entry.isApiErrorMessage == true
        guard failed || message.stopReason == "end_turn" || message.stopReason == "stop_sequence" else { return records }
        let duration = sawTurnStart ? date.timeIntervalSince(turn.startedAt) : nil
        let end = failed
            ? CodexTurnEnd(reply: nil, hasError: true, errorMessage: message.blocks.compactMap(\.text).first ?? "API error",
                           duration: duration)
            : CodexTurnEnd(reply: reply, hasError: false, errorMessage: nil, duration: duration)
        heldCompletion = TurnLogRecord(record: CodexLifecycleRecord(timestamp: date, lifecycle: .completed, turnID: turn.turnID),
                                       end: end, tests: verdict(duration: duration), waitingForReply: false)
        endedMessageID = message.id
        close()
        return records
    }

    private mutating func open(id: String, at date: Date, fromStart: Bool) -> TurnLogRecord {
        openTurn = Checkpoint(turnID: id, startedAt: date)
        sawTurnStart = fromStart
        reply = nil
        testRuns = 0
        lastTestFailed = nil
        pendingTests = []
        endedMessageID = nil
        return TurnLogRecord(record: CodexLifecycleRecord(timestamp: date, lifecycle: .started, turnID: id))
    }

    private mutating func close() {
        openTurn = nil
        pendingQuestions = []
    }

    private func verdict(duration: TimeInterval?) -> TestOutcome? {
        if testRuns > 0 {
            guard let lastTestFailed else { return .ran }
            return lastTestFailed ? .failed : .passed
        }
        guard sawTurnStart, let duration, duration >= CodexTurnFacts.longTurn else { return nil }
        return .notRun
    }

    /// Words the person typed, not command output or attached context.
    static func isPrompt(_ text: String) -> Bool {
        guard !text.hasPrefix("<command-"), !text.hasPrefix("<local-command"), !text.hasPrefix("Caveat:") else { return false }
        return CodexAutoAssociation.userWords(in: text) != nil
    }

    struct Entry: Decodable {
        let type: String?
        let uuid: String?
        let timestamp: String?
        let isSidechain: Bool?
        let isMeta: Bool?
        let isApiErrorMessage: Bool?
        let customTitle: String?
        let message: Message?

        var date: Date? {
            timestamp.flatMap { try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse($0) }
                ?? timestamp.flatMap { try? Date.ISO8601FormatStyle().parse($0) }
        }
    }

    struct Message: Decodable {
        let id: String?
        let stopReason: String?
        /// A typed prompt is a plain string; everything else is a list of blocks.
        let text: String?
        let blocks: [Block]

        enum CodingKeys: String, CodingKey {
            case id, content
            case stopReason = "stop_reason"
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try? values.decodeIfPresent(String.self, forKey: .id)
            stopReason = try? values.decodeIfPresent(String.self, forKey: .stopReason)
            text = try? values.decodeIfPresent(String.self, forKey: .content)
            blocks = (try? values.decodeIfPresent([Block].self, forKey: .content)) ?? []
        }
    }

    struct Block: Decodable {
        let type: String?
        let text: String?
        let id: String?
        let name: String?
        let toolUseID: String?
        let isError: Bool?
        let input: Input?

        enum CodingKeys: String, CodingKey {
            case type, text, id, name, input
            case toolUseID = "tool_use_id"
            case isError = "is_error"
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            type = try? values.decodeIfPresent(String.self, forKey: .type)
            text = try? values.decodeIfPresent(String.self, forKey: .text)
            id = try? values.decodeIfPresent(String.self, forKey: .id)
            name = try? values.decodeIfPresent(String.self, forKey: .name)
            toolUseID = try? values.decodeIfPresent(String.self, forKey: .toolUseID)
            isError = try? values.decodeIfPresent(Bool.self, forKey: .isError)
            input = try? values.decodeIfPresent(Input.self, forKey: .input)
        }
    }

    struct Input: Decodable {
        let command: String?
    }
}
