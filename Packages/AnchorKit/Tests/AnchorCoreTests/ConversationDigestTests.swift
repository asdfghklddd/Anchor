import Foundation
import Testing
@testable import AnchorCore

@Suite("Conversation digests")
struct ConversationDigestTests {
    private typealias Round = ConversationTranscript.Round

    private static func log(_ lines: [[String: Any]]) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "digest-\(UUID().uuidString).jsonl")
        let data = try lines.map { try JSONSerialization.data(withJSONObject: $0) }
            .reduce(into: Data()) { $0.append($1); $0.append(10) }
        try data.write(to: url)
        return url
    }

    @Test("A Claude Code log yields its files, commands and the reply around them")
    func readsToolUse() throws {
        let url = try Self.log([
            ["type": "user", "sessionId": "s", "message": ["role": "user", "content": "把投锚页面的放弃草稿删掉，改成左上角确认"]],
            ["type": "assistant", "sessionId": "s", "message": ["role": "assistant", "content": [
                ["type": "text", "text": "Looking at the sheet."],
                ["type": "tool_use", "id": "t1", "name": "Edit", "input": ["file_path": "/repo/Sheet.swift"]],
            ]]],
            ["type": "assistant", "sessionId": "s", "message": ["role": "assistant", "content": [
                ["type": "tool_use", "id": "t2", "name": "Bash", "input": ["command": "git commit -m fix"]],
            ]]],
            ["type": "assistant", "sessionId": "s", "message": ["role": "assistant", "stop_reason": "end_turn", "content": [
                ["type": "text", "text": "**The draft button is gone, committed as 1409400.** It isn't pushed."],
            ]]],
        ])
        defer { try? FileManager.default.removeItem(at: url) }
        let transcript = try #require(ConversationTranscript.read(at: url))
        #expect(transcript.rounds.count == 1)
        #expect(transcript.rounds[0].files == ["/repo/Sheet.swift"])
        #expect(transcript.rounds[0].commands == ["git commit -m fix"])
        let digest = ConversationDigest(transcript, title: nil)
        #expect(digest.path == ["The draft button is gone, committed as…"])
        #expect(digest.facts == [.committed("1409400"), .notPushed, .filesChanged(1)])
        #expect(digest.cues == ["Sheet.swift"])
    }

    @Test("Following a growing log reads only what was added, and matches a fresh read")
    func follows() throws {
        let first: [[String: Any]] = [
            ["type": "user", "sessionId": "s", "message": ["role": "user", "content": "把卡片阴影改淡一点"]],
            ["type": "assistant", "sessionId": "s", "message": ["role": "assistant", "content": [["type": "text", "text": "改好了。"]]]],
        ]
        let url = try Self.log(first)
        defer { try? FileManager.default.removeItem(at: url) }
        var follower: ConversationTranscript.Follower?
        #expect(ConversationTranscript.follow(url, with: &follower)?.rounds.count == 1)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        let more = try JSONSerialization.data(withJSONObject: ["type": "user", "sessionId": "s", "message": ["role": "user", "content": "再把圆角改大一点"]])
        // Half a line first: it waits until the rest is written.
        try handle.write(contentsOf: more.prefix(20))
        #expect(ConversationTranscript.follow(url, with: &follower)?.rounds.count == 1)
        try handle.write(contentsOf: more.dropFirst(20) + Data([10]))
        try handle.close()
        let followed = ConversationTranscript.follow(url, with: &follower)
        #expect(followed?.rounds.map(\.request) == ["把卡片阴影改淡一点", "再把圆角改大一点"])
        #expect(followed == ConversationTranscript.read(at: url))
    }

    @Test("A Codex patch and command count toward the round")
    func readsCodexTools() throws {
        let patch = "*** Begin Patch\n*** Update File: /repo/App/Card.swift\n@@\n-old\n+new\n*** End Patch"
        let url = try Self.log([
            ["type": "session_meta", "payload": ["id": "x"]],
            ["type": "event_msg", "payload": ["type": "user_message", "message": "修一下卡片的阴影"]],
            ["type": "response_item", "payload": ["type": "custom_tool_call", "name": "exec",
                                                  "input": #"tools.exec_command({"cmd":"swift test"})"#]],
            ["type": "response_item", "payload": ["type": "custom_tool_call", "name": "apply_patch", "input": patch]],
            ["type": "event_msg", "payload": ["type": "agent_message", "message": "阴影改好了，测试全部通过。"]],
        ])
        defer { try? FileManager.default.removeItem(at: url) }
        let transcript = try #require(ConversationTranscript.read(at: url))
        #expect(transcript.rounds[0].files == ["/repo/App/Card.swift"])
        #expect(transcript.rounds[0].commands.contains("swift test"))
        let digest = ConversationDigest(transcript, title: nil)
        #expect(digest.facts == [.testsPassed, .filesChanged(1)])
    }

    @Test("A question at the end of the reply is what waits on the person")
    func question() {
        let reply = "**I compared both orientations.**\nThe desk keeps its colors.\nShould portrait show the faces too, or only the landscape desk?"
        let digest = ConversationDigest(ConversationTranscript(rounds: [Round(request: "refer to this HTML to polish the iOS design system", reply: reply)]),
                                        title: nil)
        #expect(digest.waiting == .init(kind: .answer, text: "Should portrait show the faces too, or only the landscape desk？"))
    }

    @Test("A request to try something is something to do")
    func act() {
        let reply = "等距 70 版做好了，放在 Deliverables 里。\n还是建议先打印一张折一下，主要看最里面那片能不能压平。"
        let digest = ConversationDigest(ConversationTranscript(rounds: [Round(request: "帮我单独另外做一份70-70等距的版本", reply: reply)]),
                                        title: nil)
        #expect(digest.waiting?.kind == .act)
        #expect(digest.path == ["等距 70 版做好了，放在 Deliverables 里"])
    }

    @Test("Short follow-ups belong to the request before them")
    func followUps() {
        let rounds = [
            Round(request: "重构 notch 区域的鼠标悬停效果，让两侧更窄一点", reply: "改好了。", files: ["/a/Island.swift"]),
            Round(request: "commit", reply: "**Committed as cb7d21a.** Not pushed.", commands: ["git commit -m island"]),
        ]
        let digest = ConversationDigest(ConversationTranscript(rounds: rounds), title: "macOS 插件 UI 重构")
        #expect(digest.facts == [.committed("cb7d21a"), .notPushed, .filesChanged(1)])
        #expect(digest.latestRequest == "重构 notch 区域的鼠标悬停效果，让两侧更窄一点")
        #expect(digest.path == ["改好了", "Committed as cb7d21a"])
    }

    @Test("A stated choice is kept in the person's words")
    func decision() {
        let rounds = [
            Round(request: "我们来讨论主页的设计", reply: "有三个方案。"),
            Round(request: "采纳方案B 但是右边要显示步骤", reply: "好的，按 B 做。"),
        ]
        #expect(ConversationDigest(ConversationTranscript(rounds: rounds), title: nil).decision == "采纳方案B 但是右边要显示步骤")
    }

    @Test("Keywords are the person's recurring nouns, not the conversation's name")
    func keywords() {
        let rounds = [
            Round(request: "折页的背面要放二维码，折页展开后背面是地图"),
            Round(request: "背面的二维码再大一点"),
        ]
        let words = ConversationDigest(ConversationTranscript(rounds: rounds), title: "折页设计").keywords
        #expect(words.contains("背面"))
        #expect(words.contains("二维码"))
        #expect(!words.contains("折页"))
    }

    @Test("An interrupted turn says so")
    func interrupted() {
        let digest = ConversationDigest(ConversationTranscript(rounds: [Round(request: "add more flowcharts to the portfolio", interrupted: true)]),
                                        title: nil)
        #expect(digest.facts == [.interrupted])
    }

    /// Prints digests of real logs listed in ANCHOR_DIGEST_LOGS (newline-separated paths); skipped otherwise.
    @Test("Real logs, when asked", .enabled(if: ProcessInfo.processInfo.environment["ANCHOR_DIGEST_LOGS"] != nil))
    func realLogs() throws {
        let paths = (ProcessInfo.processInfo.environment["ANCHOR_DIGEST_LOGS"] ?? "").split(separator: "\n")
        let started = Date.now
        var lines: [String] = []
        var reading = 0.0
        for path in paths {
            let readStart = Date.now
            let transcript = ConversationTranscript.read(at: URL(filePath: String(path)))
            reading += Date.now.timeIntervalSince(readStart)
            let digest = transcript.map { ConversationDigest($0, title: nil) }
            let data = try JSONEncoder().encode(digest)
            lines.append(String(decoding: data, as: UTF8.self))
        }
        let total = Date.now.timeIntervalSince(started) * 1000
        let count = Double(max(1, paths.count))
        lines.append("{\"msEach\": \(total / count), \"readingMsEach\": \(reading * 1000 / count)}")
        let out = ProcessInfo.processInfo.environment["ANCHOR_DIGEST_OUT"] ?? "/dev/stdout"
        try lines.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
    }
}
