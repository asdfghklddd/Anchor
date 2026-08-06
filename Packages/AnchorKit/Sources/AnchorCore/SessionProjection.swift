import Foundation

public struct SessionProjection: Codable, Hashable, Sendable {
    public var session: AnchorSession?
    public var connection: ConnectionState
    public var proximity: ProximityState
    public var generatedAt: Date
    public var dataObservedAt: Date?
    public var errorMessage: String?

    public init(
        session: AnchorSession? = nil,
        connection: ConnectionState = .unavailable,
        proximity: ProximityState = .unknown,
        generatedAt: Date = .now,
        dataObservedAt: Date? = nil,
        errorMessage: String? = nil
    ) {
        self.session = session
        self.connection = connection
        self.proximity = proximity
        self.generatedAt = generatedAt
        self.dataObservedAt = dataObservedAt
        self.errorMessage = errorMessage
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
