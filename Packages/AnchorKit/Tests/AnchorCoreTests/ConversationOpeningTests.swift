import Foundation
import Testing
@testable import AnchorCore

@Suite("Opening a conversation on the Mac")
struct ConversationOpeningTests {
    private static func log(_ lines: [[String: Any]]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "open-\(UUID().uuidString).jsonl")
        let data = try lines.map { try JSONSerialization.data(withJSONObject: $0) }
            .reduce(into: Data()) { $0.append($1); $0.append(10) }
        try data.write(to: url)
        return url
    }

    @Test("The request survives the wire and goes stale after half a minute")
    func request() throws {
        let asked = Date(timeIntervalSince1970: 1_000_000)
        let request = ConversationOpenRequest(conversation: UUID(), requestedAt: asked)
        let decoded = try #require(ConversationOpenRequest(envelope: request.envelope(sourceID: UUID())))
        #expect(decoded == request)
        #expect(decoded.isFresh(at: asked.addingTimeInterval(10)))
        #expect(!decoded.isFresh(at: asked.addingTimeInterval(45)))
    }

    @Test("Other envelopes are not open requests")
    func otherEnvelopes() throws {
        let activity = try DayActivity(tokens: [], links: []).envelope(sourceID: UUID())
        #expect(ConversationOpenRequest(envelope: activity) == nil)
    }

    @Test("A Codex log opens its thread")
    func codex() throws {
        let url = try Self.log([["type": "session_meta", "payload": ["id": "019a-thread", "originator": "codex_desktop"]]])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ConversationLink(logAt: url) == ConversationLink(url: URL(string: "codex://threads/019a-thread")!))
    }

    @Test("A Claude Code log opens the Code tab with its resume command")
    func claude() throws {
        let url = try Self.log([["type": "user", "sessionId": "5f1c-session", "cwd": "/Users/x/Anchor",
                                 "message": ["role": "user", "content": "hi"]]])
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(ConversationLink(logAt: url)
            == ConversationLink(url: URL(string: "claude://code")!, resumeCommand: "claude --resume 5f1c-session"))
    }
}
