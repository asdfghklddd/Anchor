import Foundation

public protocol SessionRepository: Sendable {
    func currentProjection() async -> SessionProjection
    func projections() async -> AsyncStream<SessionProjection>
    func send(_ command: SessionCommand) async throws
}

public protocol PresenceSignalProviding: Sendable {
    func presenceSignals() async -> AsyncStream<PresenceSignals>
}

public actor InMemorySessionRepository: SessionRepository {
    private var projection: SessionProjection
    private var continuations: [UUID: AsyncStream<SessionProjection>.Continuation] = [:]

    public init(initialProjection: SessionProjection = .empty) {
        projection = initialProjection
    }

    public func currentProjection() -> SessionProjection { projection }

    public func projections() -> AsyncStream<SessionProjection> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(projection)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func send(_ command: SessionCommand) throws {
        projection = try SessionReducer.reduce(projection, command: command)
        for continuation in continuations.values {
            continuation.yield(projection)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}

/// A production-local repository for the period before the remote session
/// service is available. It starts with an empty projection and only persists
/// state created by the user or received from a real peer; it never supplies
/// demo fixtures.
public actor LocalSessionRepository: SessionRepository {
    private struct PersistedState: Codable, Sendable {
        let schemaVersion: Int
        var projection: SessionProjection
    }

    public static let schemaVersion = 1

    private var projection: SessionProjection
    private let storageURL: URL
    private var continuations: [UUID: AsyncStream<SessionProjection>.Continuation] = [:]

    public init(storageURL: URL? = nil) {
        let resolvedURL = storageURL ?? Self.defaultStorageURL()
        self.storageURL = resolvedURL

        if let data = try? Data(contentsOf: resolvedURL),
           let persisted = try? JSONDecoder().decode(PersistedState.self, from: data),
           persisted.schemaVersion == Self.schemaVersion {
            projection = persisted.projection
        } else {
            projection = .empty
        }
    }

    public func currentProjection() -> SessionProjection { projection }

    public func projections() -> AsyncStream<SessionProjection> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(projection)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    public func send(_ command: SessionCommand) throws {
        projection = try SessionReducer.reduce(projection, command: command)
        if shouldPersist(command) {
            persist()
        }
        for continuation in continuations.values {
            continuation.yield(projection)
        }
    }

    private func shouldPersist(_ command: SessionCommand) -> Bool {
        switch command {
        case .updateSignals, .clearError:
            false
        default:
            true
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let state = PersistedState(schemaVersion: Self.schemaVersion, projection: projection)
            let data = try JSONEncoder().encode(state)
            try data.write(to: storageURL, options: .atomic)
            projection.errorMessage = nil
        } catch {
            projection.errorMessage = error.localizedDescription
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private static func defaultStorageURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "Anchor", directoryHint: .isDirectory)
            .appending(path: "session-state.json")
    }
}
