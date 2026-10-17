import AnchorCore
import AnchorDesign
import Foundation
import Testing
@testable import AnchorMacFeatures

private let now = Date(timeIntervalSince1970: 1_792_137_600)

private func ago(_ minutes: Double) -> Date {
    now.addingTimeInterval(-minutes * 60)
}

func codexConversation(
    _ id: String,
    _ state: CodexConversationSummary.State,
    modified: Date,
    created: Date? = nil,
    title: String? = nil,
    workspace: String = "Anchor",
    reply: String? = nil
) -> CodexConversationSummary {
    CodexConversationSummary(
        candidate: CodexTaskCandidate(
            id: id,
            fileURL: URL(filePath: "/tmp/\(id).jsonl"),
            workspaceName: workspace,
            originator: "Codex Desktop",
            modifiedAt: modified,
            activity: .unknown,
            activityObservedAt: nil,
            createdAt: created
        ),
        title: title ?? id,
        state: state,
        reply: reply
    )
}

@Test("Running conversations lead; the rest follow by when their turn ended, not by log writes")
func ordersCodexConversations() {
    let list = [
        codexConversation("done-recent", .completed(at: ago(2), duration: 60), modified: ago(2)),
        // Written to a moment ago, yet it keeps the place its turn start gives it.
        codexConversation("running-old", .running(since: ago(30)), modified: ago(0.1)),
        codexConversation("stopped", .interrupted(at: ago(10)), modified: ago(10)),
        codexConversation("running-new", .running(since: ago(5)), modified: ago(1)),
        codexConversation("fresh", .unknown, modified: ago(0.5), created: ago(20)),
        codexConversation("failed", .failed(at: ago(1), message: "x"), modified: ago(1)),
    ]

    #expect(MacCodexConversationOrder.ordered(list).map(\.id)
        == ["running-new", "running-old", "failed", "done-recent", "stopped", "fresh"])
}

@Test("Each state reads as one word, one fact and, when there is one, the reply or error")
func describesCodexConversationStates() {
    let running = MacCodexConversationStatus(
        codexConversation("a", .running(since: ago(6)), modified: ago(0.2)), now: now)
    #expect(running.tone == .running)
    #expect(running.label == L10n.sourceSetupTaskRunning)
    #expect(running.fact == MacCodexConversationStatus.duration(360))
    #expect(running.endedAt == nil)

    // A long silence is stated, not dressed up as progress or guessed as a failure.
    let quiet = MacCodexConversationStatus(
        codexConversation("b", .running(since: ago(40)), modified: ago(12)), now: now)
    #expect(quiet.tone == .quiet)
    #expect(quiet.label == L10n.sourceSetupTaskRunning)
    #expect(quiet.fact == MacCodexCopy.quiet(MacCodexConversationStatus.duration(720)))

    let done = MacCodexConversationStatus(
        codexConversation("c", .completed(at: ago(3), duration: 420), modified: ago(3), reply: "Fixed it"), now: now)
    #expect(done.tone == .done)
    #expect(done.fact == MacCodexCopy.took(MacCodexConversationStatus.duration(420)))
    #expect(done.detail == "Fixed it")
    #expect(done.endedAt == ago(3))

    let failed = MacCodexConversationStatus(
        codexConversation("d", .failed(at: ago(1), message: "Context window exceeded"), modified: ago(1)), now: now)
    #expect(failed.tone == .failed)
    #expect(failed.label == MacCodexCopy.failed)
    #expect(failed.detail == "Context window exceeded")

    let stopped = MacCodexConversationStatus(
        codexConversation("e", .interrupted(at: ago(9)), modified: ago(9)), now: now)
    #expect(stopped.tone == .stopped)
    #expect(stopped.label == L10n.sourceSetupTaskInterrupted)
    #expect(stopped.detail == nil)
}

@Test("The Mac reads conversation times in Chinese at glance precision")
func formatsCodexConversationTimes() {
    #expect(MacCodexConversationStatus.duration(42) == "42秒")
    #expect(MacCodexConversationStatus.duration(420) == "7分钟")
    #expect(MacCodexConversationStatus.duration(3_720) == "1小时2分钟")
    #expect(MacCodexCopy.took("7分钟") == "用时 7分钟")
    #expect(MacCodexCopy.quiet("12分钟") == "12分钟没有新动态")
    #expect(MacCodexCopy.more(2) == "另有 2 个对话")
    #expect(MacCodexCopy.title == "Codex 对话")
}
