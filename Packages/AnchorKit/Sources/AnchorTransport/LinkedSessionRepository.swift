import AnchorCore
import Foundation

public protocol AnchorEventTransport: Sendable {
    func send(_ event: EventEnvelope) async throws
}

public actor LinkedSessionRepository: SessionRepository {
    private struct ActiveFlush {
        let id: UUID
        let task: Task<Void, Never>
    }

    private let base: any SessionRepository
    private let eventBackedBase: (any EventBackedSessionRepository)?
    private let transport: any AnchorEventTransport
    private var activeFlush: ActiveFlush?
    private var backgroundFlush: Task<Void, Never>?
    private var flushRequested = false

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
        requestBackgroundFlush()
    }

    /// UI commands finish when the local mutation is durable. Radio delivery
    /// must not keep an editor or confirmation sheet waiting for peer ACKs.
    private func requestBackgroundFlush() {
        guard eventBackedBase != nil else { return }
        flushRequested = true
        guard backgroundFlush == nil else { return }
        backgroundFlush = Task { [weak self] in
            await self?.drainRequestedFlushes()
        }
    }

    private func drainRequestedFlushes() async {
        while flushRequested {
            flushRequested = false
            await flushPendingEvents()
        }
        backgroundFlush = nil
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
        while true {
            if let activeFlush {
                await activeFlush.task.value
                if self.activeFlush?.id == activeFlush.id {
                    self.activeFlush = nil
                }
                // A command may have queued another event while the shared
                // flush was suspended. Recheck instead of returning early.
                continue
            }
            guard let eventBackedBase else { return }
            let transport = self.transport
            let id = UUID()
            let task = Task {
                for event in await eventBackedBase.pendingEvents() {
                    do {
                        try await transport.send(event)
                        try await eventBackedBase.markDelivered(event.id)
                    } catch {
                        return
                    }
                }
            }
            activeFlush = ActiveFlush(id: id, task: task)
            await task.value
            if activeFlush?.id == id {
                activeFlush = nil
            }
            return
        }
    }

    /// Replays retained immutable events for every active hosted task, or the
    /// newest terminal task when no work is active, after an authenticated reconnect.
    /// The receiver's event IDs, source sequences, and deduplication keys make
    /// this safe when both peers already contain some or all of the history.
    public func reconcilePeerHistory() async {
        while true {
            if let activeFlush {
                await activeFlush.task.value
                if self.activeFlush?.id == activeFlush.id {
                    self.activeFlush = nil
                }
                continue
            }
            guard let eventBackedBase else { return }
            let projection = await eventBackedBase.currentProjection()
            let hostedSessionIDs = Set(projection.hostedSessions.map(\.id))
            let reconciliationSessionIDs = hostedSessionIDs.isEmpty
                ? Set(projection.archivedSessions.prefix(1).map(\.id))
                : hostedSessionIDs
            guard !reconciliationSessionIDs.isEmpty else {
                return
            }
            let retainedEvents = await eventBackedBase.retainedEvents().filter {
                reconciliationSessionIDs.contains($0.sessionID)
            }
            let transport = self.transport
            let id = UUID()
            let task = Task {
                for event in retainedEvents {
                    do {
                        try await transport.send(event)
                        try await eventBackedBase.markDelivered(event.id)
                    } catch {
                        return
                    }
                }
            }
            activeFlush = ActiveFlush(id: id, task: task)
            await task.value
            if activeFlush?.id == id {
                activeFlush = nil
            }
            return
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
