import Foundation
import Testing
import AnchorCore
@testable import AnchorIOSFeatures

@Suite("Me page numbers")
struct ProfileStatsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Wednesday 2026-11-04, 15:00 in Shanghai.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 15))!
    }

    private func day(_ back: Int) -> Date {
        calendar.date(byAdding: .day, value: -back, to: calendar.startOfDay(for: now))!
    }

    @Test func theWeekRunsFromItsFirstDayAndLeavesTheFutureEmpty() {
        let week = ProfileStats.week(now: now, calendar: calendar) { _ in 600 }
        #expect(week.count == 7)
        #expect(week[0].date == day(2)) // Monday
        #expect(week.filter(\.isToday).map(\.date) == [day(0)])
        #expect(week.map(\.isAhead) == [false, false, false, true, true, true, true])
        #expect(week.map(\.seconds) == [600, 600, 600, 0, 0, 0, 0])
    }

    @Test func aStreakCountsBackUntilTheFirstEmptyDay() {
        let anchored = Set([day(0), day(1), day(2), day(4)])
        let streak = ProfileStats.streak(now: now, calendar: calendar) { anchored.contains($0) ? 3_600 : 0 }
        #expect(streak == 3)
    }

    @Test func nothingAnchoredYetTodayDoesNotBreakAStreak() {
        let anchored = Set([day(1), day(2)])
        let streak = ProfileStats.streak(now: now, calendar: calendar) { anchored.contains($0) ? 3_600 : 0 }
        #expect(streak == 2)
    }

    @Test func aFewSecondsDoNotKeepAStreakAlive() {
        let streak = ProfileStats.streak(now: now, calendar: calendar) { _ in 59 }
        #expect(streak == 0)
    }

    @Test func onlyFinishedTasksCountNewestFirst() {
        let older = task("Older", completedAt: now - 7_200)
        let newer = task("Newer", completedAt: now - 3_600)
        let shelved = task("Shelved", completedAt: nil)
        let finished = ProfileStats.finished(in: projection(archived: [older, shelved, newer]))
        #expect(finished.map(\.goal.title) == ["Newer", "Older"])
    }

    @Test func agentTimeAddsUpAcrossTasksIncludingFinishedOnes() {
        let current = task("Current", processes: [process("Claude Code", worked: 3_600),
                                                  process("Codex", worked: nil)])
        let done = task("Done", completedAt: now, processes: [process("Claude Code", worked: 1_800),
                                                              process("Codex", worked: 7_200)])
        let groups = SourceGroup.all(in: projection(hosted: current, archived: [done]))
        #expect(groups.map(\.name) == ["Codex", "Claude Code"])
        #expect(groups.map(\.workedSeconds) == [7_200, 5_400])
        #expect(groups.map(\.conversations.count) == [2, 2])
    }

    @Test func returnsCountEveryRecapAcrossTasks() {
        var current = task("Current")
        current.returnRecaps = [ReturnRecap(returnedAt: now, conversations: [])]
        var done = task("Done", completedAt: now)
        done.returnRecaps = [ReturnRecap(returnedAt: now - 60, conversations: []),
                             ReturnRecap(returnedAt: now - 120, conversations: [])]
        #expect(ProfileStats.returns(in: projection(hosted: current, archived: [done])) == 3)
    }

    private func task(_ title: String, completedAt: Date? = nil, processes: [AnchorProcess] = []) -> AnchorSession {
        AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "", note: ""),
                      status: completedAt == nil ? .active : .completed,
                      completedAt: completedAt, processes: processes)
    }

    private func process(_ source: String, worked: TimeInterval?) -> AnchorProcess {
        var process = AnchorProcess(sourceName: source, sourceSymbol: "S", sourceTone: "cyan", title: "Work", status: .completed)
        process.workedSeconds = worked
        return process
    }

    private func projection(hosted: AnchorSession? = nil, archived: [AnchorSession]) -> SessionProjection {
        var projection = SessionProjection.empty
        projection.session = hosted
        projection.archivedSessions = archived
        return projection
    }
}
