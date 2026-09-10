import Foundation

/// Stable metadata for the selected JSONL file. It intentionally excludes
/// file contents and keeps only enough information to reject stale offsets.
public struct CodexLifecycleFileIdentity: Codable, Equatable, Sendable {
    public let fileNumber: UInt64?
    public let creationDate: Date?

    public init(fileNumber: UInt64?, creationDate: Date?) {
        self.fileNumber = fileNumber
        self.creationDate = creationDate
    }
}

public struct CodexLifecycleCheckpoint: Codable, Equatable, Sendable {
    public let identity: CodexLifecycleFileIdentity
    public let scannerCheckpoint: Data

    public init(identity: CodexLifecycleFileIdentity, scannerCheckpoint: Data) {
        self.identity = identity
        self.scannerCheckpoint = scannerCheckpoint
    }
}

/// Durable, privacy-minimized checkpoints for append-only Codex observation.
/// Corrupt state is surfaced to the caller rather than silently overwritten.
public actor CodexLifecycleCheckpointStore {
    public let storageURL: URL
    private var entries: [String: CodexLifecycleCheckpoint]?

    public init(storageURL: URL) {
        self.storageURL = storageURL
    }

    public init() {
        storageURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "Anchor/codex-checkpoints.json")
    }

    public func load(for sourceKey: String) throws -> CodexLifecycleCheckpoint? {
        try loadEntries()[sourceKey]
    }

    public func save(_ checkpoint: CodexLifecycleCheckpoint, for sourceKey: String) throws {
        var values = try loadEntries()
        values[sourceKey] = checkpoint
        try persist(values)
    }

    public func remove(for sourceKey: String) throws {
        var values = try loadEntries()
        guard values.removeValue(forKey: sourceKey) != nil else { return }
        try persist(values)
    }

    private func loadEntries() throws -> [String: CodexLifecycleCheckpoint] {
        if let entries { return entries }
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            entries = [:]
            return [:]
        }
        let data = try Data(contentsOf: storageURL)
        let decoded = try JSONDecoder.anchor.decode(
            [String: CodexLifecycleCheckpoint].self,
            from: data
        )
        entries = decoded
        return decoded
    }

    private func persist(_ values: [String: CodexLifecycleCheckpoint]) throws {
        let directory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.anchor.encode(values)
        try data.write(to: storageURL, options: .atomic)
        entries = values
    }
}
