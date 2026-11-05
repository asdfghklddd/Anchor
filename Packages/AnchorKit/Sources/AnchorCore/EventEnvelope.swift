// Role: the unit stored and sent between devices. `type` says what `payload` holds. Types in use:
// `anchor.operation.v1` (a `SessionOperation`, the event history), `anchor.reset.v1`, `anchor.history.v1`,
// `anchor.open.v1`, `anchor.activity.v1`. Legacy `session.projection.v1` is still accepted on input.
// Note: the last four are acted on directly and are never replayed into the projection.

import Foundation

/// Wire and storage record. `sourceID` + `sequence` order events per device; `deduplicationKey` drops repeats.
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
