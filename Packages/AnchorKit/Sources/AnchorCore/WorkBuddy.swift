import Foundation

/// How WorkBuddy's conversation logs read
/// (`~/.workbuddy/projects/<project>/<session>.jsonl`). Lines are items of a
/// model's input and output: `message`, `function_call`, `function_call_result`
/// and `reasoning`, stamped in milliseconds. Each request wraps the person's
/// words in the setup context it sends the model.
public enum WorkBuddyLog {
    public static let originator = "WorkBuddy"
    /// The logs' folder, under the person's home.
    public static let rootPath = ".workbuddy/projects"

    private static let headMarker = Data(#""type":"session-meta""#.utf8)
    private static let questionTools: Set<String> = [
        "AskUserQuestion", "AskFollowupQuestion", "ask_user_question", "ask_followup_question",
    ]
    private static let interruptionText = "Interrupted by user"

    static func isLog(head: Data) -> Bool { head.range(of: headMarker) != nil }
    static func isQuestion(tool: String) -> Bool { questionTools.contains(tool) }

    static func date(of object: [String: Any]) -> Date? {
        (object["timestamp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1_000) }
    }

    static func providerData(of object: [String: Any]) -> [String: Any] {
        object["providerData"] as? [String: Any] ?? [:]
    }

    /// The text of a message's blocks of one type; a plain string counts too.
    private static func text(of object: [String: Any], blocks type: String) -> String {
        if let plain = object["content"] as? String { return plain }
        return (object["content"] as? [[String: Any]])?
            .filter { $0["type"] as? String == type }.compactMap { $0["text"] as? String }
            .joined(separator: "\n") ?? ""
    }

    private static func isUserMessage(_ object: [String: Any]) -> Bool {
        object["type"] as? String == "message" && object["role"] as? String == "user"
    }

    private static func isAssistantMessage(_ object: [String: Any]) -> Bool {
        object["type"] as? String == "message" && object["role"] as? String == "assistant"
    }

    /// Compaction and attached data are the app talking to the model, not the person.
    private static func isFromApp(_ data: [String: Any]) -> Bool {
        data["agent"] as? String == "compact" || data["isAdditionalData"] as? Bool == true
    }

    /// A request that begins a turn. A message typed while a turn runs says
    /// `startsNewUserRequest: false` and joins that turn.
    static func opensTurn(_ object: [String: Any]) -> Bool {
        guard isUserMessage(object) else { return false }
        let data = providerData(of: object)
        guard !isFromApp(data) else { return false }
        return data["startsNewUserRequest"] as? Bool ?? (data["isMeta"] as? Bool != true)
    }

    /// The words of a message the person typed, whether or not it began a turn.
    public static func request(in object: [String: Any]) -> String? {
        guard isUserMessage(object) else { return nil }
        let data = providerData(of: object)
        guard !isFromApp(data), opensTurn(object) || data["isMeta"] as? Bool != true else { return nil }
        return userWords(in: text(of: object, blocks: "input_text"))
    }

    /// What the agent said in a reply, when it said something.
    static func reply(in object: [String: Any]) -> String? {
        guard isAssistantMessage(object), !isInterruption(object) else { return nil }
        let reply = text(of: object, blocks: "output_text").trimmingCharacters(in: .whitespacesAndNewlines)
        return reply.isEmpty ? nil : reply
    }

    /// The person stopped the turn before it ended.
    static func isInterruption(_ object: [String: Any]) -> Bool {
        guard isAssistantMessage(object), object["status"] as? String == "incomplete" else { return false }
        return text(of: object, blocks: "output_text").hasPrefix(interruptionText)
            || failure(in: object)?.localizedCaseInsensitiveContains("aborted") == true
    }

    /// Why an unfinished reply stopped.
    static func failure(in object: [String: Any]) -> String? {
        let error = providerData(of: object)["error"] as? [String: Any]
        return (error?["message"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// A reply that ends its turn. The usage of a model step sits on the step's
    /// last item, so a reply carrying it was not followed by a tool call.
    static func endsTurn(_ object: [String: Any]) -> Bool {
        guard isAssistantMessage(object) else { return false }
        let data = providerData(of: object)
        return data["usage"] != nil || data["terminalStopReason"] as? String == "end_turn"
    }

    /// The person's words: WorkBuddy puts them in `<user_query>`, after the context.
    static func userWords(in text: String) -> String? {
        guard let open = text.range(of: "<user_query>"),
              let close = text.range(of: "</user_query>", options: .backwards),
              open.upperBound <= close.lowerBound else {
            return CodexAutoAssociation.userWords(in: text)
        }
        let words = text[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return words.isEmpty ? nil : words
    }

    /// The folder's name, except for the one WorkBuddy makes for a chat without
    /// a project (`~/WorkBuddy/2026-11-05-06-26-01`), which names nothing.
    static func workspaceName(cwd: String) -> String? {
        let folder = URL(filePath: cwd, directoryHint: .isDirectory)
        let name = folder.lastPathComponent
        let isChatFolder = folder.deletingLastPathComponent().lastPathComponent == "WorkBuddy"
            && name.wholeMatch(of: /\d{4}(-\d{2}){5}/) != nil
        return isChatFolder ? nil : name
    }

    /// The command of a shell call, or the file of a writing one.
    static func arguments(of object: [String: Any]) -> [String: Any] {
        guard let text = object["arguments"] as? String,
              let parsed = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return [:] }
        return parsed
    }

    /// Whether a shell call failed. The call itself reads as completed however
    /// the command ended; its output closes with the exit code.
    static func failed(result object: [String: Any]) -> Bool {
        if object["status"] as? String != "completed" { return true }
        let output = (object["output"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined()
            ?? object["output"] as? String ?? ""
        guard let code = output.matches(of: /Exit Code: ([^\s\\]+)/).last?.1 else { return false }
        return code != "0"
    }

    /// The fresh tokens of one model step: its input already counts cached reads.
    static func tokens(in object: [String: Any]) -> Int {
        guard let usage = (object["message"] as? [String: Any])?["usage"] as? [String: Any] else { return 0 }
        func int(_ key: String) -> Int { (usage[key] as? NSNumber)?.intValue ?? 0 }
        return max(0, int("input_tokens") - int("cache_read_input_tokens")) + int("output_tokens")
    }
}

/// Turns of a WorkBuddy session. A request opens a turn; a reply that ends its
/// model step without a tool call completes it, an unfinished reply stops or
/// fails it. A request arriving while a turn is open means that turn was
/// stopped without saying so.
struct WorkBuddyTurnReader: Sendable {
    private(set) var openTurn: ClaudeCodeTurnReader.Checkpoint?
    private var aiTitle: String?
    private var customTitle: String?
    private var sawTurnStart = false
    private var reply: String?
    private var testRuns = 0
    private var lastTestFailed: Bool?
    private var pendingTests: Set<String> = []
    private var pendingQuestions: Set<String> = []

    init(resuming checkpoint: ClaudeCodeTurnReader.Checkpoint? = nil) {
        openTurn = checkpoint
    }

    var title: String? { customTitle ?? aiTitle }
    var testsSoFar: TestOutcome? { verdict(duration: nil) }
    var isHeldByQuestion: Bool { !pendingQuestions.isEmpty }

    private static let markers = [#""type":"message""#, #""type":"function_call""#, #""type":"ai-title""#,
                                  #""type":"custom-title""#].map { Data($0.utf8) }
    private static let resultMarker = Data(#""type":"function_call_result""#.utf8)

    mutating func read(_ line: Data) -> [TurnLogRecord] {
        let head = line.prefix(2_048)
        let isResult = head.range(of: Self.resultMarker) != nil
        // Most lines are tool output; a result matters only while a test or a question waits on it.
        if isResult ? pendingTests.isEmpty && pendingQuestions.isEmpty
                    : !Self.markers.contains(where: { head.range(of: $0) != nil }) { return [] }
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return [] }
        switch object["type"] as? String {
        case "ai-title":
            aiTitle = trimmed(object["aiTitle"])
        case "custom-title":
            customTitle = trimmed(object["customTitle"])
        case "function_call_result":
            guard let id = object["callId"] as? String else { break }
            if pendingTests.remove(id) != nil { lastTestFailed = WorkBuddyLog.failed(result: object) }
            pendingQuestions.remove(id)
        case "function_call":
            return functionCall(object)
        case "message":
            return object["role"] as? String == "user" ? user(object) : assistant(object)
        default:
            break
        }
        return []
    }

    private func trimmed(_ value: Any?) -> String? {
        (value as? String).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    private mutating func user(_ object: [String: Any]) -> [TurnLogRecord] {
        guard WorkBuddyLog.opensTurn(object) else {
            // A message typed while a turn runs joins that turn; it may answer its question.
            if WorkBuddyLog.request(in: object) != nil { pendingQuestions.removeAll() }
            return []
        }
        guard let date = WorkBuddyLog.date(of: object) else { return [] }
        var records: [TurnLogRecord] = []
        if let turn = openTurn {
            close()
            records.append(TurnLogRecord(record: CodexLifecycleRecord(timestamp: date, lifecycle: .aborted, turnID: turn.turnID)))
        }
        records.append(open(id: turnID(of: object, at: date), at: date, fromStart: true))
        return records
    }

    private mutating func functionCall(_ object: [String: Any]) -> [TurnLogRecord] {
        guard let date = WorkBuddyLog.date(of: object) else { return [] }
        // A read that began mid-turn opens it at the first item it sees.
        let records = openTurn == nil ? [open(id: turnID(of: object, at: date), at: date, fromStart: false)] : []
        guard let name = object["name"] as? String, let id = object["callId"] as? String else { return records }
        if WorkBuddyLog.isQuestion(tool: name) {
            pendingQuestions.insert(id)
        } else if name == "Bash", let command = WorkBuddyLog.arguments(of: object)["command"] as? String,
                  CodexTurnFacts.runsTests(command) {
            testRuns += 1
            pendingTests.insert(id)
        }
        return records
    }

    private mutating func assistant(_ object: [String: Any]) -> [TurnLogRecord] {
        guard let date = WorkBuddyLog.date(of: object) else { return [] }
        var records = openTurn == nil ? [open(id: turnID(of: object, at: date), at: date, fromStart: false)] : []
        if let text = WorkBuddyLog.reply(in: object) { reply = text }
        guard let turn = openTurn else { return records }
        let duration = sawTurnStart ? date.timeIntervalSince(turn.startedAt) : nil
        if WorkBuddyLog.isInterruption(object) {
            close()
            records.append(TurnLogRecord(record: CodexLifecycleRecord(timestamp: date, lifecycle: .aborted, turnID: turn.turnID)))
        } else if object["status"] as? String == "incomplete" {
            let message = WorkBuddyLog.failure(in: object) ?? reply ?? "WorkBuddy stopped"
            records.append(end(turn, at: date, CodexTurnEnd(reply: nil, hasError: true, errorMessage: message, duration: duration),
                               tests: verdict(duration: duration)))
        } else if WorkBuddyLog.endsTurn(object) {
            records.append(end(turn, at: date, CodexTurnEnd(reply: reply, hasError: false, errorMessage: nil, duration: duration),
                               tests: verdict(duration: duration)))
        }
        return records
    }

    private mutating func end(_ turn: ClaudeCodeTurnReader.Checkpoint, at date: Date, _ end: CodexTurnEnd,
                              tests: TestOutcome?) -> TurnLogRecord {
        close()
        return TurnLogRecord(record: CodexLifecycleRecord(timestamp: date, lifecycle: .completed, turnID: turn.turnID),
                             end: end, tests: tests, waitingForReply: false)
    }

    /// A request and everything answering it share one ID.
    private func turnID(of object: [String: Any], at date: Date) -> String {
        WorkBuddyLog.providerData(of: object)["conversationRequestId"] as? String
            ?? object["id"] as? String ?? String(date.timeIntervalSince1970)
    }

    private mutating func open(id: String, at date: Date, fromStart: Bool) -> TurnLogRecord {
        openTurn = ClaudeCodeTurnReader.Checkpoint(turnID: id, startedAt: date)
        sawTurnStart = fromStart
        reply = nil
        testRuns = 0
        lastTestFailed = nil
        pendingTests = []
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
}
