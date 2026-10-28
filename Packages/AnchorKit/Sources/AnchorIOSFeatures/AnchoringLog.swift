#if os(iOS)
import AnchorCore
import Foundation
import Observation

/// Time anchored at the desk: from the moment the Bluetooth link to the Mac
/// comes up until it drops. Each day keeps its own total, so the home starts
/// at zero after midnight and earlier days move to History. The Mac keeps its
/// own record of the link, which fills the gaps while iOS had Anchor suspended.
@MainActor
@Observable
public final class AnchoringLog {
    public static let shared: AnchoringLog = {
        let log = AnchoringLog()
        // The desk pet stays up while the person is anchored and cheers today's goal.
        DeskPetLife.anchoring = { now in
            let goal = UserDefaults.standard.object(forKey: goalKey) as? Int ?? defaultGoalMinutes
            return (log.linkedSince != nil, log.total(now: now) >= TimeInterval(goal * 60))
        }
        return log
    }()
    static let goalKey = "anchor.anchoring.goalMinutes"
    static let defaultGoalMinutes = 240

    private(set) var linkedSince: Date?
    private var links: [DateInterval]
    /// The Mac's latest day: its link record and the tokens used per half hour.
    private(set) var macActivity: DayActivity?
    private let defaults: UserDefaults
    @ObservationIgnored private var lastSeenWrite = Date.distantPast

    private static let linksKey = "anchor.anchoring.links"
    private static let sinceKey = "anchor.anchoring.since"
    private static let seenKey = "anchor.anchoring.seen"
    private static let macKey = "anchor.anchoring.mac"
    /// History keeps this many days.
    private static let kept: TimeInterval = 120 * 86_400

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        links = defaults.data(forKey: Self.linksKey)
            .flatMap { try? JSONDecoder().decode([DateInterval].self, from: $0) } ?? []
        macActivity = defaults.data(forKey: Self.macKey)
            .flatMap { try? JSONDecoder().decode(DayActivity.self, from: $0) }
        // A link left open by a quit app ends where Anchor last saw it.
        if let since = defaults.object(forKey: Self.sinceKey) as? Date {
            let seen = defaults.object(forKey: Self.seenKey) as? Date ?? since
            if seen > since { links.append(DateInterval(start: since, end: seen)) }
            defaults.removeObject(forKey: Self.sinceKey)
            save()
        }
    }

    public func linkChanged(connected: Bool, at now: Date = .now) {
        if connected {
            guard linkedSince == nil else { return }
            linkedSince = now
            defaults.set(now, forKey: Self.sinceKey)
            defaults.set(now, forKey: Self.seenKey)
        } else if let start = linkedSince {
            linkedSince = nil
            if now > start { links.append(DateInterval(start: start, end: now)) }
            defaults.removeObject(forKey: Self.sinceKey)
            save()
        }
    }

    /// Takes the Mac's snapshot; returns false for any other envelope.
    public nonisolated static func receive(_ envelope: EventEnvelope) -> Bool {
        guard let activity = DayActivity(envelope: envelope) else { return envelope.type == DayActivity.envelopeType }
        Task { @MainActor in shared.take(activity) }
        return true
    }

    func take(_ activity: DayActivity) {
        guard activity.writtenAt >= (macActivity?.writtenAt ?? .distantPast) else { return }
        macActivity = activity
        if let data = try? JSONEncoder().encode(activity) { defaults.set(data, forKey: Self.macKey) }
    }

    private func intervals(now: Date) -> [DateInterval] {
        var all = links + (macActivity?.links ?? [])
        if let linkedSince, now > linkedSince { all.append(DateInterval(start: linkedSince, end: now)) }
        return all
    }

    /// Seconds anchored on the day containing `now`.
    func total(now: Date) -> TimeInterval {
        if linkedSince != nil, now.timeIntervalSince(lastSeenWrite) > 60 {
            lastSeenWrite = now
            defaults.set(now, forKey: Self.seenKey)
        }
        return AnchoringTime.total(intervals(now: now), on: now)
    }

    /// Earlier days with time anchored, newest first.
    func history(now: Date, calendar: Calendar = .current) -> [(day: Date, seconds: TimeInterval)] {
        let today = calendar.startOfDay(for: now)
        let days = Set(intervals(now: now).flatMap { interval -> [Date] in
            var day = calendar.startOfDay(for: interval.start)
            var result: [Date] = []
            while day < interval.end, day < today {
                result.append(day)
                day = calendar.date(byAdding: .day, value: 1, to: day) ?? interval.end
            }
            return result
        })
        return days.sorted(by: >).map { ($0, AnchoringTime.total(intervals(now: now), on: $0, calendar: calendar)) }
            .filter { $0.seconds >= 60 }
    }

    /// Tokens per half-hour slot start.
    var tokens: [Date: Int] {
        Dictionary((macActivity?.tokens ?? []).map { ($0.start, $0.tokens) }, uniquingKeysWith: +)
    }

    // MARK: The tour

    private static let tourSuite = "anchor.tour.anchoring"

    /// A day already under way, kept apart from the person's own: linked
    /// through the morning, a break, linked again since a little while ago,
    /// and the agents' tokens for the hours so far.
    static func tour(now: Date) -> AnchoringLog {
        clearTour()
        // A fixed, valid suite name always opens.
        let log = AnchoringLog(defaults: UserDefaults(suiteName: tourSuite)!)
        log.links = [DateInterval(start: now - 16_800, end: now - 10_200),
                     DateInterval(start: now - 6_900, end: now - 2_100)]
        log.linkChanged(connected: true, at: now - 1_500)
        let current = DayActivity.slotStart(of: now)
        let shape = [0, 4, 12, 30, 48, 22, 8, 0, 6, 18, 41, 63, 52, 37, 44, 26]
        let slots = shape.enumerated().map { index, thousands in
            DayActivity.TokenSlot(start: current - Double(shape.count - 1 - index) * DayActivity.slotLength,
                                  tokens: thousands * 1_000)
        }
        log.take(DayActivity(tokens: slots, links: [], writtenAt: now))
        return log
    }

    static func clearTour() {
        UserDefaults(suiteName: tourSuite)?.removePersistentDomain(forName: tourSuite)
    }

    private func save() {
        let floor = Date.now.addingTimeInterval(-Self.kept)
        links = AnchoringTime.union(links).filter { $0.end > floor }
        if let data = try? JSONEncoder().encode(links) { defaults.set(data, forKey: Self.linksKey) }
    }
}
#endif
