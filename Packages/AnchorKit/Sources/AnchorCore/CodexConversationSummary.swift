import Foundation

/// One Codex conversation as a person glances at it: its name, whether its
/// latest turn is still working, and what that turn reported when it ended.
///
/// Mac display data only. Unlike `CodexTaskCandidate`, a summary carries the
/// conversation's title and the opening of its latest reply, so it stays in
/// memory for the Mac dashboard and is never persisted, attached to an anchor,
/// or sent to another device.
public struct CodexConversationSummary: Identifiable, Hashable, Sendable {
    public enum State: Hashable, Sendable {
        /// The latest turn started and has not reported an end yet.
        case running(since: Date)
        case completed(at: Date, duration: TimeInterval?)
        /// The turn ended with an error Codex reported.
        case failed(at: Date, message: String?)
        /// The person stopped the turn.
        case interrupted(at: Date)
        /// The readable part of the log holds no turn yet.
        case unknown

        /// When the latest turn ended; `nil` while it runs or before any turn.
        public var endedAt: Date? {
            switch self {
            case .completed(let at, _), .failed(let at, _), .interrupted(let at): at
            case .running, .unknown: nil
            }
        }
    }

    public let candidate: CodexTaskCandidate
    /// Codex's own name for the thread when readable, else the first request.
    public let title: String?
    public let state: State
    /// The opening of the latest completed turn's reply, as plain text.
    public let reply: String?
    /// How the latest turn's tests ended, if it ran any (or "not tested" for a long turn).
    public let tests: TestOutcome?
    /// The agent asked the person something and is waiting for the answer.
    public let isWaitingForReply: Bool
    /// Next steps the latest reply suggested under a clear heading, for the
    /// person to add to their plan or not. Mac display only, like `reply`.
    public let suggestedSteps: [String]

    public var id: String { candidate.id }

    public init(candidate: CodexTaskCandidate, title: String?, state: State, reply: String?,
                tests: TestOutcome? = nil, isWaitingForReply: Bool = false, suggestedSteps: [String] = []) {
        self.candidate = candidate
        self.title = title
        self.state = state
        self.reply = reply
        self.tests = tests
        self.isWaitingForReply = isWaitingForReply
        self.suggestedSteps = suggestedSteps
    }

    func titled(_ newTitle: String?) -> Self {
        Self(candidate: candidate, title: newTitle ?? title, state: state, reply: reply,
             tests: tests, isWaitingForReply: isWaitingForReply, suggestedSteps: suggestedSteps)
    }
}

/// Display fields from the `task_complete` line that ended a turn.
struct CodexTurnEnd {
    let reply: String?
    let hasError: Bool
    let errorMessage: String?
    let duration: TimeInterval?

    init(reply: String?, hasError: Bool, errorMessage: String?, duration: TimeInterval?) {
        self.reply = reply
        self.hasError = hasError
        self.errorMessage = errorMessage
        self.duration = duration
    }

    init?(json data: Data) {
        guard let payload = try? JSONDecoder().decode(Envelope.self, from: data).payload else { return nil }
        reply = payload.reply
        hasError = payload.hasError
        errorMessage = payload.errorMessage
        duration = payload.duration
    }

    private struct Envelope: Decodable {
        let payload: Payload
    }

    private struct Payload: Decodable {
        let reply: String?
        let hasError: Bool
        let errorMessage: String?
        let duration: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case reply = "last_agent_message"
            case error
            case duration = "duration_ms"
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            reply = try? values.decodeIfPresent(String.self, forKey: .reply)
            duration = (try? values.decodeIfPresent(Double.self, forKey: .duration)).map { $0 / 1_000 }
            // `error` is null on success and an object with a message on failure.
            hasError = values.contains(.error) && (try? values.decodeNil(forKey: .error)) == false
            errorMessage = (try? values.decodeIfPresent(ErrorPayload.self, forKey: .error))?.message
        }
    }

    private struct ErrorPayload: Decodable {
        let message: String?

        enum CodingKeys: String, CodingKey { case message }

        init(from decoder: any Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                message = text
                return
            }
            message = try? decoder.container(keyedBy: CodingKeys.self)
                .decodeIfPresent(String.self, forKey: .message)
        }
    }
}

/// Plain one-glance text from Markdown: the opening prose without code,
/// tables, link targets or emphasis markers.
enum CodexGlanceText {
    static let replyLength = 360
    static let requestLength = 200
    static let titleLength = 80

