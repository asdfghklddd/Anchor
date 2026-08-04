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
