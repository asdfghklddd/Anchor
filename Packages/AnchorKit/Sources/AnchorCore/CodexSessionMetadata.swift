import Foundation

/// Routing facts from the first `session_meta` line of a Codex session log:
/// identity, creation time, workspace folder name and who started the thread.
/// Instructions, prompts and absolute paths are not retained.
public struct CodexSessionMetadata: Hashable, Sendable {
    public let id: String
    public let createdAt: Date?
    public let workspaceName: String?
    public let originator: String?
    public let threadSource: String?
    public let isSubagent: Bool

    /// Threads a person started in Codex or handed off from a ChatGPT chat.
    /// Guardian reviews and spawned subagents are machine work on another
    /// thread, so they never become candidates or automatic matches.
    public var isUserConversation: Bool {
        guard !isSubagent else { return false }
        // Logs written before `thread_source` existed only contain user threads.
        guard let threadSource else { return true }
        return Self.userThreadSources.contains(threadSource)
    }

    /// The desktop app is branded ChatGPT; CLI and editor clients remain Codex.
    public var sourceName: String {
        if originator == Self.claudeCodeOriginator { return Self.claudeCodeOriginator }
        return originator?.localizedCaseInsensitiveContains("desktop") == true ? "ChatGPT" : "Codex"
    }

    public static let claudeCodeOriginator = "Claude Code"

    static let userThreadSources: Set<String> = ["user", "chatgpt_handoff"]

    public static func read(from url: URL) -> CodexSessionMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 256 * 1_024),
              let newline = data.firstIndex(of: 10) else {
            return nil
        }
        return CodexSessionMetadata(firstLine: data[..<newline]) ?? claudeCode(url: url, head: data)
    }

    /// A Claude Code session: its ID, folder and start from its first entries.
    /// Sub-agent logs live in a `subagents` folder or mark their entries as a sidechain.
    static func claudeCode(url: URL, head: Data) -> CodexSessionMetadata? {
        struct Entry: Decodable {
            let sessionId: String?
            let cwd: String?
            let timestamp: String?
            let isSidechain: Bool?
        }
        var id: String?
        var cwd: String?
        var createdAt: Date?
        var sidechain = false
        for line in head.split(separator: 10, omittingEmptySubsequences: true).prefix(200) {
            guard let entry = try? JSONDecoder().decode(Entry.self, from: Data(line)) else { continue }
            id = id ?? entry.sessionId
            if createdAt == nil, let stamp = entry.timestamp {
                createdAt = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(stamp)
            }
            if cwd == nil, let folder = entry.cwd {
                cwd = folder
                sidechain = entry.isSidechain == true
            }
            if id != nil, cwd != nil, createdAt != nil { break }
        }
        guard let id, !id.isEmpty else { return nil }
        return CodexSessionMetadata(
            id: id, createdAt: createdAt,
            workspaceName: cwd.map { URL(filePath: $0, directoryHint: .isDirectory).lastPathComponent },
            originator: claudeCodeOriginator, threadSource: nil,
            isSubagent: sidechain || url.pathComponents.contains("subagents")
        )
    }

    private init(id: String, createdAt: Date?, workspaceName: String?, originator: String?,
                 threadSource: String?, isSubagent: Bool) {
        self.id = id
        self.createdAt = createdAt
        self.workspaceName = workspaceName
        self.originator = originator
        self.threadSource = threadSource
        self.isSubagent = isSubagent
    }

    init?(firstLine: Data) {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: firstLine),
              envelope.type == "session_meta",
              !envelope.payload.id.isEmpty else {
            return nil
        }
        let payload = envelope.payload
        id = payload.id
        createdAt = envelope.timestamp.flatMap { value in
            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return parser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        }
        workspaceName = payload.cwd.map {
            URL(filePath: $0, directoryHint: .isDirectory).lastPathComponent
        }
        originator = payload.originator
        threadSource = payload.threadSource
        isSubagent = payload.parentThreadID != nil || payload.source?.isSubagent == true
    }

    private struct Envelope: Decodable {
        struct Payload: Decodable {
            let id: String
            let cwd: String?
            let originator: String?
            let threadSource: String?
            let parentThreadID: String?
            let source: Source?

            enum CodingKeys: String, CodingKey {
                case id, cwd, originator, source
                case threadSource = "thread_source"
                case parentThreadID = "parent_thread_id"
            }
        }

        /// `source` is a client name such as "vscode", or an object such as
        /// `{"subagent": {"other": "guardian"}}` for machine-started threads.
        struct Source: Decodable {
            let isSubagent: Bool

            init(from decoder: any Decoder) throws {
                let keys = (try? decoder.container(keyedBy: AnyKey.self))?.allKeys ?? []
                isSubagent = keys.contains { $0.stringValue == "subagent" }
            }
        }

        struct AnyKey: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        let type: String
        let timestamp: String?
        let payload: Payload
    }
}
