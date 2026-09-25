import AnchorCore
import Foundation

#if canImport(CloudKit)
// CloudKit's SDK predates complete Swift 6 Sendable annotations. All
// CKContainer/CKDatabase/CKRecord values stay inside CloudKitEventStore's
// actor; only immutable EventEnvelope values cross the public boundary.
@preconcurrency import CloudKit

public struct CloudKitEventStoreConfiguration: Sendable, Hashable {
    public let containerIdentifier: String
    public let recordType: String
    public let syncStateRecordType: String

    public init(
        containerIdentifier: String,
        recordType: String = "AnchorEventEnvelope",
        syncStateRecordType: String = "AnchorSyncState"
    ) {
        self.containerIdentifier = containerIdentifier
        self.recordType = recordType
        self.syncStateRecordType = syncStateRecordType
    }
}

/// Private-database event storage for the durable-away/offline path. The
/// containing app must enable the matching iCloud container entitlement and
/// deploy the `AnchorEventEnvelope` record schema before constructing it.
public actor CloudKitEventStore: DurableEventStore {
    private let database: CKDatabase
    private let recordType: String
    private let syncStateRecordType: String

    public init(configuration: CloudKitEventStoreConfiguration) {
        database = CKContainer(identifier: configuration.containerIdentifier).privateCloudDatabase
        recordType = configuration.recordType
        syncStateRecordType = configuration.syncStateRecordType
    }

    public func save(_ envelope: EventEnvelope) async throws {
        let record = makeRecord(for: envelope)
        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // The outbox may retry after the server accepted a record but the
            // acknowledgement was lost. Treat an identical immutable record
            // as success; reject an ID collision with different content.
            guard let serverRecord = error.serverRecord,
                  Self.matches(serverRecord, envelope: envelope) else {
                throw CloudKitEventStoreError.conflictingRecord(record.recordID.recordName)
            }
        }
        try await updateSyncState(with: envelope)
    }

    public func currentSessionID() async throws -> UUID? {
        guard let record = try await syncStateRecord() else { return nil }
        guard let value = record["sessionID"] as? String,
              let sessionID = UUID(uuidString: value) else {
            throw CloudKitEventStoreError.malformedRecord(record.recordID.recordName)
        }
        return sessionID
    }

    public func events(
        for sessionID: UUID,
        onOrAfter date: Date?
    ) async throws -> [EventEnvelope] {
        guard let state = try await syncStateRecord(),
              state["sessionID"] as? String == sessionID.uuidString else {
            return []
        }
        let eventIDs = state["eventIDs"] as? [String] ?? []
        let recordIDs = eventIDs.map(CKRecord.ID.init(recordName:))
        var records: [CKRecord] = []
        for start in stride(from: 0, to: recordIDs.count, by: 200) {
            let end = min(start + 200, recordIDs.count)
            let response = try await database.records(for: Array(recordIDs[start ..< end]))
            records.append(contentsOf: try response.values.map { try $0.get() })
        }

        return try records
            .compactMap(Self.decode)
            .filter { date == nil || $0.timestamp >= date! }
            .sorted(by: Self.eventSort)
    }

    private func updateSyncState(with envelope: EventEnvelope) async throws {
        let incomingCreatesSession = Self.createsSession(envelope)
        for _ in 0 ..< 4 {
            let record = try await syncStateRecord() ?? CKRecord(
                recordType: syncStateRecordType,
                recordID: Self.syncStateRecordID
            )
            let existingSessionID = (record["sessionID"] as? String).flatMap(UUID.init(uuidString:))
            let existingUpdatedAt = record["updatedAt"] as? Date ?? .distantPast

            if let existingSessionID, existingSessionID != envelope.sessionID {
                guard incomingCreatesSession, envelope.timestamp >= existingUpdatedAt else {
                    return
                }
                record["eventIDs"] = [String]() as CKRecordValue
            }

            var eventIDs = record["eventIDs"] as? [String] ?? []
            let eventID = envelope.id.uuidString
            if !eventIDs.contains(eventID) {
                eventIDs.append(eventID)
            }
            record["sessionID"] = envelope.sessionID.uuidString as CKRecordValue
            record["eventIDs"] = eventIDs as CKRecordValue
            record["updatedAt"] = max(existingUpdatedAt, envelope.timestamp) as CKRecordValue

            do {
                _ = try await database.save(record)
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            }
        }
        throw CloudKitEventStoreError.conflictingRecord(Self.syncStateRecordID.recordName)
    }

    private func syncStateRecord() async throws -> CKRecord? {
        do {
            return try await database.record(for: Self.syncStateRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func makeRecord(for envelope: EventEnvelope) -> CKRecord {
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: envelope.id.uuidString)
        )
        record["sessionID"] = envelope.sessionID.uuidString as CKRecordValue
        record["sourceID"] = envelope.sourceID.uuidString as CKRecordValue
        record["sequence"] = NSNumber(value: envelope.sequence)
        record["timestamp"] = envelope.timestamp as CKRecordValue
        record["type"] = envelope.type as CKRecordValue
        record["payload"] = envelope.payload as CKRecordValue
        record["schemaVersion"] = NSNumber(value: envelope.schemaVersion)
        if let deduplicationKey = envelope.deduplicationKey {
            record["deduplicationKey"] = deduplicationKey as CKRecordValue
        }
        return record
    }

    private static func matches(_ record: CKRecord, envelope: EventEnvelope) -> Bool {
        guard
            let sessionID = record["sessionID"] as? String,
            let sourceID = record["sourceID"] as? String,
            let sequence = record["sequence"] as? NSNumber,
            let timestamp = record["timestamp"] as? Date,
            let type = record["type"] as? String,
            let payload = record["payload"] as? Data,
            let schemaVersion = record["schemaVersion"] as? NSNumber
        else {
            return false
        }

        return sessionID == envelope.sessionID.uuidString
            && sourceID == envelope.sourceID.uuidString
            && sequence.uint64Value == envelope.sequence
            && timestamp == envelope.timestamp
            && type == envelope.type
            && payload == envelope.payload
            && schemaVersion.intValue == envelope.schemaVersion
            && (record["deduplicationKey"] as? String) == envelope.deduplicationKey
    }

    private static func decode(_ record: CKRecord) throws -> EventEnvelope? {
        guard
            let sessionString = record["sessionID"] as? String,
            let sessionID = UUID(uuidString: sessionString),
            let sourceString = record["sourceID"] as? String,
            let sourceID = UUID(uuidString: sourceString),
            let sequenceNumber = record["sequence"] as? NSNumber,
            let timestamp = record["timestamp"] as? Date,
            let type = record["type"] as? String,
            let payload = record["payload"] as? Data,
            let schemaNumber = record["schemaVersion"] as? NSNumber,
            let id = UUID(uuidString: record.recordID.recordName)
        else {
            throw CloudKitEventStoreError.malformedRecord(record.recordID.recordName)
        }

        return EventEnvelope(
            id: id,
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: sequenceNumber.uint64Value,
            timestamp: timestamp,
            type: type,
            payload: payload,
            schemaVersion: schemaNumber.intValue,
            deduplicationKey: record["deduplicationKey"] as? String
        )
    }

    private static func createsSession(_ envelope: EventEnvelope) -> Bool {
        guard envelope.type == "anchor.operation.v1",
              let operation = try? JSONDecoder.anchor.decode(
                  SessionOperation.self,
                  from: envelope.payload
              ) else {
            return false
        }
        if case .createSession = operation { return true }
        return false
    }

    private static func eventSort(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        if lhs.sourceID != rhs.sourceID {
            return lhs.sourceID.uuidString < rhs.sourceID.uuidString
        }
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static let syncStateRecordID = CKRecord.ID(recordName: "anchor-current-session-v1")
}

public enum CloudKitEventStoreError: LocalizedError, Sendable, Hashable {
    case malformedRecord(String)
    case conflictingRecord(String)

    public var errorDescription: String? {
        switch self {
        case let .malformedRecord(recordName):
            "The iCloud Anchor record is malformed: \(recordName)."
        case let .conflictingRecord(recordName):
            "The iCloud Anchor record ID is already used by different content: \(recordName)."
        }
    }
}
#endif

/// Creates the optional production runner only when the containing app
/// declares `ANCHOR_CLOUDKIT_CONTAINER_IDENTIFIER`. This keeps local-first
/// development and Demo targets fully functional before the iCloud capability
/// is provisioned in the Apple developer account.
public enum AnchorCloudSyncFactory {
    public static func makeRunner(
        local: any EventBackedSessionRepository,
        containerIdentifier: String? = nil,
        interval: TimeInterval = 5
    ) -> DurableSyncRunner? {
        #if canImport(CloudKit)
        let identifier = containerIdentifier
            ?? (Bundle.main.object(forInfoDictionaryKey: "ANCHOR_CLOUDKIT_CONTAINER_IDENTIFIER") as? String)
        guard let identifier, !identifier.isEmpty else { return nil }
        let store = CloudKitEventStore(
            configuration: CloudKitEventStoreConfiguration(containerIdentifier: identifier)
        )
        let synchronizer = DurableEventSynchronizer(local: local, remote: store)
        return DurableSyncRunner(synchronizer: synchronizer, interval: interval)
        #else
        _ = local
        _ = containerIdentifier
        _ = interval
        return nil
        #endif
    }
}
