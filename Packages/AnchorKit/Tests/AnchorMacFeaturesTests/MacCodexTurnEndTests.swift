#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation
import Testing
@testable import AnchorMacFeatures

private let now = Date(timeIntervalSince1970: 1_792_137_600)

private func ago(_ minutes: Double) -> Date {
    now.addingTimeInterval(-minutes * 60)
}

@Test("Launching Anchor records where conversations stand without replaying their endings")
func turnEndBaselineDoesNotPing() {
    var detector = CodexTurnEndDetector()
    let seen = [
        codexConversation("a", .completed(at: ago(1), duration: 30), modified: ago(1)),
        codexConversation("b", .interrupted(at: ago(2)), modified: ago(2)),
        codexConversation("c", .running(since: ago(3)), modified: ago(0.1)),
    ]

    #expect(detector.endings(in: seen, now: now).isEmpty)
    #expect(detector.endings(in: seen, now: now).isEmpty)
}

@Test("Each new turn ending pings once, including a turn too short to be seen running")
func turnEndsPingOnce() {
    var detector = CodexTurnEndDetector()
    _ = detector.endings(in: [
        codexConversation("running", .running(since: ago(5)), modified: ago(0.2)),
        codexConversation("done", .completed(at: ago(4), duration: 60), modified: ago(4)),
    ], now: now)

    let next = [
        codexConversation("running", .completed(at: ago(0.1), duration: 290), modified: ago(0.1)),
        // A new turn began and ended between two scans.
        codexConversation("done", .failed(at: ago(0.2), message: "x"), modified: ago(0.2)),
        // A conversation first seen after the baseline, already ended.
        codexConversation("new", .interrupted(at: ago(0.3)), modified: ago(0.3)),
    ]
    #expect(detector.endings(in: next, now: now).map(\.id) == ["running", "done", "new"])
    #expect(detector.endings(in: next, now: now).isEmpty)
}

@Test("Old endings and a passing empty scan never ping")
func staleTurnEndsStayQuiet() {
    var detector = CodexTurnEndDetector()
    // A failed read must not become the baseline that makes everything look new.
    #expect(detector.endings(in: [], now: now).isEmpty)
    let first = [codexConversation("a", .completed(at: ago(1), duration: 30), modified: ago(1))]
    #expect(detector.endings(in: first, now: now).isEmpty)

    let late = [codexConversation("old", .completed(at: ago(11), duration: 30), modified: ago(11))]
    #expect(detector.endings(in: late, now: now).isEmpty)
}

@Test("A ping reads like the conversation's dashboard row")
func turnEndNoticeWording() throws {
    let done = try #require(CodexTurnEndNotice(codexConversation(
        "login", .completed(at: ago(1), duration: 420), modified: ago(1),
        title: "修复登录崩溃", reply: "已修复启动崩溃，所有测试通过。")))
    #expect(done.title == "修复登录崩溃")
    #expect(done.subtitle == "已完成 · 用时 7分钟 · Anchor")
    #expect(done.body == "已修复启动崩溃，所有测试通过。")
    #expect(done.threadIdentifier == "anchor.codex.login")
    #expect(done.identifier.hasPrefix(MacCodexTurnEndNotifier.identifierPrefix))

    let failed = try #require(CodexTurnEndNotice(codexConversation(
        "notes", .failed(at: ago(1), message: "Context window exceeded"), modified: ago(1), title: "整理发布说明")))
    #expect(failed.subtitle == "出错 · Anchor")
    #expect(failed.body == "Context window exceeded")

    // Without its own title the folder names the conversation once, not twice.
    let untitled = CodexConversationSummary(
        candidate: codexConversation("x", .interrupted(at: ago(1)), modified: ago(1)).candidate,
        title: nil, state: .interrupted(at: ago(1)), reply: nil)
    let stopped = try #require(CodexTurnEndNotice(untitled))
    #expect(stopped.title == "Anchor")
    #expect(stopped.subtitle == "已中断")
    #expect(stopped.body.isEmpty)

    #expect(CodexTurnEndNotice(codexConversation("r", .running(since: ago(1)), modified: ago(0.1))) == nil)

    // Two endings of one conversation are two notifications in one thread.
    let later = try #require(CodexTurnEndNotice(codexConversation(
        "login", .completed(at: ago(0.5), duration: 30), modified: ago(0.5))))
    #expect(later.identifier != done.identifier)
    #expect(later.threadIdentifier == done.threadIdentifier)
}

@MainActor
@Test("A turn that ends while Anchor watches reaches the ping once, with its reply")
func scannerHandsTurnEndsToThePing() async throws {
    let root = URL.temporaryDirectory.appending(path: "anchor-turn-end-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "anchor-turn-end-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    func at(_ secondsAgo: TimeInterval) -> String { formatter.string(from: .now.addingTimeInterval(-secondsAgo)) }
    let file = root.appending(path: "rollout-thread-ping.jsonl")
    let opening = [
        #"{"timestamp":"\#(at(60))","type":"session_meta","payload":{"id":"thread-ping","cwd":"/tmp/Anchor","originator":"codex_cli_rs","thread_source":"user"}}"#,
        #"{"timestamp":"\#(at(59))","type":"event_msg","payload":{"type":"user_message","message":"Fix the crash"}}"#,
        #"{"timestamp":"\#(at(58))","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#,
    ]
    try Data((opening.joined(separator: "\n") + "\n").utf8).write(to: file)

    var pinged: [CodexConversationSummary] = []
    let model = MacSourceSetupModel(defaults: defaults)
    model.onCodexTurnsEnded = { pinged.append(contentsOf: $0) }
    await model.observeAuthorizedCodexFolder(root)
    defer { model.stopObserving() }
    await model.refreshCodexCandidates()
    #expect(pinged.isEmpty)

    let completed = #"{"timestamp":"\#(at(1))","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","last_agent_message":"Fixed the crash.","duration_ms":57000,"error":null}}"#
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\(completed)\n".utf8))
    try handle.close()

    // The background scan may get there first; either way it pings exactly once.
    await model.refreshCodexCandidates()
    await model.refreshCodexCandidates()
    #expect(pinged.map(\.reply) == ["Fixed the crash."])
    #expect(pinged.first?.title == "Fix the crash")
}
#endif
