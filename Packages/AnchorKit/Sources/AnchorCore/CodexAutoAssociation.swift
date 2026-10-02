import Foundation

/// Local keyword matching. Conversation text is read transiently and is never
/// copied into a projection, sync event, or persistent matching index.
public enum CodexAutoAssociation {

    public static func matchingSession(
        text: String, conversationStartedAt: Date, sessions: [AnchorSession], now: Date = .now
    ) -> UUID? {
        guard conversationStartedAt <= now else { return nil }
        let words = tokens(text)
        let ranked = sessions.filter {
            $0.status == .active && conversationStartedAt >= $0.startedAt
        }.compactMap { session -> (UUID, Double)? in
            let title = tokens(session.goal.title)
            let shared = title.intersection(words).count
            guard !title.isEmpty, shared >= min(3, title.count) else { return nil }
            let coverage = Double(shared) / Double(title.count)
            guard coverage >= 0.5 else { return nil }
            let context = tokens(session.goal.completionCriteria + " " + (session.goal.userPlan?.steps.joined(separator: " ") ?? ""))
            let contextCoverage = context.isEmpty ? 0 : Double(context.intersection(words).count) / Double(context.count)
            return (session.id, coverage * 0.85 + contextCoverage * 0.15)
        }.sorted { $0.1 > $1.1 }
        guard let best = ranked.first else { return nil }
        // Similar tasks remain candidates rather than silently choosing one.
        if ranked.count > 1 && best.1 - ranked[1].1 < 0.15 { return nil }
        return best.0
    }

    public static func firstUserRequest(at url: URL) -> String? {
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
        for data in chunks {
            for line in data.split(separator: 10) {
                guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                      let payload = object["payload"] as? [String: Any] else { continue }
                let message: String?
                if object["type"] as? String == "event_msg", payload["type"] as? String == "user_message" {
                    message = payload["message"] as? String
                } else if object["type"] as? String == "response_item",
                          payload["type"] as? String == "message", payload["role"] as? String == "user",
                          let content = payload["content"] as? [[String: Any]] {
                    message = content.filter { $0["type"] as? String == "input_text" }
                        .compactMap { $0["text"] as? String }.joined(separator: "\n")
                } else { message = nil }
                guard let message else { continue }
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      !trimmed.hasPrefix("<environment_context>"),
                      !trimmed.hasPrefix("# AGENTS.md instructions"),
                      !trimmed.hasPrefix("<permissions instructions>"),
                      !trimmed.hasPrefix("<turn_aborted>") else { continue }
                return String(trimmed.prefix(8_000))
            }
        }
        return nil
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
