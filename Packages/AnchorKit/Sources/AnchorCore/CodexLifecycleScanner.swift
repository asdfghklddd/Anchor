import Foundation

public enum CodexLifecycleScanner {
    public static func scan(data: Data) -> [CodexLifecycleRecord] {
        var scanner = CodexIncrementalScanner()
        return scanner.append(data)
    }
}

struct CodexLifecycleScannedRecord: Sendable {
    let record: CodexLifecycleRecord
    let committedOffset: UInt64
    /// For a `task_complete` line: its reply preview, duration and error.
    var end: CodexTurnEnd? = nil
    /// For a `task_complete` line: how the turn's tests ended, if it ran any.
    var tests: TestOutcome? = nil
    /// For a `task_complete` line: the turn ended with a question still open.
    var waitingForReply = false
}

enum CodexLifecycleScannerError: Error {
    case invalidCommittedOffset
}

/// Checkpoints contain only a complete-line byte boundary, never raw log bytes.
/// After recreation the caller seeks to offset and rereads any partial line.
public struct CodexIncrementalScanner: Codable, Sendable {
    public private(set) var offset: UInt64 = 0
    private var committedOffset: UInt64 = 0
    private var remainder = Data()
    private var discardingOversizedLine = false
    private var maximumLineBytes = 2 * 1_024 * 1_024
    /// The current turn's tests and open question. Not checkpointed: a resumed
    /// scan has not seen the turn start, so it never claims "not tested".
    private var facts = CodexTurnFacts()
    public init() {}
    private enum CodingKeys: String, CodingKey { case version, offset }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .version) == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .version, in: values, debugDescription: "Unsupported checkpoint")
        }
        offset = try values.decode(UInt64.self, forKey: .offset)
        committedOffset = offset
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .version)
        try values.encode(committedOffset, forKey: .offset)
    }

    public init(checkpoint data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
    public func checkpoint() throws -> Data { try JSONEncoder().encode(self) }

    func checkpoint(committedThrough offset: UInt64) throws -> Data {
        guard offset <= committedOffset else {
            throw CodexLifecycleScannerError.invalidCommittedOffset
        }
        var copy = self
        copy.offset = offset
        copy.committedOffset = offset
        copy.remainder.removeAll()
        copy.discardingOversizedLine = false
        return try copy.checkpoint()
    }

    /// The file reader must detect identity changes and truncation, then reset explicitly.
    public mutating func reset() { self = Self() }

    public mutating func append(_ data: Data) -> [CodexLifecycleRecord] {
        appendWithOffsets(data).map(\.record)
    }

    mutating func appendWithOffsets(_ data: Data) -> [CodexLifecycleScannedRecord] {
        var records: [CodexLifecycleScannedRecord] = []
        for byte in data {
            offset += 1
            if byte == 10 {
                let record = discardingOversizedLine ? nil : CodexLifecycleRecord(json: remainder)
                if record == nil, !discardingOversizedLine { facts.consume(remainder) }
                var scanned = record.map { CodexLifecycleScannedRecord(record: $0, committedOffset: offset) }
                switch record?.lifecycle {
                case .started?:
                    facts.turnStarted()
                case .completed?:
                    let end = CodexTurnEnd(json: remainder)
                    scanned?.end = end
                    scanned?.tests = facts.tests(duration: end?.duration)
                    scanned?.waitingForReply = facts.isWaitingForReply(turnEnded: true)
                case .aborted?, nil:
                    break
                }
                remainder.removeAll(keepingCapacity: true)
                discardingOversizedLine = false
                committedOffset = offset
                if let scanned { records.append(scanned) }
            } else if !discardingOversizedLine {
                if remainder.count < maximumLineBytes {
                    remainder.append(byte)
                } else {
                    remainder.removeAll(keepingCapacity: true)
                    discardingOversizedLine = true
                }
            }
        }
        return records
    }
}
