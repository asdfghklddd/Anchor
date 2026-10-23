import Foundation
import Testing
@testable import AnchorCore

@Suite("Task conversation stack")
struct TaskConversationStackTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func conversation(_ title: String, minutesAgo: Double, status: ProcessStatus = .completed,
                              command: Bool = false) -> AnchorProcess {
        AnchorProcess(sourceID: command ? BuiltInProcessSourceID.file : UUID(),
                      sourceName: command ? "Terminal" : "Claude Code", sourceSymbol: "C", sourceTone: "cyan",
                      title: title, status: status, updatedAt: now.addingTimeInterval(-minutesAgo * 60))
    }

    private func task(_ processes: [AnchorProcess]) -> AnchorSession {
        var task = AnchorSession(goal: AnchorGoal(title: "Anchor", completionCriteria: ""), processes: processes)
        task.captureJoiningOrder()
        return task
    }

    @Test("The three newest conversations stack in joining order with the newest in front")
    func newestThreeInFront() {
        let first = conversation("first", minutesAgo: 50)
        let second = conversation("second", minutesAgo: 5)
        let third = conversation("third", minutesAgo: 30)
        let fourth = conversation("fourth", minutesAgo: 10)
        let command = conversation("swift test", minutesAgo: 1, command: true)
        let stack = TaskConversationStack(task: task([first, second, third, command, fourth]))

        #expect(stack.cards.map(\.title) == ["third", "fourth", "second"])
        #expect(stack.front?.title == "second")
    }

    @Test("A picked card stays in front until another conversation moves")
    func pickHoldsUntilNews() {
        let older = conversation("older", minutesAgo: 20)
        let newer = conversation("newer", minutesAgo: 10)
        let pick = TaskConversationStack.Pick(conversation: older.id, at: now.addingTimeInterval(-5 * 60))

        let picked = TaskConversationStack(task: task([older, newer]), pick: pick)
        #expect(picked.cards.map(\.title) == ["newer", "older"])

        var moved = newer
        moved.updatedAt = now
        let afterNews = TaskConversationStack(task: task([older, moved]), pick: pick)
        #expect(afterNews.front?.title == "newer")
    }

    @Test("A task without conversations has an empty stack")
    func emptyStack() {
        let stack = TaskConversationStack(task: task([conversation("make", minutesAgo: 1, command: true)]))
        #expect(stack.cards.isEmpty && stack.front == nil)
    }

    @Test("A running turn has no reply yet; a finished one answers with its reply or error")
    func latestReply() {
        var running = conversation("run", minutesAgo: 1, status: .running)
        running.detail = "An older reply"
        #expect(running.latestReply == nil)

        var finished = conversation("done", minutesAgo: 1)
        finished.detail = "  Done: three voice samples.  "
        #expect(finished.latestReply == "Done: three voice samples.")
        finished.detail = ""
        #expect(finished.latestReply == nil)
    }
}
