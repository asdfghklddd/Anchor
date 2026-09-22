import Foundation

public struct SessionProjection: Codable, Hashable, Sendable {
    public var session: AnchorSession?
    /// Completed user-owned tasks retained independently from the single
    /// foreground session. Older saved projections decode this as an empty
    /// history, so the addition remains wire- and storage-compatible.
    public var archivedSessions: [AnchorSession]
    public var connection: ConnectionState
    public var proximity: ProximityState
    public var generatedAt: Date
    public var dataObservedAt: Date?
    public var errorMessage: String?
    /// Source health is operational state, not a source event. It is exposed
    /// to the UI but intentionally is not included in the event outbox.
    public var sourceHealth: [UUID: SourceHealth]
    public var durableSyncState: DurableSyncState

    public init(
        session: AnchorSession? = nil,
        archivedSessions: [AnchorSession] = [],
        connection: ConnectionState = .unavailable,
        proximity: ProximityState = .unknown,
        generatedAt: Date = .now,
        dataObservedAt: Date? = nil,
        errorMessage: String? = nil,
        sourceHealth: [UUID: SourceHealth] = [:],
        durableSyncState: DurableSyncState = .notConfigured
    ) {
        self.session = session
        self.archivedSessions = archivedSessions
        self.connection = connection
        self.proximity = proximity
        self.generatedAt = generatedAt
        self.dataObservedAt = dataObservedAt
        self.errorMessage = errorMessage
        self.sourceHealth = sourceHealth
        self.durableSyncState = durableSyncState
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case archivedSessions
        case connection
        case proximity
        case generatedAt
        case dataObservedAt
        case errorMessage
        case sourceHealth
        case durableSyncState
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decodeIfPresent(AnchorSession.self, forKey: .session)
        archivedSessions = try container.decodeIfPresent(
            [AnchorSession].self,
            forKey: .archivedSessions
        ) ?? []
        connection = try container.decodeIfPresent(ConnectionState.self, forKey: .connection) ?? .unavailable
        proximity = try container.decodeIfPresent(ProximityState.self, forKey: .proximity) ?? .unknown
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt) ?? .now
        dataObservedAt = try container.decodeIfPresent(Date.self, forKey: .dataObservedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        sourceHealth = try container.decodeIfPresent(
            [UUID: SourceHealth].self,
            forKey: .sourceHealth
        ) ?? [:]
        durableSyncState = try container.decodeIfPresent(
            DurableSyncState.self,
            forKey: .durableSyncState
        ) ?? .notConfigured
    }

    public static let empty = SessionProjection()

    /// Inserts one terminal session by stable identity and keeps task history
    /// in a deterministic newest-first order.
    public mutating func archive(_ completedSession: AnchorSession) {
        archivedSessions.removeAll { $0.id == completedSession.id }
        archivedSessions.append(completedSession)
        archivedSessions.sort { lhs, rhs in
            let lhsDate = lhs.endedAt ?? lhs.startedAt
            let rhsDate = rhs.endedAt ?? rhs.startedAt
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func archivedSession(id: UUID) -> AnchorSession? {
        archivedSessions.first { $0.id == id }
    }

    public var openDecisions: [Decision] {
        session?.decisions.filter { $0.status == .open } ?? []
    }

    public var unreadNotificationsCount: Int {
        guard let session else { return 0 }
        return session.timeline.lazy.filter {
            $0.kind == .decisionRequired || $0.kind == .completed || $0.kind == .failed
        }.count
    }

    public var overallProgress: Double? {
        guard let processes = session?.processes else { return nil }
        let values = processes.compactMap(\.progress)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    public var isStale: Bool {
        isStale(at: generatedAt)
    }

    public func isStale(
        at date: Date,
        staleAfter interval: TimeInterval = 300
    ) -> Bool {
        guard let dataObservedAt else { return false }
        return date.timeIntervalSince(dataObservedAt) > interval
    }

    /// A connection is necessary but not sufficient for live presentation:
    /// data must also have been observed recently. Missing observation time is
    /// intentionally treated as last-known rather than current.
    public func availability(
        at date: Date,
        staleAfter interval: TimeInterval = 300
    ) -> ProjectionAvailability {
        guard session != nil else { return .empty }

        switch connection {
        case .pairing:
            return .syncing(lastObservedAt: dataObservedAt)
        case .connected:
            guard let dataObservedAt else {
                return .lastKnown(lastObservedAt: nil)
            }
            if isStale(at: date, staleAfter: interval) {
                return .lastKnown(lastObservedAt: dataObservedAt)
            }
            return .live(lastObservedAt: dataObservedAt)
        case .disconnected, .unavailable, .permissionDenied, .failed:
            return .lastKnown(lastObservedAt: dataObservedAt)
        }
    }

    public func needsRecoveryReview(
        at date: Date,
        after interval: TimeInterval = 86_400
    ) -> Bool {
        guard let session,
              session.status == .draft || session.status == .active else {
            return false
        }
        let lastContinuedAt = session.lastContinuedAt ?? session.startedAt
        return date.timeIntervalSince(lastContinuedAt) > interval
    }
}
