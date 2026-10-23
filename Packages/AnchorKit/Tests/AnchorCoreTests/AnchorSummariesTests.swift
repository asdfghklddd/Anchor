import Foundation
import Testing
@testable import AnchorCore

@Suite("Glance summaries")
struct AnchorSummariesTests {
    /// A stand-in for a model: says too much, counts its calls, or fails.
    private actor ModelWriter: AnchorSummarizer {
        let name: String?
        let recap: String?
        private(set) var nameCalls = 0

        init(name: String?, recap: String?) {
            self.name = name
            self.recap = recap
        }

        func conversationName(_ source: ConversationNameSource) async throws -> String {
            nameCalls += 1
            guard let name else { throw CancellationError() }
            return name
        }

        func leaveRecap(_ facts: TaskLeaveFacts) async throws -> String {
            guard let recap else { throw CancellationError() }
            return recap
        }
    }

    private struct PlainWriter: AnchorSummarizer {
        func conversationName(_ source: ConversationNameSource) async throws -> String { source.gist ?? "" }
        func leaveRecap(_ facts: TaskLeaveFacts) async throws -> String { "local: \(facts.title)" }
    }

    @Test("Names fit about ten Chinese characters and recaps sixty characters")
    func limits() {
        #expect(SummaryLimit.name("按设计稿重做横屏工作页面并加动效") == "按设计稿重做横屏工作")
        #expect(SummaryLimit.name("  iOS app UI\npolish  ") == "iOS app UI polish")
        #expect(SummaryLimit.name("   ") == nil)
        let long = String(repeating: "进度", count: 40)
        let recap = SummaryLimit.recap(long)
        #expect(recap?.count == 60 && recap?.hasSuffix("…") == true)
        #expect(SummaryLimit.recap("第 2/4 步：实现删除") == "第 2/4 步：实现删除")
    }

    @Test("A name is the conversation's own name, else the gist of its first request")
    func gist() {
        #expect(ConversationNameSource(ownName: "iOS app UI polish", firstRequest: "帮我改界面").gist == "iOS app UI polish")
        #expect(ConversationNameSource(firstRequest: "帮我实现红黑树的删除，包括 fixup").gist == "实现红黑树的删除")
        #expect(ConversationNameSource(firstRequest: "Please fix the login crash on cold start").gist
            == "fix the login crash")
        #expect(ConversationNameSource().gist == nil)
    }

    @Test("The book answers with the local draft at once, then the model's name, asked once")
    func modelNameReplacesDraft() async throws {
        let model = ModelWriter(name: "横屏任务进程库的卡片切换动效", recap: nil)
        let book = SummaryBook(local: PlainWriter(), model: model)
        let log = URL(fileURLWithPath: "/tmp/conversation.jsonl")
        #expect(await book.name(for: log) == nil)

        await book.note([log: ConversationNameSource(firstRequest: "帮我做卡片切换动效")])
        #expect(await book.name(for: log) == "做卡片切换动效")
        var name: String?
        for _ in 0..<50 {
            name = await book.name(for: log)
            if name != "做卡片切换动效" { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(name == "横屏任务进程库的卡片")
        #expect(await model.nameCalls == 1)
    }

    @Test("Recaps come from the model when it answers, held to sixty characters, else from the local writer")
    func leaveRecaps() async {
        let task = AnchorSession(goal: AnchorGoal(title: "Anchor", completionCriteria: ""))
        let local = await SummaryBook(local: PlainWriter(), model: ModelWriter(name: nil, recap: nil))
            .leaveRecaps(for: [task])
        #expect(local[task.id] == "local: Anchor")

        let wordy = String(repeating: "很长的回顾", count: 20)
        let modelled = await SummaryBook(local: PlainWriter(), model: ModelWriter(name: nil, recap: wordy))
            .leaveRecaps(for: [task])
        #expect(modelled[task.id]?.count == 60)
    }

    @Test("Leave facts hold the next step and the newest conversations, not commands")
    func leaveFacts() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func process(_ title: String, _ minutes: Double, command: Bool = false, status: ProcessStatus = .completed) -> AnchorProcess {
            AnchorProcess(sourceID: command ? BuiltInProcessSourceID.file : UUID(), sourceName: "Claude Code",
                          sourceSymbol: "C", sourceTone: "cyan", title: title, status: status,
                          detail: "Done.", updatedAt: now.addingTimeInterval(-minutes * 60), request: "Ask \(title)")
        }
        let task = AnchorSession(
            goal: AnchorGoal(title: "作业", completionCriteria: "",
                             userPlan: AnchorUserPlan(steps: ["实现插入", "实现删除", "写报告"], completedSteps: [0])),
            processes: [process("old", 50), process("swift test", 1, command: true), process("new", 5, status: .running),
                        process("mid", 20), process("older", 60)])
        let facts = TaskLeaveFacts(task: task)

        #expect(facts.stepCount == 3 && facts.stepsDone == 1)
        #expect(facts.nextStepNumber == 2 && facts.nextStepText == "实现删除")
        #expect(facts.conversations.map(\.name) == ["new", "mid", "old"])
        #expect(facts.conversations.first?.reply == nil)
        #expect(facts.conversations.last?.request == "Ask old")
    }
}
