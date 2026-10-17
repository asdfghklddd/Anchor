import Foundation

/// Local keyword matching. Conversation text is read transiently and is never
/// copied into a projection, sync event, or persistent matching index.
public enum CodexAutoAssociation {

    public static func matchingSession(
        text: String, conversationStartedAt: Date, sessions: [AnchorSession], now: Date = .now
    ) -> UUID? {
        guard conversationStartedAt <= now else { return nil }
        let ranked = rankedSessions(text: text, sessions: sessions.filter { conversationStartedAt >= $0.startedAt })
        guard let best = ranked.first else { return nil }
        // Similar tasks remain candidates rather than silently choosing one.
        if ranked.count > 1 && best.1 - ranked[1].1 < 0.15 { return nil }
        return best.0
    }

    /// Suggestions require confirmation, so existing conversations and ambiguous
    /// task names can be offered without silently assigning an owner.
    public static func suggestedSessionIDs(text: String, sessions: [AnchorSession]) -> [UUID] {
        rankedSessions(text: text, sessions: sessions).map(\.0)
    }

    private static func rankedSessions(text: String, sessions: [AnchorSession]) -> [(UUID, Double)] {
        let words = tokens(text)
        return sessions.filter { $0.status == .active }.compactMap { session -> (UUID, Double)? in
            let title = tokens(session.goal.title)
            let shared = title.intersection(words).count
            guard !title.isEmpty, shared >= min(3, title.count) else { return nil }
            let coverage = Double(shared) / Double(title.count)
            guard coverage >= 0.5 else { return nil }
            let context = tokens(session.goal.completionCriteria + " " + (session.goal.userPlan?.steps.joined(separator: " ") ?? ""))
            let contextCoverage = context.isEmpty ? 0 : Double(context.intersection(words).count) / Double(context.count)
            return (session.id, coverage * 0.85 + contextCoverage * 0.15)
        }.sorted { $0.1 == $1.1 ? $0.0.uuidString < $1.0.uuidString : $0.1 > $1.1 }
    }

    public static func latestUserRequest(at url: URL) -> String? {
        userRequest(at: url, latest: true)
    }

    public static func firstUserRequest(at url: URL) -> String? {
        userRequest(at: url, latest: false)
    }

    private static func userRequest(at url: URL, latest: Bool) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // Bounded header + tail covers large injected setup context. Only a
        // user request counts (lifecycle or response-item format), never assistant/tool text.
        guard let size = try? handle.seekToEnd() else { return nil }
        let limit: UInt64 = 512 * 1_024
        var chunks: [Data] = []
        for offset in Set([UInt64(0), size > limit ? size - limit : 0]).sorted() {
            guard (try? handle.seek(toOffset: offset)) != nil,
                  var data = try? handle.read(upToCount: Int(limit)) else { continue }
            if offset > 0, let newline = data.firstIndex(of: 10) { data.removeSubrange(...newline) }
            chunks.append(data)
        }
        for data in (latest ? Array(chunks.reversed()) : chunks) {
            let lines = data.split(separator: 10)
            for line in (latest ? Array(lines.reversed()) : Array(lines)) {
                guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                      let payload = object["payload"] as? [String: Any] else { continue }
                let items: [String]
                if object["type"] as? String == "event_msg", payload["type"] as? String == "user_message",
                   let message = payload["message"] as? String {
                    items = [message]
                } else if object["type"] as? String == "response_item",
                          payload["type"] as? String == "message", payload["role"] as? String == "user",
                          let content = payload["content"] as? [[String: Any]] {
                    items = content.filter { $0["type"] as? String == "input_text" }
                        .compactMap { $0["text"] as? String }
                } else { continue }
                let request = items.compactMap(userWords(in:)).joined(separator: "\n")
                guard !request.isEmpty else { continue }
                return String(request.prefix(8_000))
            }
        }
        return nil
    }

    private static let injectedPrefixes = [
        "<environment_context>", "# AGENTS.md instructions", "<permissions instructions>", "<turn_aborted>",
        "# Files mentioned by the user", "## Referenced ChatGPT conversation",
    ]

    /// The words a person typed in one message item. Codex attaches context as
    /// tagged envelopes (an open page) or headed sections (mentioned files, a
    /// referenced ChatGPT chat); a section that ends in "## My request…" carries
    /// the request after that heading.
    static func userWords(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let heading = trimmed.ranges(of: /(?m)^#{1,3} My request[^\n]*\n/).last {
            let request = trimmed[heading.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return request.isEmpty ? nil : request
        }
        guard !trimmed.isEmpty,
              !injectedPrefixes.contains(where: trimmed.hasPrefix),
              trimmed.wholeMatch(of: /<([A-Za-z_][\w\-]*)>[\s\S]*<\/\1>/) == nil else { return nil }
        return trimmed
    }

    private static func tokens(_ text: String) -> Set<String> {
        let stop: Set<String> = ["the", "and", "for", "with", "this", "that", "please", "帮我", "一下", "一个", "任务", "完成", "进行", "需要", "我们", "这个", "然后", "确认"]
        var result = Set<String>()
        var latin = ""
        var previousHan: Character?
        func flush() { if latin.count >= 3 { result.insert(latin) }; latin = "" }
        for c in text.lowercased() {
            let han = c.unicodeScalars.contains { (0x3400...0x9fff).contains(Int($0.value)) }
            if han {
                flush()
                if let previousHan { result.insert(String([previousHan, c])) }
                previousHan = c
            } else {
                previousHan = nil
                if c.isASCII && (c.isLetter || c.isNumber) { latin.append(c) } else { flush() }
            }
        }
        flush()
        return result.subtracting(stop)
    }
}