    static func reply(from markdown: String) -> String? {
        var prose: [String] = []
        var labels: [String] = []
        var length = 0
        var inCodeBlock = false
        for rawLine in markdown.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                inCodeBlock.toggle()
                continue
            }
            guard !inCodeBlock, !line.hasPrefix("|") else { continue }
            let text = plain(line)
            // Rules such as `---` and decoration-only lines carry no words.
            guard text.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            // Headings and bold-only lines usually label a section ("Summary"),
            // so they stand in only for a reply that has nothing else.
            if line.hasPrefix("#") || line.wholeMatch(of: /\*\*[^*]+\*\*:?/) != nil {
                labels.append(text)
                continue
            }
            prose.append(text)
            length += text.count + 1
            if length >= replyLength { break }
        }
        return capped((prose.isEmpty ? labels : prose).joined(separator: " "), at: replyLength)
    }

    /// Up to three next steps a reply lists under a heading such as "Next
    /// steps" or "下一步". Without such a heading a reply suggests nothing:
    /// following an agent's plan is the person's choice, so precision first.
    static func suggestedSteps(from markdown: String) -> [String] {
        var steps: [String] = []
        var underHeading = false
        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if underHeading {
                if line.isEmpty { if steps.isEmpty { continue } else { break } }
                guard line.wholeMatch(of: /(?:[-*+]|\d+[.)、])\s+.+/) != nil else { break }
                if let step = capped(plain(line), at: titleLength) { steps.append(step) }
                if steps.count == 3 { break }
            } else if isNextStepsHeading(line) {
                underHeading = true
                steps = []
            }
        }
        return steps
    }

    private static func isNextStepsHeading(_ line: String) -> Bool {
        let text = plain(line).trimmingCharacters(in: CharacterSet(charactersIn: ":：").union(.whitespaces))
        guard !text.isEmpty, text.count <= 40 else { return false }
        let lower = text.lowercased()
        return lower.contains("next step") || lower.contains("follow-up") || lower.contains("follow up")
            || text.contains("下一步") || text.contains("后续") || text.contains("接下来")
    }

    /// The opening of a request as one plain paragraph, for the desk board.
    static func request(from text: String) -> String? {
        let lines = text.split(whereSeparator: \.isNewline)
            .map { plain($0.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.isEmpty }
        return capped(lines.joined(separator: " ").replacing(/\s+/, with: " "), at: requestLength)
    }

    static func title(from request: String) -> String? {
        guard let line = request.split(whereSeparator: \.isNewline).lazy
            .map({ plain($0.trimmingCharacters(in: .whitespaces)) })
            .first(where: { !$0.isEmpty }) else { return nil }
        return capped(line.replacing(/\s+/, with: " "), at: titleLength)
    }

    private static func plain(_ line: String) -> String {
        line
            // Headings, quotes, bullets, task boxes and numbered items.
            .replacing(/^(?:#{1,6}\s+|>\s*|[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+)/, with: "")
            // Links and images keep their words, not their targets.
            .replacing(/!?\[([^\]]*)\]\([^)]*\)/) { $0.output.1 }
            .replacing(/\*\*|__|`/, with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func capped(_ text: String, at limit: Int) -> String? {
        guard !text.isEmpty else { return nil }
        return text.count > limit ? String(text.prefix(limit - 1)) + "…" : text
    }
}

/// Codex's own thread names from `session_index.jsonl` beside `sessions`.
/// It is readable only when the person granted the whole `.codex` folder;
/// otherwise titles fall back to each conversation's first request.
struct CodexThreadNames: Sendable {
    private let indexURL: URL?
    private var stamp: CodexSessionFileMetadata?
    private(set) var names: [String: String] = [:]

    init(sessionsRootURL: URL) {
        indexURL = sessionsRootURL.lastPathComponent == "sessions"
            ? sessionsRootURL.deletingLastPathComponent().appending(path: "session_index.jsonl")
            : nil
    }

    mutating func refresh() {
        guard let indexURL,
              let values = try? indexURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
              let date = values.contentModificationDate else {
            stamp = nil
            names = [:]
            return
        }
        let current = CodexSessionFileMetadata(
            fileURL: indexURL,
            contentModificationDate: date,
            fileSize: UInt64(max(0, values.fileSize ?? 0))
        )
        guard current != stamp else { return }
        stamp = current
        guard let data = try? Data(contentsOf: indexURL) else {
            names = [:]
            return
        }
        var latest: [String: String] = [:]
        for line in data.split(separator: 10, omittingEmptySubsequences: true) {
            guard let entry = try? JSONDecoder().decode(Entry.self, from: line),
                  let name = CodexGlanceText.title(from: entry.name) else { continue }
            // The index is append-only, so a later line is a rename.
            latest[entry.id] = name
        }
        names = latest
    }

    private struct Entry: Decodable {
        let id: String
        let name: String

        enum CodingKeys: String, CodingKey {
            case id
            case name = "thread_name"
        }
    }
}
