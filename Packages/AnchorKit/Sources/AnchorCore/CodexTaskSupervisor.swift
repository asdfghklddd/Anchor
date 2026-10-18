import Foundation

public enum CodexTaskActivity: String, Codable, Hashable, Sendable {
    case running
    case completed
    case interrupted
    case unknown
}

/// Privacy-minimal candidate discovered from a Codex session file. It retains
/// no prompt, response, tool output, or absolute workspace path.
public struct CodexTaskCandidate: Identifiable, Hashable, Sendable {
    public let id: String
    public let fileURL: URL
    public let workspaceName: String?
    public let originator: String?
    public let modifiedAt: Date
    public let activity: CodexTaskActivity
    public let activityObservedAt: Date?
    public let createdAt: Date?

    public init(
        id: String,
        fileURL: URL,
        workspaceName: String?,
        originator: String?,
        modifiedAt: Date,
        activity: CodexTaskActivity,
        activityObservedAt: Date?,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.fileURL = fileURL
        self.workspaceName = workspaceName
        self.originator = originator
        self.modifiedAt = modifiedAt
        self.activity = activity
        self.activityObservedAt = activityObservedAt
        self.createdAt = createdAt
    }
}

public extension CodexTaskCandidate {
    /// Started in the desktop app (branded ChatGPT) rather than the CLI or an editor.
    var isFromDesktopApp: Bool {
        originator?.localizedCaseInsensitiveContains("desktop") == true
    }
}

