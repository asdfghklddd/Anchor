import Foundation

/// How long the agent has worked in one conversation: the sum of its turns,
/// each from its start to its end (the duration the agent reports when it
/// reports one), read from the log on the Mac.
public struct ConversationWork: Codable, Hashable, Sendable {
    /// Turns that have ended.
    public private(set) var seconds: TimeInterval = 0
    /// When the turn still running started.
    public private(set) var openTurnStart: Date?

    public init(seconds: TimeInterval = 0, openTurnStart: Date? = nil) {
        self.seconds = seconds
        self.openTurnStart = openTurnStart
    }

    mutating func note(_ record: CodexLifecycleRecord, duration: TimeInterval?) {
        switch record.lifecycle {
        case .started:
            // A turn that never reported its end counts up to the next start.
            if let start = openTurnStart { seconds += max(0, record.timestamp.timeIntervalSince(start)) }
            openTurnStart = record.timestamp
        case .completed, .aborted:
            if let duration, duration > 0 {
                seconds += duration
            } else if let start = openTurnStart {
                seconds += max(0, record.timestamp.timeIntervalSince(start))
            }
            openTurnStart = nil
        }
    }

    /// Working time as of `now`, counting the turn still running.
    public func total(at now: Date) -> TimeInterval {
        seconds + (openTurnStart.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// Measures the first `length` bytes of a log, for a checkpoint written
    /// before working time was kept.
    public static func measure(_ url: URL, dialect: ConversationDialect, upTo length: UInt64) -> ConversationWork? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var scanner = CodexIncrementalScanner(dialect: dialect)
        var remaining = length
        while remaining > 0, let chunk = try? handle.read(upToCount: Int(min(remaining, 4 << 20))), !chunk.isEmpty {
            _ = scanner.appendWithOffsets(chunk)
            remaining -= UInt64(chunk.count)
        }
        return scanner.work
    }
}

public extension AnchorProcess {
    /// The agent's working time in this conversation as of `now`: what the Mac
    /// counted, plus the turn still running. `nil` when the Mac did not count it.
    func workedTime(at now: Date) -> TimeInterval? {
        guard let workedSeconds else { return nil }
        guard status == .running else { return workedSeconds }
        return workedSeconds + max(0, now.timeIntervalSince(updatedAt))
    }
}
