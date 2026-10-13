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

/// Resident metadata supervisor for Codex Desktop session files. The stream is
/// a discovery surface; the Mac coordinator applies manual or high-confidence
/// automatic association separately.
public actor CodexTaskSupervisor {
    private struct CacheEntry {
        let metadata: CodexSessionFileMetadata
        /// `nil` for subagent or unreadable logs, so each is inspected once per change.
        let candidate: CodexTaskCandidate?
    }

    private let locator: CodexSessionFileLocator
    private let pollInterval: TimeInterval
    private let candidateLimit: Int
    private let discoveryWindow: Int
    private let maximumTailBytes: UInt64
    private var cache: [URL: CacheEntry] = [:]

    public init(
        rootURL: URL,
        pollInterval: TimeInterval = 2,
        candidateLimit: Int = 12,
        discoveryWindow: Int? = nil,
        maximumTailBytes: UInt64 = 4 * 1_024 * 1_024
    ) {
        locator = CodexSessionFileLocator(rootURL: rootURL)
        self.pollInterval = max(0.25, pollInterval)
        self.candidateLimit = max(1, candidateLimit)
        // Guardian and subagent logs can outnumber user threads several times over.
        self.discoveryWindow = max(self.candidateLimit, discoveryWindow ?? self.candidateLimit * 6)
        self.maximumTailBytes = max(1_024, maximumTailBytes)
    }

    public func snapshot() -> [CodexTaskCandidate] {
        let files = locator.recentSessionFiles(limit: discoveryWindow)
        let activeURLs = Set(files.map(\.fileURL))
        cache = cache.filter { activeURLs.contains($0.key) }

        var candidates: [CodexTaskCandidate] = []
        for metadata in files where candidates.count < candidateLimit {
            let candidate: CodexTaskCandidate?
            if let cached = cache[metadata.fileURL], cached.metadata == metadata {
                candidate = cached.candidate
            } else {
                candidate = self.candidate(for: metadata)
                cache[metadata.fileURL] = CacheEntry(metadata: metadata, candidate: candidate)
            }
            if let candidate { candidates.append(candidate) }
        }
        return candidates
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

    private func candidate(for metadata: CodexSessionFileMetadata) -> CodexTaskCandidate? {
        guard let session = CodexSessionMetadata.read(from: metadata.fileURL),
              session.isUserConversation else {
            return nil
        }
        let lifecycle = readLatestLifecycle(
            from: metadata.fileURL,
            fileSize: metadata.fileSize
        )
        return CodexTaskCandidate(
            id: session.id,
            fileURL: metadata.fileURL,
            workspaceName: session.workspaceName,
            originator: session.originator,
            modifiedAt: metadata.contentModificationDate,
            activity: lifecycle.map(Self.activity) ?? .unknown,
            activityObservedAt: lifecycle?.timestamp,
            createdAt: session.createdAt
        )
    }

    private func readLatestLifecycle(
        from url: URL,
        fileSize: UInt64
    ) -> CodexLifecycleRecord? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let start = fileSize > maximumTailBytes ? fileSize - maximumTailBytes : 0
        do {
            try handle.seek(toOffset: start)
            guard var data = try handle.readToEnd(), !data.isEmpty else { return nil }
            if start > 0, let newline = data.firstIndex(of: 10) {
                data.removeSubrange(...newline)
            }
            return data
                .split(separator: 10, omittingEmptySubsequences: true)
                .compactMap { CodexLifecycleRecord(json: Data($0)) }
                .max { $0.timestamp < $1.timestamp }
        } catch {
            return nil
        }
    }

    private static func activity(_ record: CodexLifecycleRecord) -> CodexTaskActivity {
        switch record.lifecycle {
        case .started: .running
        case .completed: .completed
        case .aborted: .interrupted
        }
    }
}
