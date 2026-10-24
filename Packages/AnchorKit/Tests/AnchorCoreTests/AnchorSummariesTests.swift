import Foundation
import Testing
@testable import AnchorCore

@Suite("Glance summaries")
struct AnchorSummariesTests {
    /// A stand-in for a model: counts its calls, or fails.
    private actor ModelWriter: AnchorSummarizer {
        let name: String?
        private(set) var nameCalls = 0

        init(name: String?) {
            self.name = name
        }

        func conversationName(_ source: ConversationNameSource) async throws -> String {
            nameCalls += 1
            guard let name else { throw CancellationError() }
            return name
        }
    }

    private struct PlainWriter: AnchorSummarizer {
        func conversationName(_ source: ConversationNameSource) async throws -> String { source.gist ?? "" }
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
        let model = ModelWriter(name: "横屏任务进程库的卡片切换动效")
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
}
