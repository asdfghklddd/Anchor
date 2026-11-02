import Foundation

/// A DeepSeek Harness session as its status file tells it. The harness keeps
/// each conversation in a zstd stream, and beside it a plain JSON status file
/// (`~/.dsh/storages/session_projcache/sessions/<id>.json`) that it rewrites
/// as a turn starts and ends. Anchor reads only that file: the turn state,
/// working time, tokens and, per turn, the request and the reply's opening.
public struct HarnessSessionStatus: Hashable, Sendable {
    public struct Turn: Hashable, Sendable {
        public let number: Int
        public let request: String
        /// The harness keeps the reply's first 120 characters.
        public let reply: String
    }

    public static let originator = "DeepSeek Harness"
    public static let sourceName = "DeepSeek"
    /// The status files' folder, under the person's home.
    public static let rootPath = ".dsh/storages/session_projcache/sessions"

    public let id: String
    public let workspacePath: String?
    public let createdAt: Date?
    /// When the person last sent something.
    public let lastRequestAt: Date?
    public let title: String?
    /// Oldest first.
    public let turns: [Turn]
    /// The number of the latest turn, running or not; 0 before any.
    public let latestTurn: Int
    public let isTurnOpen: Bool
    /// Questions the agent asked with its ask tool that wait for an answer.
    public let openQuestions: Int
    /// Questions answered in this session so far.
    public let answeredQuestions: Int
    /// The model's and tools' time across every turn.
    public let workedSeconds: TimeInterval
    /// Fresh input, cache writes and output; cached reads repeat context already paid for.
    public let tokens: Int
    /// A sub-agent the harness ran for another session.
    public let isSubagent: Bool
    /// Opened but never asked anything.
    public let isBlank: Bool

    public var workspaceName: String? {
        workspacePath.map { URL(filePath: $0, directoryHint: .isDirectory).lastPathComponent }
    }

    /// A conversation the person had: not a sub-agent, not an empty window.
    public var isUserConversation: Bool { !isSubagent && !isBlank }

    public static func isStatusFile(_ url: URL) -> Bool {
        url.pathExtension == "json" && url.deletingLastPathComponent().lastPathComponent == "sessions"
            && url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent == "session_projcache"
    }

    public init?(contentsOf url: URL) {
        guard Self.isStatusFile(url), let data = try? Data(contentsOf: url) else { return nil }
        self.init(data: data, id: url.deletingPathExtension().lastPathComponent)
    }

    init?(data: Data, id fileStem: String) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let record = object["record"] as? [String: Any],
              let rows = record["rows"] as? [String: Any] else { return nil }
        func value(_ row: String) -> Any? { (rows[row] as? [String: Any])?["val"] }
        func dictionary(_ row: String) -> [String: Any] { value(row) as? [String: Any] ?? [:] }
        func int(_ any: Any?) -> Int { (any as? NSNumber)?.intValue ?? 0 }
        func date(_ any: Any?) -> Date? {
            (any as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1_000) }
        }

        let identity = record["identity"] as? [String: Any] ?? [:]
        let stem = fileStem.hasPrefix("session-") ? String(fileStem.dropFirst("session-".count)) : fileStem
        id = stem.lowercased()
        workspacePath = (value("workingDirectory") as? String) ?? (identity["cwd"] as? String)
        createdAt = date(identity["createdAt"])
        lastRequestAt = date(dictionary("sessionListMetadata")["lastPromptAt"])
        isBlank = dictionary("sessionListMetadata")["blank"] as? Bool ?? false
        title = (value("title") as? String).flatMap { $0.isEmpty ? nil : $0 }

        let outline = dictionary("turnOutline")["turns"] as? [[String: Any]] ?? []
        turns = outline.map {
            Turn(number: int($0["turn"]), request: $0["prompt"] as? String ?? "", reply: $0["response"] as? String ?? "")
        }
        let boundary = dictionary("turnBoundary")
        latestTurn = int(boundary["lastTurn"])
        isTurnOpen = boundary["openTurnStartSeq"].map { !($0 is NSNull) } ?? false

        let questions = dictionary("userQuestions")["questions"] as? [String: Any] ?? [:]
        openQuestions = (questions["active"] as? [Any])?.count ?? 0
        answeredQuestions = (questions["settled"] as? [Any])?.count ?? 0

        let stats = dictionary("sessionStats")
        workedSeconds = Double(int(stats["llmMs"]) + int(stats["toolMs"])) / 1_000
        let totals = dictionary("tokenUsage")["totals"] as? [String: Any] ?? [:]
        tokens = int(totals["uncachedInputTokens"]) + int(totals["cacheWriteTokens"]) + int(totals["outputTokens"])
        isSubagent = !dictionary("subagent").isEmpty
    }

    /// The latest rounds, oldest first, for digests and return recaps.
    public func transcript(limit: Int = ConversationTranscript.roundLimit) -> ConversationTranscript? {
        let rounds = turns.filter { !$0.request.isEmpty || !$0.reply.isEmpty }.suffix(limit)
            .map { ConversationTranscript.Round(request: $0.request, reply: $0.reply.isEmpty ? nil : $0.reply) }
        return rounds.isEmpty ? nil : ConversationTranscript(rounds: Array(rounds))
    }

    /// The person's first or latest request.
    func request(latest: Bool) -> String? {
        let requests = turns.map(\.request).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return latest ? requests.last : requests.first
    }

    var latestReply: String? {
        turns.last(where: { $0.number == latestTurn }).flatMap { $0.reply.isEmpty ? nil : $0.reply }
    }

    /// Where the latest turn stands. A question the agent asked with its tool
    /// holds the turn open on the harness's side; for the person it waits on
    /// them, so each answered question begins a new stretch of the turn.
    struct Stretch: Hashable {
        let turnID: String
        let lifecycle: CodexLifecycleRecord.CodexLifecycle
        let waiting: Bool
    }

    var stretch: Stretch? {
        guard latestTurn > 0 else { return nil }
        let id = answeredQuestions == 0 ? "turn-\(latestTurn)" : "turn-\(latestTurn)-after-\(answeredQuestions)"
        if isTurnOpen {
            return openQuestions > 0
                ? Stretch(turnID: id, lifecycle: .completed, waiting: true)
                : Stretch(turnID: id, lifecycle: .started, waiting: false)
        }
        return Stretch(turnID: id, lifecycle: .completed, waiting: false)
    }
}

