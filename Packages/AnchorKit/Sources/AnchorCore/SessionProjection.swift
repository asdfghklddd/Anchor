import Foundation

public struct SessionProjection: Codable, Hashable, Sendable {
    public var session: AnchorSession?
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
        connection: ConnectionState = .unavailable,
        proximity: ProximityState = .unknown,
        generatedAt: Date = .now,
        dataObservedAt: Date? = nil,
        errorMessage: String? = nil,
        sourceHealth: [UUID: SourceHealth] = [:],
        durableSyncState: DurableSyncState = .notConfigured
    ) {
        self.session = session
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
        guard let dataObservedAt else { return false }
        return generatedAt.timeIntervalSince(dataObservedAt) > 300
    }
}
