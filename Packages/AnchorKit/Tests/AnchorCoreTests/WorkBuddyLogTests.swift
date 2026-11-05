import Foundation
import Testing
@testable import AnchorCore

/// WorkBuddy session lines, in the real key order: `id`, `timestamp`, then `type`.
enum WorkBuddyLine {
    static let start = 1_793_889_000_000
    static let meta = #"{"type":"session-meta","id":"m-1","sessionId":"wb-1","timestamp":\#(start),"meta":{"codebuddy.ai/hostKind":"unopted"}}"#
    static let usage = #""rawUsage":{"prompt_tokens":1000,"completion_tokens":50},"usage":{"requests":1,"inputTokens":1000,"outputTokens":50}"#
    static let messageUsage = #""message":{"usage":{"input_tokens":1000,"output_tokens":50,"total_tokens":1050,"cache_read_input_tokens":900}}"#

    static func title(_ text: String, at seconds: Int = 2) -> String {
        #"{"id":"t-1","timestamp":\#(start + seconds * 1_000),"type":"ai-title","aiTitle":"\#(text)","sessionId":"wb-1","cwd":"/Users/example/Website"}"#
    }
    static let rename = #"{"type":"custom-title","customTitle":"My own name","sessionId":"wb-1"}"#

    static func prompt(_ text: String, request: String = "r-1", at seconds: Int = 0, starts: Bool = true,
                       cwd: String = "/Users/example/Website") -> String {
        let context = "<user_info>Mac</user_info>\\n<project_context>a long setup</project_context>\\n"
        return #"{"id":"u-\#(request)","timestamp":\#(start + seconds * 1_000),"type":"message","role":"user","content":[{"type":"input_text","text":"\#(context)<user_query>\#(text)</user_query>"}],"providerData":{"startsNewUserRequest":\#(starts),"agent":"cli","conversationRequestId":"\#(request)"},"sessionId":"wb-1","cwd":"\#(cwd)"}"#
    }
    static func reasoning(at seconds: Int) -> String {
        #"{"id":"re-\#(seconds)","timestamp":\#(start + seconds * 1_000),"type":"reasoning","providerData":{"conversationRequestId":"r-1"},"content":[],"rawContent":[{"type":"reasoning_text","text":"thinking"}],"sessionId":"wb-1"}"#
    }
    /// A reply: the last item of its model step carries the step's usage.
    static func reply(_ text: String, request: String = "r-1", at seconds: Int, last: Bool) -> String {
        let usageField = last ? "," + usage : ""
        let messageField = last ? "," + messageUsage : ""
        return #"{"id":"a-\#(seconds)","timestamp":\#(start + seconds * 1_000),"type":"message","role":"assistant","providerData":{"conversationRequestId":"\#(request)","stepSeq":1\#(usageField)},"status":"completed","content":[{"type":"output_text","text":"\#(text)"}],"sessionId":"wb-1"\#(messageField)}"#
    }
    static func unfinished(_ text: String, error: String?, at seconds: Int) -> String {
        let errorField = error.map { #","error":{"message":"\#($0)"}"# } ?? ""
        return #"{"id":"a-\#(seconds)","timestamp":\#(start + seconds * 1_000),"type":"message","role":"assistant","status":"incomplete","content":[{"type":"output_text","text":"\#(text)"}],"providerData":{"skipRun":true\#(errorField)},"sessionId":"wb-1"}"#
    }
    static func call(_ name: String, id: String, arguments: String, at seconds: Int, last: Bool = true) -> String {
        let usageField = last ? "," + usage : ""
        let messageField = last ? "," + messageUsage : ""
        let escaped = arguments.replacingOccurrences(of: #"""#, with: #"\""#)
        return #"{"id":"c-\#(id)","timestamp":\#(start + seconds * 1_000),"type":"function_call","providerData":{"conversationRequestId":"r-1"\#(usageField)},"callId":"\#(id)","name":"\#(name)","arguments":"\#(escaped)","sessionId":"wb-1"\#(messageField)}"#
    }
    static func result(_ name: String, id: String, output: String = "ok", status: String = "completed", at seconds: Int) -> String {
        #"{"id":"cr-\#(id)","timestamp":\#(start + seconds * 1_000),"type":"function_call_result","name":"\#(name)","callId":"\#(id)","status":"\#(status)","output":[{"type":"input_text","text":"\#(output)"}],"sessionId":"wb-1"}"#
    }
    static func at(_ seconds: Int) -> Date { Date(timeIntervalSince1970: Double(start + seconds * 1_000) / 1_000) }

    static func file(_ lines: [String]) -> Data { Data((lines.joined(separator: "\n") + "\n").utf8) }
}

private func scan(_ lines: [String], scanner: inout CodexIncrementalScanner) -> [CodexLifecycleScannedRecord] {
    scanner.appendWithOffsets(WorkBuddyLine.file(lines))
}

@Suite("WorkBuddy logs")
struct WorkBuddyLogTests {
    @Test("A request opens a turn; a reply before a tool call does not end it; the step's last reply does")
    func turnFromRequestToReply() {
        var scanner = CodexIncrementalScanner(dialect: .workBuddy)
        let records = scan([
            WorkBuddyLine.meta, WorkBuddyLine.prompt("Make the deploy script retry"), WorkBuddyLine.title("Deploy retries"),
            WorkBuddyLine.reasoning(at: 5), WorkBuddyLine.reply("Let me look.", at: 5, last: false),
            WorkBuddyLine.call("Bash", id: "c1", arguments: #"{"command":"ls"}"#, at: 6),
            WorkBuddyLine.result("Bash", id: "c1", at: 7),
            WorkBuddyLine.reply("Deploy now retries three times.", at: 300, last: true),
        ], scanner: &scanner)

        #expect(records.map(\.record.lifecycle) == [.started, .completed])
        #expect(Set(records.map(\.record.turnID)) == ["r-1"])
        #expect(records.last?.end?.reply == "Deploy now retries three times.")
        #expect(records.last?.end?.duration == 300)
        #expect(records.last?.end?.hasError == false)
    }

    @Test("A step that ends in a tool call leaves the turn running")
    func toolCallKeepsTheTurnOpen() {
        var scanner = CodexIncrementalScanner(dialect: .workBuddy)
        let records = scan([
            WorkBuddyLine.prompt("Fix it"), WorkBuddyLine.reply("Working.", at: 5, last: false),
            WorkBuddyLine.call("Read", id: "c1", arguments: #"{"file_path":"/a"}"#, at: 5),
        ], scanner: &scanner)
        #expect(records.map(\.record.lifecycle) == [.started])
    }

    @Test("A message typed mid-turn joins it; a stop ends it; an error fails it")
    func joinsStopsAndFails() {
        var scanner = CodexIncrementalScanner(dialect: .workBuddy)
        let stopped = scan([
            WorkBuddyLine.prompt("Fix the flaky test"),
            WorkBuddyLine.prompt("also the README", request: "r-1", at: 3, starts: false),
            WorkBuddyLine.unfinished("Interrupted by user", error: nil, at: 9),
        ], scanner: &scanner)
        #expect(stopped.map(\.record.lifecycle) == [.started, .aborted])
        #expect(stopped.map(\.record.turnID) == ["r-1", "r-1"])

        var other = CodexIncrementalScanner(dialect: .workBuddy)
        let failed = scan([
            WorkBuddyLine.prompt("Fix it"),
            WorkBuddyLine.unfinished("Something went wrong", error: "Quota exceeded", at: 9),
        ], scanner: &other)
        #expect(failed.map(\.record.lifecycle) == [.started, .completed])
        #expect(failed.last?.end?.hasError == true)
        #expect(failed.last?.end?.errorMessage == "Quota exceeded")
    }

    @Test("A new request while a turn is open closes the one that stopped without saying so")
    func newRequestClosesTheOldTurn() {
        var scanner = CodexIncrementalScanner(dialect: .workBuddy)
        let records = scan([
            WorkBuddyLine.prompt("First"),
            WorkBuddyLine.call("Bash", id: "c1", arguments: #"{"command":"sleep 100"}"#, at: 4),
            WorkBuddyLine.prompt("Second", request: "r-2", at: 20),
        ], scanner: &scanner)
        #expect(records.map(\.record.lifecycle) == [.started, .aborted, .started])
        #expect(records.map(\.record.turnID) == ["r-1", "r-1", "r-2"])
    }

    @Test("A turn that resumes after a relaunch still ends the turn it began")
    func checkpointKeepsTheOpenTurn() throws {
        var scanner = CodexIncrementalScanner(dialect: .workBuddy)
        _ = scan([WorkBuddyLine.prompt("Make the deploy script retry")], scanner: &scanner)
        var resumed = try CodexIncrementalScanner(checkpoint: scanner.checkpoint())
        #expect(resumed.dialect == .workBuddy)
        let records = scan([WorkBuddyLine.reply("Done.", at: 60, last: true)], scanner: &resumed)
        #expect(records.map(\.record.lifecycle) == [.completed])
        #expect(records.first?.record.turnID == "r-1")
    }

    @Test("A question to the person holds the turn until its answer")
    func question() {
        var reader = WorkBuddyTurnReader()
        _ = reader.read(Data(WorkBuddyLine.prompt("Set up the database").utf8))
        _ = reader.read(Data(WorkBuddyLine.call("AskUserQuestion", id: "q1", arguments: #"{"questions":[]}"#, at: 5).utf8))
        #expect(reader.isHeldByQuestion)
        _ = reader.read(Data(WorkBuddyLine.result("AskUserQuestion", id: "q1", at: 9).utf8))
        #expect(!reader.isHeldByQuestion)
    }

    @Test("A test run's verdict comes from its exit code, since the call reads as completed either way")
    func testVerdict() {
        func verdict(_ output: String) -> TestOutcome? {
            var scanner = CodexIncrementalScanner(dialect: .workBuddy)
            return scan([
                WorkBuddyLine.prompt("Run the tests"),
                WorkBuddyLine.call("Bash", id: "c1", arguments: #"{"command":"swift test"}"#, at: 5),
                WorkBuddyLine.result("Bash", id: "c1", output: output, at: 9),
                WorkBuddyLine.reply("Done.", at: 10, last: true),
            ], scanner: &scanner).last?.tests
        }
        #expect(verdict(#"Output: all good\\nExit Code: 0\\nSignal: (none)"#) == .passed)
        #expect(verdict(#"Output: Exit Code: 0 in a log\\nExit Code: 1\\nSignal: (none)"#) == .failed)
        #expect(verdict(#"Output: killed\\nExit Code: (none)\\nSignal: 9"#) == .failed)
    }

    @Test("A session reads as a conversation: its name, last reply and source, without its setup text")
    func summaryAndMetadata() async throws {
        let root = URL.temporaryDirectory.appending(path: "workbuddy-projects-\(UUID())")
        let project = root.appending(path: "Users-example-Website")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = project.appending(path: "wb-1.jsonl")
        try WorkBuddyLine.file([
            WorkBuddyLine.meta, WorkBuddyLine.prompt("Make the deploy script retry"), WorkBuddyLine.title("Deploy retries"),
            WorkBuddyLine.reply("Deploy now retries.", at: 299, last: true),
        ]).write(to: file)
        // A sub-agent log beside it is machine work.
        let agents = project.appending(path: "wb-1/subagents")
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try WorkBuddyLine.file([WorkBuddyLine.meta, WorkBuddyLine.prompt("Search the repo")])
            .write(to: agents.appending(path: "agent-1.jsonl"))

        #expect(ConversationDialect.of(file) == .workBuddy)
        let metadata = try #require(CodexSessionMetadata.read(from: file))
        #expect(metadata.id == "wb-1")
        #expect(metadata.workspaceName == "Website")
        #expect(metadata.sourceName == "WorkBuddy")
        #expect(metadata.createdAt == WorkBuddyLine.at(0))
        #expect(CodexSessionMetadata.read(from: agents.appending(path: "agent-1.jsonl"))?.isUserConversation == false)
        #expect(CodexAutoAssociation.latestUserRequest(at: file) == "Make the deploy script retry")
        #expect(CodexAutoAssociation.firstUserRequest(at: file) == "Make the deploy script retry")
        #expect(ConversationLink(logAt: file)?.url.absoluteString == "workbuddy://chat/wb-1")

        let summaries = await CodexTaskSupervisor(rootURL: root, dialect: .workBuddy).summaries()
        #expect(summaries.count == 1)
        let summary = try #require(summaries.first)
        #expect(summary.title == "Deploy retries")
        #expect(summary.reply == "Deploy now retries.")
        #expect(summary.state == .completed(at: WorkBuddyLine.at(299), duration: 299))
        #expect(summary.candidate.originator == "WorkBuddy")
    }

    @Test("The person's own name for a conversation beats the generated one")
    func renamed() {
        var reader = WorkBuddyTurnReader()
        _ = reader.read(Data(WorkBuddyLine.title("Deploy retries").utf8))
        #expect(reader.title == "Deploy retries")
        _ = reader.read(Data(WorkBuddyLine.rename.utf8))
        _ = reader.read(Data(WorkBuddyLine.title("Later guess").utf8))
        #expect(reader.title == "My own name")
    }

    @Test("A chat without a project has no workspace name; a real folder does")
    func workspaceNames() {
        #expect(WorkBuddyLog.workspaceName(cwd: "/Users/example/WorkBuddy/2026-11-05-06-26-01") == nil)
        #expect(WorkBuddyLog.workspaceName(cwd: "/Users/example/WorkBuddy/Notes") == "Notes")
        #expect(WorkBuddyLog.workspaceName(cwd: "/Users/example/Website") == "Website")
    }

    @Test("A prompt's words are what the person typed, wrapped context or not")
    func userWords() {
        #expect(WorkBuddyLog.userWords(in: "<user_info>Mac</user_info>\n<user_query>\nHello\n</user_query>") == "Hello")
        #expect(WorkBuddyLog.userWords(in: "<user_query>  </user_query>") == nil)
        #expect(WorkBuddyLog.userWords(in: "Also the README") == "Also the README")
        #expect(WorkBuddyLog.userWords(in: "<system-reminder>Network error</system-reminder>") == nil)
    }

    @Test("The transcript holds the person's words, the agent's last words and what it did; tool output stays out")
    func transcript() throws {
        let rounds = ConversationTranscript.rounds(in: WorkBuddyLine.file([
            WorkBuddyLine.meta, WorkBuddyLine.prompt("Make the deploy script retry"),
            WorkBuddyLine.reasoning(at: 3), WorkBuddyLine.reply("Let me look.", at: 4, last: false),
            WorkBuddyLine.call("Write", id: "c1", arguments: #"{"file_path":"/repo/deploy.sh","content":"x"}"#, at: 5),
            WorkBuddyLine.result("Write", id: "c1", output: "SECRET OUTPUT", at: 6),
            WorkBuddyLine.call("Bash", id: "c2", arguments: #"{"command":"./deploy.sh","description":"run"}"#, at: 7),
            WorkBuddyLine.result("Bash", id: "c2", at: 8),
            WorkBuddyLine.reply("Deploy now retries.", at: 9, last: true),
            WorkBuddyLine.prompt("Now stop", request: "r-2", at: 20),
            WorkBuddyLine.unfinished("Interrupted by user", error: nil, at: 21),
        ]))
        #expect(rounds.map(\.request) == ["Make the deploy script retry", "Now stop"])
        #expect(rounds[0].reply == "Deploy now retries.")
        #expect(rounds[0].files == ["/repo/deploy.sh"])
        #expect(rounds[0].commands == ["./deploy.sh"])
        #expect(rounds[0].interrupted == false)
        #expect(rounds[1].reply == nil)
        #expect(rounds[1].interrupted)
    }

    @Test("Tokens count fresh input and output once per model step")
    func tokens() throws {
        let root = URL.temporaryDirectory.appending(path: "workbuddy-tokens-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "wb-1.jsonl")
        try WorkBuddyLine.file([
            WorkBuddyLine.meta, WorkBuddyLine.prompt("Go"), WorkBuddyLine.reply("Looking.", at: 4, last: false),
            WorkBuddyLine.call("Read", id: "c1", arguments: "{}", at: 5), WorkBuddyLine.result("Read", id: "c1", at: 6),
            WorkBuddyLine.reply("Done.", at: 7, last: true),
        ]).write(to: file)
        // Two steps, each 1000 in with 900 cached, and 50 out.
        #expect(TokenTally.read(file).values.reduce(0, +) == 300)
    }
}