/// The recent DeepSeek Harness conversations under the status folder, read
/// as a glance needs them, like `CodexTaskSupervisor` does for Codex logs.
public actor DeepSeekHarnessSupervisor {
    private let rootURL: URL
    private let candidateLimit: Int
    private var cache: [URL: (modified: Date, summary: CodexConversationSummary?)] = [:]

    public init(rootURL: URL, candidateLimit: Int = 12) {
        self.rootURL = rootURL
        self.candidateLimit = max(1, candidateLimit)
    }

    public func summaries() -> [CodexConversationSummary] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = ((try? FileManager.default.contentsOfDirectory(
            at: rootURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? [])
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> (URL, Date)? in
                guard let modified = try? url.resourceValues(forKeys: Set(keys)).contentModificationDate else { return nil }
                return (url, modified)
            }
            .sorted { $0.1 == $1.1 ? $0.0.path < $1.0.path : $0.1 > $1.1 }
        cache = cache.filter { entry in files.contains { $0.0 == entry.key } }
        var summaries: [CodexConversationSummary] = []
        for (url, modified) in files where summaries.count < candidateLimit {
            let summary: CodexConversationSummary?
            if let cached = cache[url], cached.modified == modified {
                summary = cached.summary
            } else {
                summary = HarnessSessionStatus(contentsOf: url).flatMap { Self.summary($0, at: url, modified: modified) }
                cache[url] = (modified, summary)
            }
            if let summary { summaries.append(summary) }
        }
        return summaries
    }

    static func summary(_ status: HarnessSessionStatus, at url: URL, modified: Date) -> CodexConversationSummary? {
        guard status.isUserConversation else { return nil }
        let stretch = status.stretch
        let candidate = CodexTaskCandidate(
            id: status.id, fileURL: url, workspaceName: status.workspaceName,
            originator: HarnessSessionStatus.originator, modifiedAt: modified,
            activity: stretch.map { $0.lifecycle == .started || $0.waiting ? .running : .completed } ?? .unknown,
            activityObservedAt: stretch == nil ? nil : modified, createdAt: status.createdAt)
        let state: CodexConversationSummary.State
        var reply: String?
        var suggestions: [String] = []
        switch stretch {
        case nil:
            state = .unknown
        case let stretch? where stretch.lifecycle == .started || stretch.waiting:
            state = .running(since: status.lastRequestAt ?? modified)
        case _?:
            state = .completed(at: modified, duration: nil)
            reply = status.latestReply.flatMap { CodexGlanceText.reply(from: $0) }
            suggestions = status.latestReply.map { CodexGlanceText.suggestedSteps(from: $0) } ?? []
        }
        let firstRequest = status.request(latest: false).flatMap { CodexGlanceText.title(from: $0) }
        return CodexConversationSummary(
            candidate: candidate,
            title: status.title.flatMap { CodexGlanceText.title(from: $0) } ?? firstRequest,
            state: state, reply: reply, tests: nil,
            isWaitingForReply: stretch?.waiting == true,
            suggestedSteps: suggestions, firstRequest: firstRequest)
    }
}

