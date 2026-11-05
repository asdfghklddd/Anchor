#if os(iOS)
import AnchorCore
import Foundation

/// One day of the Me page's week.
struct ProfileWeekDay: Identifiable, Equatable {
    let date: Date
    let seconds: TimeInterval
    let isToday: Bool
    /// Still to come this week, so it has nothing to show yet.
    let isAhead: Bool

    var id: Date { date }
}

/// The Me page's numbers, each one counted from what this phone really holds.
enum ProfileStats {
    /// A day needs this much anchoring to count, the same bar History uses.
    private static let countedDay: TimeInterval = 60
    /// How far back a streak can reach: the anchoring log keeps 120 days.
    private static let longestStreak = 120

    /// This calendar week, first day first.
    static func week(now: Date, calendar: Calendar = .current,
                     seconds: (Date) -> TimeInterval) -> [ProfileWeekDay] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        let today = calendar.startOfDay(for: now)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let isAhead = day > today
            return ProfileWeekDay(date: day, seconds: isAhead ? 0 : seconds(day),
                                  isToday: day == today, isAhead: isAhead)
        }
    }

    /// Days in a row with anchoring. Today not being anchored yet doesn't break it.
    static func streak(now: Date, calendar: Calendar = .current,
                       seconds: (Date) -> TimeInterval) -> Int {
        let today = calendar.startOfDay(for: now)
        var count = 0
        for back in 0...longestStreak {
            guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { break }
            if seconds(day) >= countedDay {
                count += 1
            } else if back > 0 {
                break
            }
        }
        return count
    }

    /// Tasks the person finished, newest first. A task archived without being
    /// finished stays in History but isn't counted here.
    static func finished(in projection: SessionProjection) -> [AnchorSession] {
        projection.archivedSessions
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Times the person came back to a task and got its recap.
    static func returns(in projection: SessionProjection) -> Int {
        (projection.hostedSessions + projection.archivedSessions)
            .reduce(0) { $0 + ($1.returnRecaps?.count ?? 0) }
    }
}
#endif
