import Foundation

public protocol SessionRepository: Sendable {
    func currentProjection() async -> SessionProjection
    func projections() async -> AsyncStream<SessionProjection>
    func send(_ command: SessionCommand) async throws
}

/// A repository that can durably retain mutations until a peer acknowledges
/// them and can apply the same mutations received from another device.
public protocol EventBackedSessionRepository: SessionRepository {
    func pendingEvents() async -> [EventEnvelope]
    func applyRemote(_ envelope: EventEnvelope) async throws
    func markDelivered(_ eventID: UUID) async throws
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
public actor LocalSessionRepository: EventBackedSessionRepository {
    private struct PersistedState: Codable, Sendable {
        let schemaVersion: Int
        let baseProjection: SessionProjection
        var events: [EventEnvelope]
        var outbox: [EventEnvelope]
        var nextSequence: UInt64
    }

    private struct LegacyPersistedState: Codable, Sendable {
        let schemaVersion: Int
        let projection: SessionProjection
    }

    public static let schemaVersion = 2

    private let sourceID: UUID
    private var baseProjection: SessionProjection
    private var events: [EventEnvelope]
    private var outbox: [EventEnvelope]
    private var nextSequence: UInt64
    private var projection: SessionProjection
    private let storageURL: URL
    private var continuations: [UUID: AsyncStream<SessionProjection>.Continuation] = [:]

    public init(storageURL: URL? = nil, sourceID: UUID = UUID()) {
        self.sourceID = sourceID
        let resolvedURL = storageURL ?? Self.defaultStorageURL()
        self.storageURL = resolvedURL

        let storedData = try? Data(contentsOf: resolvedURL)
        var startupError: String?
        if let data = storedData,
           let persisted = Self.decodePersistedState(data),
           persisted.schemaVersion == Self.schemaVersion {
            baseProjection = persisted.baseProjection
            events = persisted.events
            outbox = persisted.outbox
            nextSequence = max(
                persisted.nextSequence,
                (persisted.events.filter { $0.sourceID == sourceID }.map(\ .sequence).max() ?? 0) + 1
            )
        } else if let data = try? Data(contentsOf: resolvedURL),
                  let legacy = try? JSONDecoder().decode(LegacyPersistedState.self, from: data),
                  legacy.schemaVersion == 1 {
            // Preserve the v1 projection as a migration checkpoint. New
            // mutations are appended as v2 events from this point forward.
            baseProjection = legacy.projection
            events = []
            outbox = []
            nextSequence = 1
        } else {
            baseProjection = .empty
            events = []
            outbox = []
            nextSequence = 1
            if storedData != nil {
                startupError = "The saved Anchor state could not be recovered. A new local workspace was started."
            }
        }

        projection = Self.replay(
            baseProjection: baseProjection,
            events: events,
            connection: .unavailable,
            proximity: .unknown,
            sourceHealth: [:],
            durableSyncState: .notConfigured
        )
        if let startupError {
            projection.errorMessage = startupError
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
        let now = Date.now
        if let operation = try SessionOperation.make(
            from: command,
            projection: projection,
            now: now
        ) {
            let sessionID = operation.sessionID ?? projection.session?.id
            guard let sessionID else {
                throw SessionRepositoryError.noActiveSession
            }
            let payload = try JSONEncoder.anchor.encode(operation)
            let envelope = EventEnvelope(
                sessionID: sessionID,
                sourceID: sourceID,
                sequence: nextSequence,
                timestamp: Self.timestamp(for: operation, fallback: now),
                type: EventEnvelope.operationType,
                payload: payload,
                deduplicationKey: operation.deduplicationKey
            )
            let nextEvents = events + [envelope]
            let nextOutbox = outbox + [envelope]
            let nextProjection = Self.replay(
                baseProjection: baseProjection,
                events: nextEvents,
                connection: projection.connection,
                proximity: projection.proximity,
                sourceHealth: projection.sourceHealth,
                durableSyncState: projection.durableSyncState
            )
            try write(
                baseProjection: baseProjection,
                events: nextEvents,
                outbox: nextOutbox,
                nextSequence: nextSequence &+ 1
            )
            nextSequence &+= 1
            events = nextEvents
            outbox = nextOutbox
            projection = nextProjection
            broadcast()
            return
        }

        let nextProjection = try SessionReducer.reduce(projection, command: command, now: now)
        if shouldPersist(command) {
            let nextBaseProjection: SessionProjection
            let nextEvents: [EventEnvelope]
            let nextOutbox: [EventEnvelope]

            if case .mergeRemoteSession = command {
                nextBaseProjection = nextProjection
                nextEvents = []
                nextOutbox = []
            } else {
                nextBaseProjection = baseProjection
                nextEvents = events
                nextOutbox = outbox
            }

            try write(
                baseProjection: nextBaseProjection,
                events: nextEvents,
                outbox: nextOutbox,
                nextSequence: nextSequence
            )
            baseProjection = nextBaseProjection
            events = nextEvents
            outbox = nextOutbox
        }
        projection = nextProjection
        broadcast()
    }

    public func pendingEvents() -> [EventEnvelope] {
        outbox.sorted(by: Self.eventSort)
    }

    public func applyRemote(_ envelope: EventEnvelope) throws {
        guard envelope.schemaVersion <= 1 else {
            throw SessionRepositoryError.unsupportedEventSchema
        }

        if envelope.type == "session.projection.v1" {
            guard let session = try? JSONDecoder.anchor.decode(
                AnchorSession.self,
                from: envelope.payload
            ), session.id == envelope.sessionID else {
                throw SessionRepositoryError.malformedEvent
            }
            if let currentSessionID = projection.session?.id,
               currentSessionID != session.id {
                throw SessionRepositoryError.eventSessionMismatch
            }
            let mergedSession = Self.mergeLegacySession(
                local: projection.session,
                remote: session,
                envelopeTimestamp: envelope.timestamp
            )
            let nextProjection = SessionProjection(
                session: mergedSession,
                connection: projection.connection,
                proximity: projection.proximity,
                generatedAt: .now,
                dataObservedAt: max(projection.dataObservedAt ?? envelope.timestamp, envelope.timestamp),
                errorMessage: projection.errorMessage
            )
            try write(
                baseProjection: nextProjection,
                events: events,
                outbox: outbox,
                nextSequence: nextSequence
            )
            baseProjection = nextProjection
            projection = Self.replay(
                baseProjection: baseProjection,
                events: events,
                connection: projection.connection,
                proximity: projection.proximity,
                sourceHealth: projection.sourceHealth,
                durableSyncState: projection.durableSyncState
            )
            broadcast()
            return
        }

        guard envelope.type == EventEnvelope.operationType else {
            throw SessionRepositoryError.malformedEvent
        }
        guard let operation = try? JSONDecoder.anchor.decode(
            SessionOperation.self,
            from: envelope.payload
        ) else {
            throw SessionRepositoryError.malformedEvent
        }

        try Self.validate(operation: operation, against: envelope)

        if events.contains(where: { $0.id == envelope.id }) {
            return
        }
        if let deduplicationKey = envelope.deduplicationKey,
           events.contains(where: {
               $0.sourceID == envelope.sourceID && $0.deduplicationKey == deduplicationKey
           }) {
            return
        }
        if events.contains(where: {
            $0.sourceID == envelope.sourceID && $0.sequence == envelope.sequence
        }) {
            return
        }

        let currentSessionID = projection.session?.id
        let operationSessionID = operation.sessionID ?? envelope.sessionID
        if let currentSessionID, currentSessionID != operationSessionID {
            throw SessionRepositoryError.eventSessionMismatch
        }
        guard operation.sessionID == nil || operation.sessionID == envelope.sessionID else {
            throw SessionRepositoryError.eventSessionMismatch
        }

        let nextEvents = events + [envelope]
        var nextOutbox = outbox
        nextOutbox.removeAll { $0.id == envelope.id }
        let nextProjection = Self.replay(
            baseProjection: baseProjection,
            events: nextEvents,
            connection: projection.connection,
            proximity: projection.proximity,
            sourceHealth: projection.sourceHealth,
            durableSyncState: projection.durableSyncState
        )
        try write(
            baseProjection: baseProjection,
            events: nextEvents,
            outbox: nextOutbox,
            nextSequence: nextSequence
        )
        events = nextEvents
        outbox = nextOutbox
        projection = nextProjection
        broadcast()
    }

    public func markDelivered(_ eventID: UUID) throws {
        let previousCount = outbox.count
        let nextOutbox = outbox.filter { $0.id != eventID }
        guard nextOutbox.count != previousCount else { return }
        try write(
            baseProjection: baseProjection,
            events: events,
            outbox: nextOutbox,
            nextSequence: nextSequence
        )
        outbox = nextOutbox
    }

    private func shouldPersist(_ command: SessionCommand) -> Bool {
        switch command {
        case .updateSignals, .updateSourceHealth, .updateDurableSyncState, .clearError:
            false
        default:
            true
        }
    }

    private func write(
        baseProjection: SessionProjection,
        events: [EventEnvelope],
        outbox: [EventEnvelope],
        nextSequence: UInt64
    ) throws {
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let state = PersistedState(
            schemaVersion: Self.schemaVersion,
            baseProjection: baseProjection,
            events: events,
            outbox: outbox,
            nextSequence: nextSequence
        )
        let data = try JSONEncoder.anchor.encode(state)
        try data.write(to: storageURL, options: .atomic)
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func broadcast() {
        for continuation in continuations.values {
            continuation.yield(projection)
        }
    }

    private func replayPreservingSignals() throws -> SessionProjection {
        Self.replay(
            baseProjection: baseProjection,
            events: events,
            connection: projection.connection,
            proximity: projection.proximity,
            sourceHealth: projection.sourceHealth,
            durableSyncState: projection.durableSyncState
        )
    }

    private static func replay(
        baseProjection: SessionProjection,
        events: [EventEnvelope],
        connection: ConnectionState,
        proximity: ProximityState,
        sourceHealth: [UUID: SourceHealth],
        durableSyncState: DurableSyncState
    ) -> SessionProjection {
        var result = baseProjection
        var latestObservedAt = baseProjection.dataObservedAt
        for envelope in events.sorted(by: eventSort) {
            guard let operation = try? JSONDecoder.anchor.decode(
                SessionOperation.self,
                from: envelope.payload
            ) else {
                result.errorMessage = "An Anchor event could not be decoded and was retained for recovery."
                continue
            }
            do {
                try validate(operation: operation, against: envelope)
                result = try SessionReducer.reduce(
                    result,
                    operation: operation,
                    now: envelope.timestamp
                )
            } catch {
                // Retain the immutable event, surface the recovery condition,
                // and let a later replay (after its prerequisite create event
                // arrives) attempt the operation again.
                result.errorMessage = error.localizedDescription
            }
            latestObservedAt = max(latestObservedAt ?? envelope.timestamp, envelope.timestamp)
        }
        result.connection = connection
        result.proximity = proximity
        result.sourceHealth = sourceHealth
        result.durableSyncState = durableSyncState
        result.dataObservedAt = latestObservedAt
        result.generatedAt = .now
        return result
    }

    private static func validate(
        operation: SessionOperation,
        against envelope: EventEnvelope
    ) throws {
        if let operationSessionID = operation.sessionID,
           operationSessionID != envelope.sessionID {
            throw SessionRepositoryError.eventSessionMismatch
        }

        switch operation {
        case let .createSession(session):
            guard session.id == envelope.sessionID else {
                throw SessionRepositoryError.eventSessionMismatch
            }
            for process in session.processes {
                if let processSessionID = process.sessionID,
                   processSessionID != session.id {
                    throw SessionRepositoryError.eventSessionMismatch
                }
            }
        case let .addProcess(process), let .updateProcess(process):
            if let processSessionID = process.sessionID,
               processSessionID != envelope.sessionID {
                throw SessionRepositoryError.eventSessionMismatch
            }
        case let .addNote(note):
            if let noteSessionID = note.sessionID,
               noteSessionID != envelope.sessionID {
                throw SessionRepositoryError.eventSessionMismatch
            }
        case let .recordEvent(event):
            try validate(
                event: event,
                sessionID: envelope.sessionID
            )
        case let .observeProcess(observation):
            if let processSessionID = observation.process.sessionID,
               processSessionID != envelope.sessionID {
                throw SessionRepositoryError.eventSessionMismatch
            }
            if let event = observation.event {
                try validate(
                    event: event,
                    sessionID: envelope.sessionID
                )
            }
            if let decision = observation.decision,
               decision.processID != observation.process.id {
                throw SessionRepositoryError.eventSessionMismatch
            }
        case .updateGoal, .resolveDecision, .removeProcess, .reorderProcesses,
             .updateTileSize, .updatePresence, .acknowledgeReturn,
             .completeSession, .resumeSession:
            break
        }
    }

    private static func validate(
        event: ProcessEvent,
        sessionID: UUID
    ) throws {
        if let eventSessionID = event.sessionID, eventSessionID != sessionID {
            throw SessionRepositoryError.eventSessionMismatch
        }
        if let progress = event.progress, !(0 ... 1).contains(progress) {
            throw SessionRepositoryError.malformedEvent
        }
    }

    private static func mergeLegacySession(
        local: AnchorSession?,
        remote: AnchorSession,
        envelopeTimestamp: Date
    ) -> AnchorSession {
        guard let local, local.id == remote.id else { return remote }
        var merged = local

        if remote.goal.createdAt >= local.goal.createdAt {
            merged.goal = remote.goal
        }
        merged.processes = mergeProcesses(local.processes, remote.processes)
        merged.decisions = mergeDecisions(local.decisions, remote.decisions)
        merged.notes = mergeByID(local.notes, remote.notes, newer: { $0.createdAt >= $1.createdAt })
        merged.timeline = mergeByID(local.timeline, remote.timeline, newer: { $0.occurredAt >= $1.occurredAt })
            .sorted(by: timelineSort)
        merged.snapshots = mergeByID(local.snapshots, remote.snapshots, newer: { $0.createdAt >= $1.createdAt })
            .sorted { $0.createdAt > $1.createdAt }
        merged.processedEventIDs.formUnion(remote.processedEventIDs)
        if remote.status == .completed || local.status == .archived {
            merged.status = remote.status
        }
        if remote.completedAt != nil {
            merged.completedAt = remote.completedAt
        }
        if remote.presence != .unknown {
            merged.presence = remote.presence
        }
        if remote.returnSummary != nil {
            merged.returnSummary = remote.returnSummary
        }
        _ = envelopeTimestamp
        return merged
    }

    private static func mergeProcesses(
        _ local: [AnchorProcess],
        _ remote: [AnchorProcess]
    ) -> [AnchorProcess] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for candidate in remote {
            guard let existing = byID[candidate.id] else {
                byID[candidate.id] = candidate
                continue
            }
            var merged = candidate.updatedAt >= existing.updatedAt ? candidate : existing
            let allEvents = mergeByID(
                existing.events,
                candidate.events,
                newer: { $0.occurredAt >= $1.occurredAt }
            )
            merged.events = allEvents.sorted(by: timelineSort)
            merged.updatedAt = max(existing.updatedAt, candidate.updatedAt)
            byID[candidate.id] = merged
        }
        let order = local.map(\ .id) + remote.map(\ .id)
        var seen = Set<UUID>()
        return order.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return byID[id]
        }
    }

    private static func mergeDecisions(
        _ local: [Decision],
        _ remote: [Decision]
    ) -> [Decision] {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for candidate in remote {
            guard let existing = byID[candidate.id] else {
                byID[candidate.id] = candidate
                continue
            }
            if existing.status == .resolved || existing.status == .cancelled {
                continue
            }
            byID[candidate.id] = candidate
        }
        let order = local.map(\ .id) + remote.map(\ .id)
        var seen = Set<UUID>()
        return order.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return byID[id]
        }
    }

