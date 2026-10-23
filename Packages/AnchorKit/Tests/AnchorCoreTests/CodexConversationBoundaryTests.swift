import Foundation
import Testing
@testable import AnchorCore

@Suite("Codex conversation boundary")
struct CodexConversationBoundaryTests {
    @Test("Only threads a person started count as conversations")
    func userThreadsOnly() throws {
        let user = try #require(metadata(threadSource: "user", originator: "Codex Desktop"))
        let handoff = try #require(metadata(threadSource: "chatgpt_handoff", originator: "Codex Desktop"))
        let guardian = try #require(metadata(
            threadSource: "guardian_review",
            extra: #","parent_thread_id":"parent","source":{"subagent":{"other":"guardian"}}"#
        ))
        let spawned = try #require(metadata(threadSource: "subagent", extra: #","parent_thread_id":"parent""#))
        let unlabelledSubagent = try #require(metadata(threadSource: nil, extra: #","source":{"subagent":"review"}"#))
        let legacy = try #require(metadata(threadSource: nil, extra: #","source":"vscode""#))

        #expect(user.isUserConversation && handoff.isUserConversation && legacy.isUserConversation)
        #expect(!guardian.isUserConversation && !spawned.isUserConversation && !unlabelledSubagent.isUserConversation)
        #expect(user.sourceName == "ChatGPT")
        #expect(try #require(metadata(threadSource: "user", originator: "codex_cli_rs")).sourceName == "Codex")
        #expect(user.workspaceName == "Anchor")
    }

    @Test("Subagent logs neither become candidates nor crowd out a user conversation")
    func subagentsDoNotCrowdDiscovery() async throws {
        let root = URL.temporaryDirectory.appending(path: "codex-boundary-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let user = root.appending(path: "user.jsonl")
        try sessionLog(id: "user-thread", threadSource: "user").write(to: user)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(-60)], ofItemAtPath: user.path)
        for index in 0..<14 {
            try sessionLog(
                id: "guardian-\(index)", threadSource: "guardian_review",
                extra: #","parent_thread_id":"user-thread","source":{"subagent":{"other":"guardian"}}"#
            ).write(to: root.appending(path: "guardian-\(index).jsonl"))
        }

        let candidates = await CodexTaskSupervisor(rootURL: root, candidateLimit: 12).snapshot()

        #expect(candidates.map(\.id) == ["user-thread"])
    }

    @Test("Matching reads the typed request, not attached page or file context")
    func typedRequestOnly() throws {
        let root = URL.temporaryDirectory.appending(path: "codex-request-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let pageOnly = #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<external_codex_apps_open_page>Quarterly budget spreadsheet</external_codex_apps_open_page>"}]}}"#
        let typed = #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix the Anchor dashboard"}]}}"#
        let file = root.appending(path: "page.jsonl")
        try Data((pageOnly + "\n" + typed + "\n").utf8).write(to: file)
        #expect(CodexAutoAssociation.firstUserRequest(at: file) == "Fix the Anchor dashboard")

        let mentioned = "# Files mentioned by the user:\n\n## mock.png: /Users/example/mock.png\n\n## My request for Codex:\nPolish the Mac edge boat\n"
        #expect(CodexAutoAssociation.userWords(in: mentioned) == "Polish the Mac edge boat")
        #expect(CodexAutoAssociation.userWords(in: "## Referenced ChatGPT conversation\nLong chat") == nil)
        #expect(CodexAutoAssociation.userWords(in: "  Ship the release notes ") == "Ship the release notes")
    }

    @Test("A conversation's turns fold into one dashboard row")
    func turnsFoldIntoConversation() throws {
        let sourceID = UUID()
        var session = AnchorSession(goal: AnchorGoal(title: "Anchor", completionCriteria: "Done"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let records = [("turn-1", "task_complete", 0.0), ("turn-2", "task_complete", 10), ("turn-3", "task_started", 20)]
        for (turn, lifecycle, offset) in records {
            let line = #"{"timestamp":"\#(ISO8601DateFormatter().string(from: base.addingTimeInterval(offset)))","type":"event_msg","payload":{"type":"\#(lifecycle)","turn_id":"\#(turn)"}}"#
            let event = try #require(CodexLifecycleRecord(json: Data(line.utf8)))
                .externalEvent(sessionID: session.id, sourceID: sourceID, sourceName: "ChatGPT", title: "Anchor")
            var process = event.process
            process.events = [try #require(event.event)]
            session.processes.append(process)
            session.timeline.append(try #require(event.event))
        }
        let command = AnchorProcess(sessionID: session.id, sourceID: BuiltInProcessSourceID.file,
                                    sourceName: "Terminal", sourceSymbol: "T", sourceTone: "cyan",
                                    title: "swift", status: .running)
        session.processes.append(command)
        session.captureJoiningOrder()
        let firstTurnID = session.processes[0].id

        let presented = try #require(TaskDashboardPolicy.presentation(of: SessionProjection(session: session)).session)

        #expect(presented.processes.count == 2)
        let conversation = try #require(presented.processes.first)
        #expect(conversation.id == firstTurnID)
        #expect(conversation.status == .running)
        #expect(conversation.sourceName == "ChatGPT" && conversation.title == "Anchor")
        #expect(conversation.events.count == 3)
        #expect(presented.processJoinOrder == [firstTurnID, command.id])
        #expect(presented.timeline.allSatisfy { $0.processID == firstTurnID })
    }

    @Test("A conversation shows the latest request one of its turns carried")
    func conversationKeepsLatestRequest() throws {
        let sourceID = UUID()
        var session = AnchorSession(goal: AnchorGoal(title: "Anchor", completionCriteria: "Done"))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let records: [(String, String, Double, String?)] = [
            ("turn-1", "task_complete", 0, "Make the cards swap"),
            ("turn-2", "task_complete", 10, "Soften the voice"),
            ("turn-3", "task_started", 20, nil),
        ]
        for (turn, lifecycle, offset, request) in records {
            let line = #"{"timestamp":"\#(ISO8601DateFormatter().string(from: base.addingTimeInterval(offset)))","type":"event_msg","payload":{"type":"\#(lifecycle)","turn_id":"\#(turn)"}}"#
            let event = try #require(CodexLifecycleRecord(json: Data(line.utf8)))
                .externalEvent(sessionID: session.id, sourceID: sourceID, title: "Anchor", end: nil, request: request)
            var process = event.process
            process.events = [try #require(event.event)]
            session.processes.append(process)
        }
        session.captureJoiningOrder()

        let presented = try #require(TaskDashboardPolicy.presentation(of: SessionProjection(session: session)).session)

        #expect(presented.processes.count == 1)
        #expect(presented.processes.first?.status == .running)
        #expect(presented.processes.first?.request == "Soften the voice")
    }

    private func metadata(threadSource: String?, originator: String = "Codex Desktop",
                          extra: String = "") -> CodexSessionMetadata? {
        CodexSessionMetadata(firstLine: sessionLog(id: "id", threadSource: threadSource,
                                                   originator: originator, extra: extra).prefix { $0 != 10 })
    }

    private func sessionLog(id: String, threadSource: String?, originator: String = "Codex Desktop",
                            extra: String = "") -> Data {
        let source = threadSource.map { #","thread_source":"\#($0)""# } ?? ""
        return Data(#"""
        {"timestamp":"2026-10-09T00:00:00.000Z","type":"session_meta","payload":{"id":"\#(id)","cwd":"/Users/example/Anchor","originator":"\#(originator)"\#(source)\#(extra)}}

        """#.utf8)
    }
}
