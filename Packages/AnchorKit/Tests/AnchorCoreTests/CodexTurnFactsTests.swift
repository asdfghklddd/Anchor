import Foundation
import Testing
@testable import AnchorCore

/// Log lines in the shape Codex writes them: compact JSON, payload type first.
private enum Line {
    static func started(_ turn: String, at time: String = "08:00:01") -> String {
        #"{"timestamp":"2026-10-16T\#(time).000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"\#(turn)"}}"#
    }
    static func exec(_ call: String, _ script: String) -> String {
        #"{"timestamp":"2026-10-16T08:01:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","id":"ctc","status":"completed","call_id":"\#(call)","name":"exec","input":"\#(script)"}}"#
    }
    static func execOutput(_ call: String, exitCode: Int?) -> String {
        let text = exitCode.map { #"{\"exit_code\": \#($0), \"stdout\": \"…\"}\nWall time: 12s"# } ?? "Wall time: 12s"
        return #"{"timestamp":"2026-10-16T08:02:00.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","id":"ctco","call_id":"\#(call)","output":[{"type":"input_text","text":"\#(text)"}]}}"#
    }
    static func js(_ call: String, code: String) -> String {
        #"{"timestamp":"2026-10-16T08:01:00.000Z","type":"response_item","payload":{"type":"function_call","name":"js","arguments":"{\"code\":\"\#(code)\",\"title\":\"Run\"}","call_id":"\#(call)"}}"#
    }
    static func functionOutput(_ call: String, _ output: String) -> String {
        #"{"timestamp":"2026-10-16T08:02:00.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"\#(call)","output":"\#(output)"}}"#
    }
    static func question(_ call: String, blocking: Bool = false) -> String {
        let name = blocking ? "request_user_input" : "request_user_input_async"
        return #"{"timestamp":"2026-10-16T08:03:00.000Z","type":"response_item","payload":{"type":"function_call","name":"\#(name)","arguments":"{\"questions\":[]}","call_id":"\#(call)"}}"#
    }
    static let userMessage = #"{"timestamp":"2026-10-16T08:09:00.000Z","type":"event_msg","payload":{"type":"user_message","message":"Yes"}}"#
    /// Tool output that happens to quote a user message must not count as one.
    static let quotedUser = #"{"timestamp":"2026-10-16T08:04:00.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","id":"x","call_id":"other","output":[{"type":"input_text","text":"{\"payload\":{\"type\":\"user_message\"}} \"role\":\"user\""}]}}"#
    static func completed(_ turn: String, seconds: Int, at time: String = "08:05:00") -> String {
        #"{"timestamp":"2026-10-16T\#(time).000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"\#(turn)","last_agent_message":"Done.","duration_ms":\#(seconds * 1000),"error":null}}"#
    }
}

private func scan(_ lines: [String]) -> [CodexLifecycleScannedRecord] {
    var scanner = CodexIncrementalScanner()
    return scanner.appendWithOffsets(Data((lines.joined(separator: "\n") + "\n").utf8))
}

@Suite("Codex turn facts")
struct CodexTurnFactsTests {
    @Test("Tests that ran give their verdict; other commands do not count")
    func testVerdicts() throws {
        let passed = scan([Line.started("t1"), Line.exec("c1", "text(await exec('git status'))"),
                           Line.exec("c2", "text(await exec('swift test --parallel'))"),
                           Line.execOutput("c2", exitCode: 0), Line.completed("t1", seconds: 30)])
        #expect(passed.last?.tests == .passed)

        let failed = scan([Line.started("t1"), Line.js("c1", code: "await exec('npm test')"),
                           Line.functionOutput("c1", #"{\"exit_code\":1}"#), Line.completed("t1", seconds: 30)])
        #expect(failed.last?.tests == .failed)

        let unknown = scan([Line.started("t1"), Line.exec("c1", "text(await exec('xcodebuild -scheme App test'))"),
                            Line.execOutput("c1", exitCode: nil), Line.completed("t1", seconds: 30)])
        #expect(unknown.last?.tests == .ran)
    }

    @Test("Only a long turn read from its start is called untested")
    func notTested() {
        #expect(scan([Line.started("t1"), Line.completed("t1", seconds: 240)]).last?.tests == .notRun)
        #expect(scan([Line.started("t1"), Line.completed("t1", seconds: 60)]).last?.tests == nil)
        // A scan that resumed mid-turn never saw it start.
        #expect(scan([Line.completed("t1", seconds: 600)]).last?.tests == nil)
        // A new turn starts its own count.
        let second = scan([Line.started("t1"), Line.exec("c1", "text(await exec('swift test'))"),
                           Line.execOutput("c1", exitCode: 0), Line.completed("t1", seconds: 30),
                           Line.started("t2", at: "08:06:00"), Line.completed("t2", seconds: 300, at: "08:12:00")])
        #expect(second.map(\.tests) == [nil, .passed, nil, .notRun])
    }

    @Test("A question still open when the turn ends waits for the person, until they reply")
    func waitingForReply() throws {
        let asked = scan([Line.started("t1"), Line.question("q1"), Line.functionOutput("q1", #"{\"accepted\":true}"#),
                          Line.quotedUser, Line.completed("t1", seconds: 30)])
        #expect(asked.last?.waitingForReply == true)

        let answered = scan([Line.started("t1"), Line.question("q1"), Line.userMessage, Line.completed("t1", seconds: 30)])
        #expect(answered.last?.waitingForReply == false)

        let session = UUID(), source = UUID()
        let event = try #require(asked.last).record.externalEvent(
            sessionID: session, sourceID: source, end: asked.last?.end, tests: asked.last?.tests,
            waitingForReply: true)
        #expect(event.process.status == .needsDecision)
        #expect(event.event?.kind == .decisionRequired)
        #expect(event.process.detail == "Done.")
    }

    @Test("A blocking question holds a running turn until its answer arrives")
    func blockingQuestion() {
        var facts = CodexTurnFacts()
        facts.turnStarted()
        facts.consume(Data(Line.question("q1", blocking: true).utf8))
        #expect(facts.isWaitingForReply(turnEnded: false))
        facts.consume(Data(Line.functionOutput("q1", #"{\"answers\":{}}"#).utf8))
        #expect(!facts.isWaitingForReply(turnEnded: true))
    }

    @Test("Exit statuses are read in every shape Codex has written")
    func exitCodes() {
        #expect(CodexTurnFacts.exitCode(in: #"{"exit_code": 2}"#) == 2)
        #expect(CodexTurnFacts.exitCode(in: "Exit code: 0\nWall time: 1s") == 0)
        #expect(CodexTurnFacts.exitCode(in: "Process exited with code 1") == 1)
        #expect(CodexTurnFacts.exitCode(in: "Wall time: 1s") == nil)
        #expect(CodexTurnFacts.runsTests("cd App && swift test --filter Login"))
        #expect(CodexTurnFacts.runsTests("python3 -m pytest -q"))
        #expect(!CodexTurnFacts.runsTests("rg testCase Sources"))
    }

    @Test("A synced test verdict decodes on older data and from newer peers")
    func outcomeDecoding() throws {
        let process = AnchorProcess(sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan", title: "Run",
                                    status: .completed, testOutcome: .failed)
        let data = try JSONEncoder().encode(process)
        #expect(try JSONDecoder().decode(AnchorProcess.self, from: data).testOutcome == .failed)
        let newer = Data(String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: #""testOutcome":"failed""#, with: #""testOutcome":"flaky""#).utf8)
        #expect(try JSONDecoder().decode(AnchorProcess.self, from: newer).testOutcome == .ran)
        // Data written before the field existed has no key at all.
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["testOutcome"] = nil
        let older = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(AnchorProcess.self, from: older).testOutcome == nil)
    }
}
