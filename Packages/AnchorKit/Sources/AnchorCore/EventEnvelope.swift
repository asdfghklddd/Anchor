import Foundation

public struct EventEnvelope: Identifiable, Codable, Hashable, Sendable {
    public static let operationType = "anchor.operation.v1"

    public let id: UUID
    public let sessionID: UUID
    public let sourceID: UUID
    public let sequence: UInt64
    public let timestamp: Date
    public let type: String
    public let payload: Data
    public let schemaVersion: Int
    public let deduplicationKey: String?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        sourceID: UUID,
        sequence: UInt64,
        timestamp: Date = .now,
        type: String,
        payload: Data,
        schemaVersion: Int = 1,
        deduplicationKey: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.sequence = sequence
        self.timestamp = timestamp
        self.type = type
        self.payload = payload
        self.schemaVersion = schemaVersion
        self.deduplicationKey = deduplicationKey
    }
}
