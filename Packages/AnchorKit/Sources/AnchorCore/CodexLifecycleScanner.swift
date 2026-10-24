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
    /// The conversation's working time through this record, and the start of
    /// a turn still open after it.
    var work = ConversationWork()
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
    /// Turns read so far. A checkpoint keeps only a Claude Code turn that is
    /// still open; tests and questions are not kept, so a resumed scan has not
    /// seen the turn start and never claims "not tested".
    private var reader: ConversationLogReader
    /// The agent's working time in the turns read so far.
    public private(set) var work = ConversationWork()
    /// A checkpoint from before working time was kept; the caller measures the
    /// part of the log already read before trusting `work`.
    public private(set) var needsWorkBackfill = false
    public init(dialect: ConversationDialect = .codex) {
        reader = ConversationLogReader(dialect: dialect)
    }
    private enum CodingKeys: String, CodingKey { case version, offset, dialect, openTurn, work }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .version) == 1 else {
            throw DecodingError.dataCorruptedError(forKey: .version, in: values, debugDescription: "Unsupported checkpoint")
        }
        offset = try values.decode(UInt64.self, forKey: .offset)
        committedOffset = offset
        reader = ConversationLogReader(
            dialect: (try? values.decodeIfPresent(ConversationDialect.self, forKey: .dialect)) ?? .codex,
            resuming: try? values.decodeIfPresent(ClaudeCodeTurnReader.Checkpoint.self, forKey: .openTurn)
        )
        if let work = try? values.decodeIfPresent(ConversationWork.self, forKey: .work) {
            self.work = work
        } else {
            needsWorkBackfill = offset > 0
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .version)
        try values.encode(committedOffset, forKey: .offset)
        try values.encode(work, forKey: .work)
        if reader.dialect != .codex {
            try values.encode(reader.dialect, forKey: .dialect)
            try values.encodeIfPresent(reader.claude.openTurn, forKey: .openTurn)
        }
    }

    public var dialect: ConversationDialect { reader.dialect }

    public init(checkpoint data: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: data)
    }
    public func checkpoint() throws -> Data { try JSONEncoder().encode(self) }

    func checkpoint(committedThrough offset: UInt64, work: ConversationWork? = nil) throws -> Data {
        guard offset <= committedOffset else {
            throw CodexLifecycleScannerError.invalidCommittedOffset
        }
        var copy = self
        copy.offset = offset
        copy.committedOffset = offset
        if let work { copy.work = work }
        copy.remainder.removeAll()
        copy.discardingOversizedLine = false
        return try copy.checkpoint()
    }

    /// The file reader must detect identity changes and truncation, then reset explicitly.
    public mutating func reset() { self = Self(dialect: reader.dialect) }

    /// Working time measured over the part of the log a backfilled checkpoint had read.
    public mutating func backfill(_ measured: ConversationWork) {
        work = measured
        needsWorkBackfill = false
    }

    public mutating func append(_ data: Data) -> [CodexLifecycleRecord] {
        appendWithOffsets(data).map(\.record)
    }

    mutating func appendWithOffsets(_ data: Data) -> [CodexLifecycleScannedRecord] {
        var records: [CodexLifecycleScannedRecord] = []
        for byte in data {
            offset += 1
            if byte == 10 {
                let read = discardingOversizedLine ? [] : reader.read(remainder)
                remainder.removeAll(keepingCapacity: true)
                discardingOversizedLine = false
                committedOffset = offset
                records += read.map { scanned($0, at: offset) }
            } else if !discardingOversizedLine {
                if remainder.count < maximumLineBytes {
                    remainder.append(byte)
                } else {
                    remainder.removeAll(keepingCapacity: true)
                    discardingOversizedLine = true
                }
            }
        }
        // A reply written as several entries is complete once this read ends.
        records += reader.flush().map { scanned($0, at: committedOffset) }
        return records
    }

    private mutating func scanned(_ read: TurnLogRecord, at offset: UInt64) -> CodexLifecycleScannedRecord {
        work.note(read.record, duration: read.end?.duration)
        return CodexLifecycleScannedRecord(record: read.record, committedOffset: offset, end: read.end,
                                           tests: read.tests, waitingForReply: read.waitingForReply, work: work)
    }
}
