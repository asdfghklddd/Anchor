import Foundation
import Testing
@testable import AnchorCore

private let meta = #"{"timestamp":"2026-10-16T08:00:00.000Z","type":"session_meta","payload":{"id":"thread-a","cwd":"/Users/example/Anchor","originator":"Codex Desktop","thread_source":"user"}}"#
private let injected = #"{"timestamp":"2026-10-16T08:00:00.100Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>\n  <cwd>/Users/example/Anchor</cwd>\n</environment_context>"}]}}"#
private let request = #"{"timestamp":"2026-10-16T08:00:00.200Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix the **login** crash\nIt happens on launch."}]}}"#
private let started = #"{"timestamp":"2026-10-16T08:00:01.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#
private let toolCall = #"{"timestamp":"2026-10-16T08:00:02.000Z","type":"response_item","payload":{"type":"function_call","name":"exec","arguments":"{\"cmd\":\"echo task_complete\"}"}}"#

private func writeSession(_ lines: [String], in folder: URL) throws -> URL {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appending(path: "rollout-2026-10-16T08-00-00-thread-a.jsonl")
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
    return file
}

private func temporaryRoot(_ name: String) -> URL {
    URL.temporaryDirectory.appending(path: "codex-summary-\(name)-\(UUID().uuidString)")
}

@Test("A finished turn shows its reply, its duration and the first real request")
func summarizesCompletedTurn() async throws {
    let root = temporaryRoot("completed")
    defer { try? FileManager.default.removeItem(at: root) }
    let reply = #"## Done\n\nFixed the crash in [LoginView.swift](/Users/example/LoginView.swift:12); **all tests pass**.\n\n```swift\nlet secret = 1\n```\n- Added a regression test"#
    let completed = #"{"timestamp":"2026-10-16T08:07:01.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","last_agent_message":"\#(reply)","duration_ms":420000,"error":null}}"#
    _ = try writeSession([meta, injected, request, started, toolCall, completed], in: root)

    let summary = try #require(await CodexTaskSupervisor(rootURL: root).summaries().first)

    #expect(summary.title == "Fix the login crash")
    #expect(summary.state == .completed(at: Date(timeIntervalSince1970: 1_792_138_021), duration: 420))
    #expect(summary.reply == "Fixed the crash in LoginView.swift; all tests pass. Added a regression test")
    #expect(summary.candidate.activity == .completed)
    // The privacy-minimal candidate still carries no conversation text.
    #expect(String(describing: summary.candidate).contains("crash") == false)
}

@Test("A turn that reported an error reads as failed, a stopped one as interrupted")
func summarizesFailedAndStoppedTurns() async throws {
    let failedRoot = temporaryRoot("failed")
    let stoppedRoot = temporaryRoot("stopped")
    defer {
        try? FileManager.default.removeItem(at: failedRoot)
        try? FileManager.default.removeItem(at: stoppedRoot)
    }
    let failed = #"{"timestamp":"2026-10-16T08:01:00.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","last_agent_message":null,"duration_ms":59000,"error":{"message":"Context window exceeded","codex_error_info":{}}}}"#
    let aborted = #"{"timestamp":"2026-10-16T08:01:00.000Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","reason":"interrupted","duration_ms":59000}}"#
    _ = try writeSession([meta, request, started, failed], in: failedRoot)
    _ = try writeSession([meta, request, started, aborted], in: stoppedRoot)

    let failure = try #require(await CodexTaskSupervisor(rootURL: failedRoot).summaries().first)
    let stop = try #require(await CodexTaskSupervisor(rootURL: stoppedRoot).summaries().first)

    let endedAt = Date(timeIntervalSince1970: 1_792_137_660)
    #expect(failure.state == .failed(at: endedAt, message: "Context window exceeded"))
    #expect(failure.reply == nil)
    #expect(stop.state == .interrupted(at: endedAt))
}

@Test("A turn without an end is running since it started; a fresh log has no state")
func summarizesRunningAndEmptyConversations() async throws {
    let runningRoot = temporaryRoot("running")
    let freshRoot = temporaryRoot("fresh")
    defer {
        try? FileManager.default.removeItem(at: runningRoot)
        try? FileManager.default.removeItem(at: freshRoot)
    }
    _ = try writeSession([meta, request, started, toolCall], in: runningRoot)
    let file = try writeSession([meta], in: freshRoot)

    let running = try #require(await CodexTaskSupervisor(rootURL: runningRoot).summaries().first)
    #expect(running.state == .running(since: Date(timeIntervalSince1970: 1_792_137_601)))

    let supervisor = CodexTaskSupervisor(rootURL: freshRoot)
    let fresh = try #require(await supervisor.summaries().first)
    #expect(fresh.state == .unknown)
    #expect(fresh.title == nil)

    // The request arrives after discovery; the title follows on the next change.
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\(request)\n".utf8))
    try handle.close()
    #expect(await supervisor.summaries().first?.title == "Fix the login crash")
}

@Test("Codex's own thread name wins when the index beside sessions is readable")
func prefersCodexThreadNames() async throws {
    let codex = temporaryRoot("index")
    defer { try? FileManager.default.removeItem(at: codex) }
    let sessions = codex.appending(path: "sessions")
    _ = try writeSession([meta, request, started], in: sessions.appending(path: "2026/10/16"))
    let index = [
        #"{"id":"thread-a","thread_name":"Old name","updated_at":"2026-10-16T08:00:00Z"}"#,
        #"{"id":"thread-a","thread_name":"Login crash fix","updated_at":"2026-10-16T08:05:00Z"}"#,
    ]
    try Data((index.joined(separator: "\n") + "\n").utf8).write(to: codex.appending(path: "session_index.jsonl"))

    let summary = try #require(await CodexTaskSupervisor(rootURL: sessions).summaries().first)

    #expect(summary.title == "Login crash fix")
}

@Test("Glance text keeps prose and drops code, tables, link targets and section labels")
func trimsMarkdownForAGlance() {
    let reply = """
    **Summary**

    | File | Change |
    |---|---|
    1. Rewrote `Parser.swift` — see [the PR](https://example.com/pr/1).
    ---
    > Tests pass.
    """
    #expect(CodexGlanceText.reply(from: reply) == "Rewrote Parser.swift — see the PR. Tests pass.")
    #expect(CodexGlanceText.reply(from: "## Done") == "Done")
    #expect(CodexGlanceText.reply(from: "```\nonly code\n```") == nil)

    let long = String(repeating: "word ", count: 200)
    let capped = CodexGlanceText.reply(from: long)
    #expect(capped?.count == CodexGlanceText.replyLength)
    #expect(capped?.hasSuffix("…") == true)

    #expect(CodexGlanceText.title(from: "\n  - 帮我修复登录崩溃\n详细说明") == "帮我修复登录崩溃")
}