/// Read-only DeepSeek Harness source for one conversation: it reads the
/// status file whenever it changes and reports where the latest turn stands,
/// as `CodexLifecycleFileSource` does from a log.
public struct DeepSeekHarnessSource: ProcessSource, Sendable {
    static let pollInterval: TimeInterval = 0.5
    static let restingPollInterval: TimeInterval = 2
    static let restingAfter: TimeInterval = 15

    public let fileURL: URL
    public let descriptor: SourceDescriptor
    public let conversationTitle: String?
    private let conversationName: (@Sendable () async -> String?)?
    public let stepID: UUID?
    private let sessionContextProvider: @Sendable () async -> ProcessSourceSessionContext?

    public init(fileURL: URL,
                sessionContextProvider: @escaping @Sendable () async -> ProcessSourceSessionContext?,
                descriptor: SourceDescriptor,
                conversationTitle: String? = nil,
                conversationName: (@Sendable () async -> String?)? = nil,
                stepID: UUID? = nil) {
        self.fileURL = fileURL
        self.sessionContextProvider = sessionContextProvider
        self.descriptor = descriptor
        self.conversationTitle = conversationTitle
        self.conversationName = conversationName
        self.stepID = stepID
    }

    public func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var lastModified: Date?
                var changedAt = Date.now
                // What was reported, so an unchanged turn is not sent again.
                var reported: Set<String> = []
                while !Task.isCancelled {
                    // Read afresh each time: a URL keeps the values it fetched once.
                    let modified = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))?[.modificationDate] as? Date
                    if let modified, modified != lastModified, let context = await sessionContextProvider() {
                        lastModified = modified
                        changedAt = .now
                        if let status = HarnessSessionStatus(contentsOf: fileURL) {
                            for event in await events(for: status, modified: modified, context: context)
                            where reported.insert(event.deduplicationKey ?? event.id.uuidString).inserted {
                                continuation.yield(event)
                            }
                        }
                    }
                    let resting = Date.now.timeIntervalSince(changedAt) > Self.restingAfter
                    do {
                        try await Task.sleep(for: .seconds(resting ? Self.restingPollInterval : Self.pollInterval))
                    } catch { break }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The latest turn's events: its start, and its end or the question that
    /// holds it. Turns before the task began belong to other work.
    func events(for status: HarnessSessionStatus, modified: Date,
                context: ProcessSourceSessionContext) async -> [ExternalProcessEvent] {
        guard status.isUserConversation, let stretch = status.stretch else { return [] }
        let startedAt = status.lastRequestAt ?? modified
        guard max(startedAt, modified) >= context.startedAt else { return [] }
        let name = await conversationName?()
        let title = name ?? status.title.flatMap { CodexGlanceText.title(from: $0) } ?? conversationTitle
            ?? HarnessSessionStatus.sourceName
        let request = status.request(latest: true).flatMap { CodexGlanceText.request(from: $0) }
        let digest = status.transcript().map { ConversationDigest($0, title: title) }.flatMap { $0.isEmpty ? nil : $0 }
        func event(_ lifecycle: CodexLifecycleRecord.CodexLifecycle, at date: Date, waiting: Bool) -> ExternalProcessEvent {
            let record = CodexLifecycleRecord(timestamp: date, lifecycle: lifecycle, turnID: stretch.turnID)
            let end = lifecycle == .completed
                ? CodexTurnEnd(reply: status.latestReply, hasError: false, errorMessage: nil, duration: nil) : nil
            return record.externalEvent(
                sessionID: context.sessionID, sourceID: descriptor.id, sourceName: descriptor.name,
                sourceSymbol: descriptor.symbol, sourceTone: descriptor.tone, title: title, end: end,
                stepID: stepID, waitingForReply: waiting, request: request,
                workedSeconds: status.workedSeconds, digest: digest)
        }
        var events = [event(.started, at: max(startedAt, context.startedAt), waiting: false)]
        if stretch.lifecycle == .completed {
            events.append(event(.completed, at: max(modified, startedAt), waiting: stretch.waiting))
        }
        return events
    }
}
