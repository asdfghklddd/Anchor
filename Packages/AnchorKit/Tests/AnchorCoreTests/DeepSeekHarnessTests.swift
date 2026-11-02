import Foundation
import Testing
@testable import AnchorCore

/// A status file shaped like DeepSeek Harness 0.2.1's, with made-up text.
struct HarnessFixture {
    var turns: [(request: String, reply: String)] = [("Fix the Anchor dashboard", "Fixed the layout. Want me to run the tests?")]
    var latestTurn = 1
    var open = false
    var openQuestions = 0
    var answeredQuestions = 0
    var title: String? = "Dashboard fix"
    var cwd = "/Users/demo/AnchorDemo/anchor-old"
    var createdAt = Date.now.addingTimeInterval(-600)
    var lastRequestAt = Date.now.addingTimeInterval(-300)
    var tokens = (uncached: 9_000, output: 300, cacheRead: 50_000, cacheWrite: 0)
    var milliseconds = (llm: 40_000, tool: 2_000)
    var subagent = false
    var blank = false

    var data: Data {
        func row(_ value: Any) -> [String: Any] { ["ver": 1, "seq": 1, "val": value] }
        func ms(_ date: Date) -> Int { Int(date.timeIntervalSince1970 * 1_000) }
        var outline: [[String: Any]] = []
        for (index, turn) in turns.enumerated() {
            outline.append(["turn": index + 1, "seq": index * 10 + 4, "prompt": turn.request, "response": turn.reply])
        }
        let question: [String: Any] = ["id": "q", "header": "Choose"]
        let boundary: [String: Any] = ["openTurnStartSeq": open ? 40 : NSNull(), "lastStepStartSeq": 38,
                                       "lastStepBoundary": ["kind": open ? "start" : "end", "seq": 39] as [String: Any],
                                       "lastTurn": latestTurn]
        let stats: [String: Any] = ["turns": open ? latestTurn - 1 : latestTurn, "steps": 3,
                                    "llmMs": milliseconds.llm, "toolMs": milliseconds.tool]
        let totals: [String: Any] = ["uncachedInputTokens": tokens.uncached, "outputTokens": tokens.output,
                                     "cacheReadTokens": tokens.cacheRead, "cacheWriteTokens": tokens.cacheWrite]
        let questions: [String: Any] = ["active": Array(repeating: question, count: openQuestions),
                                        "settled": Array(repeating: question, count: answeredQuestions)]
        let agent: [String: Any] = subagent ? ["identity": ["mode": "continuable", "label": "Review", "seq": 0] as [String: Any]] : [:]
        var rows: [String: Any] = [:]
        rows["title"] = row(title.map { $0 as Any } ?? NSNull())
        rows["workingDirectory"] = row(cwd)
        rows["turnBoundary"] = row(boundary)
        rows["sessionStats"] = row(stats)
        rows["tokenUsage"] = row(["totals": totals] as [String: Any])
        rows["turnOutline"] = row(["turns": outline, "draft": ""] as [String: Any])
        rows["userQuestions"] = row(["inheritedEventCount": 0, "timed": false, "questions": questions] as [String: Any])
        rows["subagent"] = row(agent)
        rows["sessionListMetadata"] = row(["blank": blank, "lastPromptAt": ms(lastRequestAt)] as [String: Any])
        let identity: [String: Any] = ["formatVersion": 4, "createdAt": ms(createdAt), "cwd": cwd,
                                       "isSeeded": false, "inheritedEventCount": 0]
        let record: [String: Any] = ["identity": identity, "rows": rows]
        return try! JSONSerialization.data(withJSONObject: ["version": 7, "record": record] as [String: Any])
    }

    /// Writes into `<folder>/session_projcache/sessions/session-<id>.json`.
    @discardableResult
    func write(id: String = "2337a4b6-7b1d-4e7b-992e-56697790820e", in folder: URL, modified: Date = .now) throws -> URL {
        let sessions = folder.appending(path: "session_projcache/sessions", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        let url = sessions.appending(path: "session-\(id).json")
        try data.write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        return url
    }
}

@Suite("DeepSeek Harness")
struct DeepSeekHarnessTests {
    private let folder = URL.temporaryDirectory.appending(path: "harness-\(UUID())")

    @Test func readsTheStatusFile() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try HarnessFixture().write(in: folder)
        let status = try #require(HarnessSessionStatus(contentsOf: url))
        #expect(status.id == "2337a4b6-7b1d-4e7b-992e-56697790820e")
        #expect(status.workspaceName == "anchor-old")
        #expect(status.title == "Dashboard fix")
        #expect(status.turns.map(\.request) == ["Fix the Anchor dashboard"])
        #expect(status.workedSeconds == 42)
        #expect(status.tokens == 9_300)
        #expect(!status.isTurnOpen)
        #expect(status.isUserConversation)

