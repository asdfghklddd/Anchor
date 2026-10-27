import Foundation

/// What the Mac saw of the person's working day: tokens agents used per half
/// hour, and when the phone's Bluetooth link was up. It is a snapshot that the
/// next one replaces, so it travels outside the event history.
public struct DayActivity: Codable, Hashable, Sendable {
    public static let envelopeType = "anchor.activity.v1"
    public static let slotLength: TimeInterval = 30 * 60

    public struct TokenSlot: Codable, Hashable, Sendable {
        /// The slot's start, on a half-hour boundary.
        public let start: Date
        public let tokens: Int

        public init(start: Date, tokens: Int) {
            self.start = start
            self.tokens = tokens
        }
    }

    public let tokens: [TokenSlot]
    /// Closed link intervals the Mac recorded, plus the open one up to `writtenAt`.
    public let links: [DateInterval]
    public let writtenAt: Date

    public init(tokens: [TokenSlot], links: [DateInterval], writtenAt: Date = .now) {
        self.tokens = tokens
        self.links = links
        self.writtenAt = writtenAt
    }

    public static func slotStart(of date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / slotLength).rounded(.down) * slotLength)
    }

    public func envelope(sourceID: UUID) throws -> EventEnvelope {
        EventEnvelope(sessionID: UUID(), sourceID: sourceID, sequence: 0, timestamp: writtenAt,
                      type: Self.envelopeType, payload: try JSONEncoder.anchor.encode(self))
    }

    public init?(envelope: EventEnvelope) {
        guard envelope.type == Self.envelopeType,
              let activity = try? JSONDecoder.anchor.decode(DayActivity.self, from: envelope.payload) else { return nil }
        self = activity
    }
}

/// Time anchored at the desk: the union of link intervals, cut to one day.
public enum AnchoringTime {
    /// Merged, sorted intervals with overlaps joined.
    public static func union(_ intervals: [DateInterval]) -> [DateInterval] {
        var merged: [DateInterval] = []
        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    /// Seconds of `intervals` that fall on the day containing `day`.
    public static func total(_ intervals: [DateInterval], on day: Date, calendar: Calendar = .current) -> TimeInterval {
        guard let today = calendar.dateInterval(of: .day, for: day) else { return 0 }
        return union(intervals).reduce(0) { sum, interval in
            sum + (interval.intersection(with: today)?.duration ?? 0)
        }
    }
}
