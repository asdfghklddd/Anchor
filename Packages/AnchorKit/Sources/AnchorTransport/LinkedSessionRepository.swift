import AnchorCore
import Foundation

public protocol AnchorEventTransport: Sendable {
    func send(_ event: EventEnvelope) async throws
}

public actor LinkedSessionRepository: SessionRepository {
    private let base: any SessionRepository
    private let eventBackedBase: (any EventBackedSessionRepository)?
    private let transport: any AnchorEventTransport

    public init(
        base: any SessionRepository,
        transport: any AnchorEventTransport
    ) {
        self.base = base
        eventBackedBase = base as? any EventBackedSessionRepository
        self.transport = transport
    }

    /// Compatibility initializer for callers that already own an iOS client.
    /// The source identity now belongs to the event-backed local repository.
    public init(
        base: any SessionRepository,
        client: AnchorBonjourClient,
        sourceID: UUID = UUID()
    ) {
        self.init(base: base, transport: client)
        _ = sourceID
    }

    public func currentProjection() async -> SessionProjection {
        await base.currentProjection()
    }

    public func projections() async -> AsyncStream<SessionProjection> {
        await base.projections()
    }

    public func send(_ command: SessionCommand) async throws {
        try await base.send(command)
        await flushPendingEvents()
    }

    public func applyRemote(_ envelope: EventEnvelope) async throws {
        guard let eventBackedBase else {
            throw SessionRepositoryError.malformedEvent
        }
        try await eventBackedBase.applyRemote(envelope)
    }

    /// Sends events in deterministic order. A transport failure leaves the
    /// remaining events in the durable outbox for the next connection attempt.
    public func flushPendingEvents() async {
        guard let eventBackedBase else { return }
        for event in await eventBackedBase.pendingEvents() {
            do {
                try await transport.send(event)
                try await eventBackedBase.markDelivered(event.id)
            } catch {
                return
            }
        }
    }
}

public enum LinkedSessionDecoder {
    public static func session(from envelope: EventEnvelope) -> AnchorSession? {
        guard envelope.type == "session.projection.v1" else { return nil }
        guard let session = try? JSONDecoder.anchor.decode(AnchorSession.self, from: envelope.payload),
              session.id == envelope.sessionID else { return nil }
        return session
    }
}