        #expect(ConversationDialect.of(url) == .deepseekHarness)
        let metadata = try #require(CodexSessionMetadata.read(from: url))
        #expect(metadata.sourceName == "DeepSeek")
        #expect(metadata.isUserConversation)
        #expect(CodexAutoAssociation.latestUserRequest(at: url) == "Fix the Anchor dashboard")
        #expect(ConversationTranscript.read(at: url)?.rounds.first?.reply == "Fixed the layout. Want me to run the tests?")
        #expect(ConversationLink(logAt: url)?.url.absoluteString == "dsh://open")
        #expect(!HarnessSessionStatus.isStatusFile(folder.appending(path: "session.json")))
    }

    @Test func aQuestionHoldsTheTurnAndAnAnswerStartsItAgain() {
        var fixture = HarnessFixture()
        fixture.open = true
        let running = HarnessSessionStatus(data: fixture.data, id: "a")?.stretch
        #expect(running == .init(turnID: "turn-1", lifecycle: .started, waiting: false))

        fixture.openQuestions = 1
        let asking = HarnessSessionStatus(data: fixture.data, id: "a")?.stretch
        #expect(asking == .init(turnID: "turn-1", lifecycle: .completed, waiting: true))

        fixture.openQuestions = 0
        fixture.answeredQuestions = 1
        let resumed = HarnessSessionStatus(data: fixture.data, id: "a")?.stretch
        #expect(resumed == .init(turnID: "turn-1-after-1", lifecycle: .started, waiting: false))

        fixture.open = false
        let ended = HarnessSessionStatus(data: fixture.data, id: "a")?.stretch
        #expect(ended == .init(turnID: "turn-1-after-1", lifecycle: .completed, waiting: false))
    }

    @Test func eventsCarryTheTurnAndWaitOnTheQuestion() async throws {
        var fixture = HarnessFixture()
        fixture.open = true
        fixture.openQuestions = 1
        let status = try #require(HarnessSessionStatus(data: fixture.data, id: "a"))
        let source = DeepSeekHarnessSource(
            fileURL: folder, sessionContextProvider: { nil },
            descriptor: SourceDescriptor(id: UUID(), name: "DeepSeek", kind: .integration, symbol: "DS",
                                         tone: "periwinkle", capabilities: [.observe]))
        let context = ProcessSourceSessionContext(sessionID: UUID(), startedAt: .now.addingTimeInterval(-3_600))
        let events = await source.events(for: status, modified: .now, context: context)
        #expect(events.map(\.process.status) == [.running, .needsDecision])
        let waiting = try #require(events.last)
        #expect(waiting.process.sourceSymbol == "DS")
        #expect(waiting.process.title == "Dashboard fix")
        #expect(waiting.process.request == "Fix the Anchor dashboard")
        #expect(waiting.process.workedSeconds == 42)

        // Work from before the task began is not the task's.
        let later = ProcessSourceSessionContext(sessionID: UUID(), startedAt: .now.addingTimeInterval(60))
        #expect(await source.events(for: status, modified: .now, context: later).isEmpty)
    }

    @Test func listsConversationsButNotSubagentsOrEmptyWindows() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var fixture = HarnessFixture()
        fixture.open = true
        fixture.openQuestions = 1
        try fixture.write(id: "11111111-1111-1111-1111-111111111111", in: folder)
        var subagent = HarnessFixture()
        subagent.subagent = true
        try subagent.write(id: "22222222-2222-2222-2222-222222222222", in: folder)
        var blank = HarnessFixture()
        blank.blank = true
        blank.turns = []
        blank.latestTurn = 0
        try blank.write(id: "33333333-3333-3333-3333-333333333333", in: folder)

        let supervisor = DeepSeekHarnessSupervisor(rootURL: folder.appending(path: "session_projcache/sessions"))
        let summaries = await supervisor.summaries()
        #expect(summaries.map(\.id) == ["11111111-1111-1111-1111-111111111111"])
        let summary = try #require(summaries.first)
        #expect(summary.title == "Dashboard fix")
        #expect(summary.isWaitingForReply)
        #expect(summary.candidate.workspaceName == "anchor-old")
    }

    @Test func tokensCountWhatEachReadAdds() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let root = folder.appending(path: "session_projcache/sessions")
        let dayStart = Calendar.current.startOfDay(for: .now)
        let first = dayStart.addingTimeInterval(9 * 3_600 + 60)
        var today = HarnessFixture()
        today.createdAt = dayStart.addingTimeInterval(9 * 3_600)
        try today.write(id: "11111111-1111-1111-1111-111111111111", in: folder, modified: first)
        var older = HarnessFixture()
        older.createdAt = dayStart.addingTimeInterval(-86_400)
        try older.write(id: "22222222-2222-2222-2222-222222222222", in: folder, modified: first)

        let tally = TokenTally()
        // Begun today: all of it. Begun yesterday: nothing until it grows.
        #expect(await tally.slots(under: [root], since: dayStart).map(\.tokens) == [9_300])

        let second = dayStart.addingTimeInterval(10 * 3_600 + 60)
        older.tokens.output += 700
        try older.write(id: "22222222-2222-2222-2222-222222222222", in: folder, modified: second)
        let slots = await tally.slots(under: [root], since: dayStart)
        #expect(slots.map(\.tokens) == [9_300, 700])
        #expect(slots.last?.start == DayActivity.slotStart(of: second))
    }
}
