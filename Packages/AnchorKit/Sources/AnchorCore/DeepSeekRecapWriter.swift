import Foundation

/// Writes conversation recaps with DeepSeek's chat API. The key is read from
/// the Keychain each time, so setting or changing it in Settings takes effect
/// at the next return; without one, recaps fall back to the latest request.
public struct DeepSeekRecapWriter: ConversationRecapWriting {
    public static let model = "deepseek-flash"
    static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    private let apiKey: @Sendable () async -> String?
    private let session: URLSession

    public init(apiKey: @escaping @Sendable () async -> String?, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public enum Failure: Error {
        case noKey
        case status(Int)
        case emptyAnswer
    }

    public func recap(_ facts: ConversationRecapFacts) async throws -> String {
        guard let key = await apiKey(), !key.isEmpty else { throw Failure.noKey }
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(
            model: Self.model,
            messages: [
                Body.Message(role: "system", content: Self.instructions),
                Body.Message(role: "user", content: Self.prompt(for: facts)),
            ],
            max_tokens: 300,
            temperature: 0.3,
            stream: false
        ))
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
            throw Failure.status(http.statusCode)
        }
        let answer = try JSONDecoder().decode(Answer.self, from: data).choices.first?.message.content
        let text = (answer ?? "")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”「」'").union(.whitespaces))
        guard !text.isEmpty else { throw Failure.emptyAnswer }
        return text
    }

    static let instructions = """
    你为 Anchor 写对话回溯摘要。读者离开电脑一段时间后回来，要一眼看懂这个 AI 对话在做什么、最近几轮做了什么、现在停在哪里，好立刻接着干。
    要求：
    - 不超过60个字（一个汉字或一个英文单词算一个字），一段话，不换行，不用列表、引号或 Markdown。
    - 先说这个对话整体在做什么，再说最近几轮做了或完成了什么，最后说现在的状态，例如等你确认、正在运行、已完成待验收、报错待修。
    - 用对话里主要使用的语言。
    - 只写对话里有的内容，不猜测，不评价。
    - 不要以“这个对话”“该对话”开头。
    只输出摘要本身。
    """

    static func prompt(for facts: ConversationRecapFacts) -> String {
        var lines = [
            "任务：\(facts.taskTitle)",
            "对话名称：\(facts.conversationName)",
            "当前状态：\(facts.isRunning ? "AI 正在运行" : "AI 已停下")",
            "最近 \(facts.transcript.rounds.count) 轮（从旧到新）：",
        ]
        for (index, round) in facts.transcript.rounds.enumerated() {
            lines.append("[\(index + 1)] 用户：\(round.request)")
            lines.append("    AI：\(round.reply ?? "（还没有回复）")")
        }
        return lines.joined(separator: "\n")
    }

    private struct Body: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let max_tokens: Int
        let temperature: Double
        let stream: Bool
    }

    private struct Answer: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }

        let choices: [Choice]
    }
}
