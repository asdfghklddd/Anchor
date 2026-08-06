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

    public init(
        containerIdentifier: String,
        recordType: String = "AnchorEventEnvelope"
    ) {
        self.containerIdentifier = containerIdentifier
        self.recordType = recordType
    }
}

/// Private-database event storage for the durable-away/offline path. The
/// containing app must enable the matching iCloud container entitlement and
/// deploy the `AnchorEventEnvelope` record schema before constructing it.
public actor CloudKitEventStore: DurableEventStore {
    private let database: CKDatabase
    private let recordType: String

    public init(configuration: CloudKitEventStoreConfiguration) {
        database = CKContainer(identifier: configuration.containerIdentifier).privateCloudDatabase
        recordType = configuration.recordType
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
    }

    public func events(
        for sessionID: UUID,
        onOrAfter date: Date?
    ) async throws -> [EventEnvelope] {
        let predicate: NSPredicate
        if let date {
            predicate = NSPredicate(
                format: "sessionID == %@ AND timestamp >= %@",
                sessionID.uuidString,
                date as NSDate
            )
        } else {
            predicate = NSPredicate(format: "sessionID == %@", sessionID.uuidString)
        }
        let query = CKQuery(recordType: recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: true)]

        var cursor: CKQueryOperation.Cursor?
        var records: [CKRecord] = []
        repeat {
            let page = try await fetch(query: query, cursor: cursor)
            records.append(contentsOf: page.records)
            cursor = page.cursor
        } while cursor != nil

        return try records.compactMap(Self.decode)
    }

    private func fetch(
        query: CKQuery,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        let response: (
            matchResults: [(CKRecord.ID, Result<CKRecord, any Error>)],
            queryCursor: CKQueryOperation.Cursor?
        )
        if let cursor {
            response = try await database.records(
                continuingMatchFrom: cursor,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )
        } else {
            response = try await database.records(
                matching: query,
                inZoneWith: nil,
                desiredKeys: nil,
                resultsLimit: CKQueryOperation.maximumResults
            )
        }
        let records = try response.matchResults.map { try $0.1.get() }
        return (records: records, cursor: response.queryCursor)
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
        interval: TimeInterval = 60
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
