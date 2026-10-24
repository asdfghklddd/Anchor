import Foundation
import Testing
@testable import AnchorCore

/// Claude Code session lines: one entry per line, one entry per content block.
enum ClaudeLine {
    /// Real key order: a user entry names its type before its message, an
    /// assistant entry after it, so a long reply pushes "type" far into the line.
    static func base(_ type: String, uuid: String, at time: String, sidechain: Bool = false, extra: String = "") -> String {
        let prefix = #"{"parentUuid":null,"isSidechain":\#(sidechain),"userType":"external","cwd":"/Users/example/Website","sessionId":"s-1","version":"2.1.0","gitBranch":"main""#
        let suffix = #","uuid":"\#(uuid)","timestamp":"2026-10-16T\#(time)Z"}"#
        return type == "assistant"
            ? prefix + extra + #","type":"assistant""# + suffix
            : prefix + #","type":"\#(type)""# + extra + suffix
    }
    static let title = #"{"type":"custom-title","customTitle":"Deploy retries","sessionId":"s-1"}"#
    static let queued = #"{"type":"queue-operation","operation":"enqueue","timestamp":"2026-10-16T08:00:00.000Z","sessionId":"s-1"}"#
    static func prompt(_ text: String, uuid: String = "u-1", at time: String = "08:00:01.000", meta: Bool = false) -> String {
        base("user", uuid: uuid, at: time, extra: #","message":{"role":"user","content":"\#(text)"}\#(meta ? #","isMeta":true"# : "")"#)
    }
    static func bash(_ command: String, id: String, at time: String = "08:01:00.000") -> String {
        base("assistant", uuid: "a-\(id)", at: time, extra: #","message":{"id":"msg-\#(id)","role":"assistant","content":[{"type":"tool_use","id":"\#(id)","name":"Bash","input":{"command":"\#(command)"}}],"stop_reason":"tool_use"}"#)
    }
    static func ask(id: String, at time: String = "08:02:00.000") -> String {
        base("assistant", uuid: "a-\(id)", at: time, extra: #","message":{"id":"msg-\#(id)","role":"assistant","content":[{"type":"tool_use","id":"\#(id)","name":"AskUserQuestion","input":{"questions":[]}}],"stop_reason":"tool_use"}"#)
    }
    static func result(_ id: String, error: Bool, at time: String = "08:03:00.000") -> String {
        base("user", uuid: "r-\(id)", at: time, extra: #","message":{"role":"user","content":[{"tool_use_id":"\#(id)","type":"tool_result","content":"done","is_error":\#(error)}]}"#)
    }
    static func thinkingEnd(_ message: String, at time: String) -> String {
        base("assistant", uuid: "t-\(message)", at: time, extra: #","message":{"id":"\#(message)","role":"assistant","content":[{"type":"thinking","thinking":"…"}],"stop_reason":"end_turn"}"#)
    }
    static func textEnd(_ message: String, _ text: String, at time: String, sidechain: Bool = false) -> String {
        base("assistant", uuid: "x-\(message)", at: time, sidechain: sidechain, extra: #","message":{"id":"\#(message)","role":"assistant","content":[{"type":"text","text":"\#(text)"}],"stop_reason":"end_turn"}"#)
    }
    static let interrupted = base("user", uuid: "u-stop", at: "08:04:00.000", extra: #","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}"#)
}

private func claudeScan(_ lines: [String], scanner: inout CodexIncrementalScanner) -> [CodexLifecycleScannedRecord] {
    scanner.appendWithOffsets(Data((lines.joined(separator: "\n") + "\n").utf8))
}

@Suite("Claude Code logs")
struct ClaudeCodeLogTests {
    @Test("A typed prompt opens a turn; a reply written in two entries ends it once, with its text")
    func turnFromPromptToReply() {
        var scanner = CodexIncrementalScanner(dialect: .claudeCode)
        let records = claudeScan([
            ClaudeLine.queued, ClaudeLine.title,
            ClaudeLine.prompt("Caveat: local command output", uuid: "u-0", meta: true),
            ClaudeLine.prompt("Make the deploy script retry"),
            ClaudeLine.bash("npm test", id: "toolu-1"), ClaudeLine.result("toolu-1", error: false),
            ClaudeLine.thinkingEnd("msg-end", at: "08:05:00.000"),
            ClaudeLine.textEnd("msg-end", "Deploy now retries three times; tests pass. " + String(repeating: "Details follow. ", count: 200),
                               at: "08:05:00.100"),
        ], scanner: &scanner)

        #expect(records.map(\.record.lifecycle) == [.started, .completed])
        #expect(Set(records.map(\.record.turnID)) == ["u-1"])
        let end = records.last
        #expect(end?.end?.reply?.hasPrefix("Deploy now retries three times; tests pass.") == true)
        #expect(end?.end?.duration == 299)
        #expect(end?.tests == .passed)
    }

    @Test("A message typed mid-turn joins it; a stop ends it; sub-agent entries never count")
    func midTurnStopAndSidechain() {
        var scanner = CodexIncrementalScanner(dialect: .claudeCode)
        let records = claudeScan([
            ClaudeLine.prompt("Fix the flaky test"),
            ClaudeLine.prompt("also check the README", uuid: "u-2", at: "08:01:30.000"),
            ClaudeLine.textEnd("msg-side", "Sub-agent done.", at: "08:02:00.000", sidechain: true),
            ClaudeLine.bash("swift test", id: "toolu-2"), ClaudeLine.result("toolu-2", error: true),
            ClaudeLine.interrupted,
        ], scanner: &scanner)
        #expect(records.map(\.record.lifecycle) == [.started, .aborted])
        #expect(records.map(\.record.turnID) == ["u-1", "u-1"])
    }

    @Test("A turn that resumes after a relaunch still ends the turn it began")
    func checkpointKeepsTheOpenTurn() throws {
        var scanner = CodexIncrementalScanner(dialect: .claudeCode)
        _ = claudeScan([ClaudeLine.prompt("Make the deploy script retry")], scanner: &scanner)
        var resumed = try CodexIncrementalScanner(checkpoint: scanner.checkpoint())
        #expect(resumed.dialect == .claudeCode)
        let records = claudeScan([ClaudeLine.textEnd("msg-9", "Done.", at: "08:09:00.000")], scanner: &resumed)
        #expect(records.map(\.record.lifecycle) == [.completed])
        #expect(records.first?.record.turnID == "u-1")
        // Codex checkpoints keep their old shape, plus the counted working time.
        let codex = try JSONSerialization.jsonObject(with: CodexIncrementalScanner().checkpoint()) as? [String: Any]
        #expect(codex?.keys.sorted() == ["offset", "version", "work"])
    }

    @Test("A question to the person holds the turn until its answer")
    func askUserQuestion() {
        var reader = ClaudeCodeTurnReader()
        _ = reader.read(Data(ClaudeLine.prompt("Set up the database").utf8))
        _ = reader.read(Data(ClaudeLine.ask(id: "toolu-q").utf8))
        #expect(reader.isHeldByQuestion)
        _ = reader.read(Data(ClaudeLine.result("toolu-q", error: false).utf8))
        #expect(!reader.isHeldByQuestion)
    }

    @Test("A Claude Code session reads as a conversation: its name, folder, last reply and source")
    func summaryAndMetadata() async throws {
        let root = URL.temporaryDirectory.appending(path: "claude-projects-\(UUID())")
        let project = root.appending(path: "-Users-example-Website")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = project.appending(path: "s-1.jsonl")
        try Data(([ClaudeLine.queued, ClaudeLine.title, ClaudeLine.prompt("Make the deploy script retry"),
                   ClaudeLine.thinkingEnd("msg-end", at: "08:05:00.000"),
                   ClaudeLine.textEnd("msg-end", "Deploy now retries.", at: "08:05:00.100")]
            .joined(separator: "\n") + "\n").utf8).write(to: file)
        // A sub-agent log beside it is machine work.
        let agents = project.appending(path: "s-1/subagents")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try Data((ClaudeLine.prompt("Search the repo") + "\n").utf8).write(to: agents.appending(path: "agent-1.jsonl"))

        #expect(ConversationDialect.of(file) == .claudeCode)
        let metadata = try #require(CodexSessionMetadata.read(from: file))
        #expect(metadata.id == "s-1")
        #expect(metadata.workspaceName == "Website")
        #expect(metadata.sourceName == "Claude Code")
        #expect(CodexSessionMetadata.read(from: agents.appending(path: "agent-1.jsonl"))?.isUserConversation == false)
        #expect(CodexAutoAssociation.latestUserRequest(at: file) == "Make the deploy script retry")

        let summaries = await CodexTaskSupervisor(rootURL: root, dialect: .claudeCode).summaries()
        #expect(summaries.count == 1)
        let summary = try #require(summaries.first)
        #expect(summary.title == "Deploy retries")
        #expect(summary.reply == "Deploy now retries.")
        #expect(summary.state == .completed(at: try Date("2026-10-16T08:05:00.000Z", strategy: .iso8601), duration: 299))
        #expect(summary.candidate.originator == "Claude Code")
    }
}