/// Resident metadata supervisor for Codex Desktop session files. The stream is
/// a discovery surface; the Mac coordinator applies manual or high-confidence
/// automatic association separately.
public actor CodexTaskSupervisor {
    private struct CacheEntry {
        let metadata: CodexSessionFileMetadata
        /// `nil` for subagent or unreadable logs, so each is inspected once per change.
        let summary: CodexConversationSummary?
    }

    private let locator: CodexSessionFileLocator
    private let pollInterval: TimeInterval
    private let candidateLimit: Int
    private let discoveryWindow: Int
    private let maximumTailBytes: UInt64
    private var cache: [URL: CacheEntry] = [:]
    /// A first request never changes, so it is read once per conversation.
    private var requestTitles: [String: String] = [:]
    private var threadNames: CodexThreadNames

    public init(
        rootURL: URL,
        pollInterval: TimeInterval = 2,
        candidateLimit: Int = 12,
        discoveryWindow: Int? = nil,
        maximumTailBytes: UInt64 = 4 * 1_024 * 1_024
    ) {
        locator = CodexSessionFileLocator(rootURL: rootURL)
        threadNames = CodexThreadNames(sessionsRootURL: rootURL)
        self.pollInterval = max(0.25, pollInterval)
        self.candidateLimit = max(1, candidateLimit)
        // Guardian and subagent logs can outnumber user threads several times over.
        self.discoveryWindow = max(self.candidateLimit, discoveryWindow ?? self.candidateLimit * 6)
        self.maximumTailBytes = max(1_024, maximumTailBytes)
    }

    public func snapshot() -> [CodexTaskCandidate] {
        summaries().map(\.candidate)
    }

    /// The same recent user conversations as `snapshot()`, with what a glance
    /// needs: a title, the latest turn's state and the opening of its reply.
    public func summaries() -> [CodexConversationSummary] {
        let files = locator.recentSessionFiles(limit: discoveryWindow)
        let activeURLs = Set(files.map(\.fileURL))
        cache = cache.filter { activeURLs.contains($0.key) }
        threadNames.refresh()

        var summaries: [CodexConversationSummary] = []
        for metadata in files where summaries.count < candidateLimit {
            let summary: CodexConversationSummary?
            if let cached = cache[metadata.fileURL], cached.metadata == metadata {
                summary = cached.summary
            } else {
                summary = self.summary(for: metadata)
                cache[metadata.fileURL] = CacheEntry(metadata: metadata, summary: summary)
            }
            // Codex can rename a thread without writing to its log.
            if let summary { summaries.append(summary.titled(threadNames.names[summary.id])) }
        }
        let activeIDs = Set(summaries.map(\.id))
        requestTitles = requestTitles.filter { activeIDs.contains($0.key) }
        return summaries
    }

    public func snapshots() -> AsyncStream<[CodexTaskCandidate]> {
        let interval = pollInterval
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task { [weak self] in
                var previous: [CodexTaskCandidate]?
                while !Task.isCancelled {
                    guard let self else { return }
                    let current = await self.snapshot()
                    if current != previous {
                        continuation.yield(current)
                        previous = current
                    }
                    do {
                        try await Task.sleep(for: .seconds(interval))
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func summary(for metadata: CodexSessionFileMetadata) -> CodexConversationSummary? {
        guard let session = CodexSessionMetadata.read(from: metadata.fileURL),
              session.isUserConversation else {
            return nil
        }
        let latest = readLatestTurn(
            from: metadata.fileURL,
            fileSize: metadata.fileSize
        )
        let candidate = CodexTaskCandidate(
            id: session.id,
            fileURL: metadata.fileURL,
            workspaceName: session.workspaceName,
            originator: session.originator,
            modifiedAt: metadata.contentModificationDate,
            activity: latest.map { Self.activity($0.record) } ?? .unknown,
            activityObservedAt: latest?.record.timestamp,
            createdAt: session.createdAt
        )
        var reply: String?
        var tests: TestOutcome?
        var waiting = false
        let state: CodexConversationSummary.State
        if let latest {
            let at = latest.record.timestamp
            switch latest.record.lifecycle {
            case .started:
                state = .running(since: at)
                // Results so far; a held question means the turn waits on the person.
                tests = latest.facts.tests(duration: nil)
                waiting = latest.facts.isWaitingForReply(turnEnded: false)
            case .aborted:
                state = .interrupted(at: at)
            case .completed:
                let end = CodexTurnEnd(json: latest.line)
                tests = latest.facts.tests(duration: end?.duration)
                if end?.hasError == true {
                    state = .failed(at: at, message: end?.errorMessage.flatMap { CodexGlanceText.reply(from: $0) })
                } else {
                    state = .completed(at: at, duration: end?.duration)
                    reply = end?.reply.flatMap { CodexGlanceText.reply(from: $0) }
                    waiting = latest.facts.isWaitingForReply(turnEnded: true)
                }
            }
        } else {
            state = .unknown
        }
        return CodexConversationSummary(
            candidate: candidate,
            title: threadNames.names[session.id] == nil ? requestTitle(for: session.id, at: metadata.fileURL) : nil,
            state: state,
            reply: reply,
            tests: tests,
            isWaitingForReply: waiting
        )
    }

    private func requestTitle(for id: String, at url: URL) -> String? {
        if let title = requestTitles[id] { return title }
        // A brand-new log may not hold its request yet; look again on the next change.
        guard let request = CodexAutoAssociation.firstUserRequest(at: url),
              let title = CodexGlanceText.title(from: request) else { return nil }
        requestTitles[id] = title
        return title
    }

    /// The latest lifecycle record and its raw line, which also carries the
    /// turn's reply, duration and error when the record ends a turn, with
    /// what that turn's tool calls showed: its tests and any open question.
    private func readLatestTurn(
        from url: URL,
        fileSize: UInt64
    ) -> (record: CodexLifecycleRecord, line: Data, facts: CodexTurnFacts)? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let start = fileSize > maximumTailBytes ? fileSize - maximumTailBytes : 0
        do {
            try handle.seek(toOffset: start)
            guard var data = try handle.readToEnd(), !data.isEmpty else { return nil }
            if start > 0, let newline = data.firstIndex(of: 10) {
                data.removeSubrange(...newline)
            }
            var latest: (record: CodexLifecycleRecord, line: Data)?
            var facts = CodexTurnFacts()
            for line in data.split(separator: 10, omittingEmptySubsequences: true) {
                // Most lines are tool output; only a line naming a lifecycle is decoded as one.
                guard Self.lifecycleMarkers.contains(where: { line.range(of: $0) != nil }),
                      let record = CodexLifecycleRecord(json: Data(line)) else {
                    facts.consume(Data(line))
                    continue
                }
                if record.lifecycle == .started { facts.turnStarted() }
                if latest.map({ record.timestamp > $0.record.timestamp }) ?? true {
                    latest = (record, Data(line))
                }
            }
            return latest.map { ($0.record, $0.line, facts) }
        } catch {
            return nil
        }
    }

    private static let lifecycleMarkers = CodexLifecycleRecord.CodexLifecycle.allCases.map { Data($0.rawValue.utf8) }

    private static func activity(_ record: CodexLifecycleRecord) -> CodexTaskActivity {
        switch record.lifecycle {
        case .started: .running
        case .completed: .completed
        case .aborted: .interrupted
        }
    }
}
