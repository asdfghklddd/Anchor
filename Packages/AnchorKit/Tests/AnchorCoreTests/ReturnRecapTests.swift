import Foundation
import Testing
@testable import AnchorCore

@Suite("Return recaps")
struct ReturnRecapTests {
    private static func log(_ lines: [[String: Any]]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "recap-\(UUID().uuidString).jsonl")
        let data = try lines.map { try JSONSerialization.data(withJSONObject: $0) }
            .reduce(into: Data()) { $0.append($1); $0.append(10) }
        try data.write(to: url)
        return url
    }

    private static func codexUser(_ text: String) -> [[String: Any]] {
        [
            ["type": "response_item", "payload": ["type": "message", "role": "user",
                                                  "content": [["type": "input_text", "text": text]]]],
            ["type": "event_msg", "payload": ["type": "user_message", "message": text]],
        ]
    }

    private static func codexReply(_ text: String) -> [[String: Any]] {
        [
            ["type": "event_msg", "payload": ["type": "agent_message", "message": text]],
            ["type": "response_item", "payload": ["type": "message", "role": "assistant",
                                                  "content": [["type": "output_text", "text": text]]]],
        ]
    }

    @Test("A Codex log yields its last five rounds once each, without injected context or code")
    func codexRounds() throws {
        var lines: [[String: Any]] = Self.codexUser("<environment_context>cwd</environment_context>")
        for index in 1...7 {
            lines += Self.codexUser("请求 \(index)")
            lines += Self.codexReply("进度 \(index)\n```swift\nlet x = 1\n```\n完成")
        }
        lines += Self.codexUser("请求 8")
        let url = try Self.log(lines)
        let transcript = try #require(ConversationTranscript.read(at: url))
        #expect(transcript.rounds.map(\.request) == ["请求 4", "请求 5", "请求 6", "请求 7", "请求 8"])
        #expect(transcript.rounds[0].reply == "进度 4\n完成")
        #expect(transcript.rounds.last?.reply == nil)
    }

    @Test("A Claude Code log keeps typed prompts and the reply's last words, skipping tools and sub-agents")
    func claudeRounds() throws {
        let lines: [[String: Any]] = [
            ["type": "user", "sessionId": "s", "message": ["role": "user", "content": "修复登录崩溃"]],
            ["type": "assistant", "sessionId": "s", "message": ["role": "assistant",
                "content": [["type": "text", "text": "先看日志"], ["type": "tool_use", "id": "t", "name": "Bash"]]]],
            ["type": "user", "sessionId": "s", "message": ["role": "user",
                "content": [["type": "tool_result", "tool_use_id": "t", "content": "ok"]]]],
            ["type": "assistant", "sessionId": "s", "isSidechain": true,
             "message": ["role": "assistant", "content": [["type": "text", "text": "子代理"]]]],
            ["type": "assistant", "sessionId": "s", "message": ["role": "assistant",
                "content": [["type": "text", "text": "已修复，等你验证"]]]],
            ["type": "user", "sessionId": "s", "isMeta": true, "message": ["role": "user", "content": "meta"]],
        ]
        let url = try Self.log(lines)
        let transcript = try #require(ConversationTranscript.read(at: url))
        #expect(transcript.rounds == [ConversationTranscript.Round(request: "修复登录崩溃", reply: "已修复，等你验证")])
    }

    private actor CountingWriter: ConversationRecapWriting {
        var calls = 0
        let fails: Bool
        init(fails: Bool = false) { self.fails = fails }
        func recap(_ facts: ConversationRecapFacts) async throws -> String {
            calls += 1
            if fails { throw CancellationError() }
            return "在做\(facts.conversationName)，" + String(repeating: "很长", count: 40)
        }
    }

    private static func returning(logs: [UUID: URL]) async throws -> (InMemorySessionRepository, UUID, [UUID]) {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let sources = Array(logs.keys)
        let processes = sources.enumerated().map { index, source in
            AnchorProcess(sourceID: source, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                          title: "对话\(index)", status: .completed, updatedAt: now.addingTimeInterval(Double(index)),
                          request: "最近的请求\(index)")
        }
        let task = AnchorSession(goal: AnchorGoal(title: "作业", completionCriteria: ""), presence: .away,
                                 processes: processes)
        let repository = InMemorySessionRepository(initialProjection: SessionProjection(session: task))
        try await repository.send(.updatePresence(.returning, at: now))
        return (repository, task.id, processes.map(\.id))
    }

    @Test("Each conversation is recapped in at most sixty characters, newest first, and kept with the task")
    func recapsAndKeeps() async throws {
        let one = try Self.log(Self.codexUser("写红黑树删除") + Self.codexReply("完成了"))
        let two = try Self.log(Self.codexUser("写报告"))
        let sourceOne = UUID(), sourceTwo = UUID()
        let (repository, taskID, processIDs) = try await Self.returning(logs: [sourceOne: one, sourceTwo: two])
        let logs = [sourceOne: one, sourceTwo: two]
        let writer = CountingWriter()
        let recapper = ReturnRecapper(repository: repository, writer: writer, logFile: { logs[$0] })

        await recapper.consider(await repository.currentProjection())
        let projection = await repository.currentProjection()
        let returnedAt = try #require(projection.returnMoment)
        let recap = try #require(projection.session?.returnRecap(for: returnedAt))
        #expect(Set(recap.conversations.map(\.id)) == Set(processIDs))
        #expect(recap.conversations.map(\.name) == ["对话1", "对话0"])
        #expect(recap.conversations.allSatisfy { $0.text.count <= 60 && $0.text.hasPrefix("在做") })
        #expect(projection.session?.id == taskID)
        #expect(await writer.calls == 2)

        // The same return is never recapped twice.
        await recapper.consider(projection)
        #expect(await writer.calls == 2)
    }

    @Test("A conversation that has not moved keeps its recap at the next return")
    func cacheByTranscript() async throws {
        let url = try Self.log(Self.codexUser("写报告") + Self.codexReply("写好了"))
        let source = UUID()
        let writer = CountingWriter()
        let (repository, _, _) = try await Self.returning(logs: [source: url])
        let recapper = ReturnRecapper(repository: repository, writer: writer, logFile: { _ in url })
        let task = try #require(await repository.currentProjection().session)
        _ = await recapper.recap(task, returnedAt: .now)
        _ = await recapper.recap(task, returnedAt: .now.addingTimeInterval(60))
        #expect(await writer.calls == 1)
    }

    @Test("Without the model, a recap is the latest request")
    func localFallback() async throws {
        let url = try Self.log(Self.codexUser("先跑测试") + Self.codexReply("好") + Self.codexUser("再修复失败项"))
        let source = UUID()
        let (repository, _, _) = try await Self.returning(logs: [source: url])
        let recapper = ReturnRecapper(repository: repository, writer: CountingWriter(fails: true), logFile: { _ in url })
        let task = try #require(await repository.currentProjection().session)
        let recap = await recapper.recap(task, returnedAt: .now)
        #expect(recap.conversations.first?.text == "再修复失败项")
    }

    @Test("A recap survives the wire and the task keeps one per return")
    func operationRoundTrip() throws {
        let recap = ReturnRecap(returnedAt: Date(timeIntervalSince1970: 5),
                                conversations: [ConversationRecap(id: UUID(), name: "对话", text: "在做作业")])
        let data = try JSONEncoder.anchor.encode(SessionOperation.recordReturnRecap(recap))
        #expect(try JSONDecoder.anchor.decode(SessionOperation.self, from: data) == .recordReturnRecap(recap))

        var task = AnchorSession(goal: AnchorGoal(title: "作业", completionCriteria: ""))
        task.keep(recap)
        var rewritten = recap
        rewritten.conversations[0].text = "改了"
        task.keep(ReturnRecap(returnedAt: recap.returnedAt, conversations: rewritten.conversations))
        #expect(task.returnRecaps?.count == 1)
        #expect(task.returnRecap(for: recap.returnedAt)?.conversations.first?.text == "改了")
    }
}