    private static func mergeByID<T: Identifiable>(
        _ local: [T],
        _ remote: [T],
        newer: (T, T) -> Bool
    ) -> [T] where T.ID: Hashable {
        var byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for candidate in remote {
            if let existing = byID[candidate.id] {
                if newer(candidate, existing) {
                    byID[candidate.id] = candidate
                }
            } else {
                byID[candidate.id] = candidate
            }
        }
        let order = local.map(\ .id) + remote.map(\ .id)
        var seen = Set<T.ID>()
        return order.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return byID[id]
        }
    }

    private static func timelineSort(_ lhs: ProcessEvent, _ rhs: ProcessEvent) -> Bool {
        if lhs.occurredAt != rhs.occurredAt {
            return lhs.occurredAt > rhs.occurredAt
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func eventSort(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        if lhs.sourceID != rhs.sourceID {
            return lhs.sourceID.uuidString < rhs.sourceID.uuidString
        }
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func timestamp(
        for operation: SessionOperation,
        fallback: Date
    ) -> Date {
        switch operation {
        case let .createSession(session): session.startedAt
        case let .updateGoal(_, at): at
        case let .addNote(note): note.createdAt
        case let .resolveDecision(_, _, resolvedAt, _): resolvedAt
        case let .addProcess(process): process.updatedAt
        case let .updateProcess(process): process.updatedAt
        case let .recordEvent(event): event.occurredAt
        case let .observeProcess(observation): observation.event?.occurredAt ?? observation.process.updatedAt
        case let .updatePresence(_, at, _): at
        case let .acknowledgeReturn(at): at
        case let .completeSession(at): at
        case let .resumeSession(at): at
        case .removeProcess, .reorderProcesses, .updateTileSize:
            fallback
        }
    }

    private static func defaultStorageURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "Anchor", directoryHint: .isDirectory)
            .appending(path: "session-state.json")
    }

    private static func decodePersistedState(_ data: Data) -> PersistedState? {
        if let state = try? JSONDecoder.anchor.decode(PersistedState.self, from: data) {
            return state
        }
        return try? JSONDecoder().decode(PersistedState.self, from: data)
    }
}
