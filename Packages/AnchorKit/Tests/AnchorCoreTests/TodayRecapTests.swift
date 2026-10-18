import Foundation
import Testing
@testable import AnchorCore

@Suite("Today recap")
struct TodayRecapTests {
    private let now = Date(timeIntervalSince1970: 1_792_224_000) // 2026-10-18 08:00 UTC
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test("Steps finished today, tasks moved and finished, and what still waits")
    func recap() throws {
        let homeworkPlan = try #require(AnchorUserPlan(steps: ["Insert", "Delete", "Report"])
            .marking(step: 0, done: true, at: now.addingTimeInterval(-30 * 3_600))?   // yesterday
            .marking(step: 1, done: true, at: now.addingTimeInterval(-3_600)))
        let homework = AnchorSession(goal: AnchorGoal(title: "Homework", completionCriteria: "", userPlan: homeworkPlan),
                                     status: .active, startedAt: now.addingTimeInterval(-50 * 3_600))
        let failed = AnchorProcess(sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan", title: "deploy",
                                   status: .failed, updatedAt: now.addingTimeInterval(-600))
        let website = AnchorSession(goal: AnchorGoal(title: "Website", completionCriteria: "",
                                                     userPlan: AnchorUserPlan(steps: ["Deploy"])),
                                    status: .active, startedAt: now.addingTimeInterval(-7_200), processes: [failed])
        var notes = AnchorSession(goal: AnchorGoal(title: "Notes", completionCriteria: ""), status: .completed,
                                  startedAt: now.addingTimeInterval(-7_200))
        notes.completedAt = now.addingTimeInterval(-1_800)

        let recap = TodayRecap(open: [homework, website], archived: [notes], now: now, calendar: calendar)
        #expect(recap.finishedSteps.map(\.text) == ["Delete"])
        #expect(recap.finishedTasks.map(\.goal.title) == ["Notes"])
        #expect(recap.movedTaskCount == 3)
        #expect(recap.needsYou.map(\.task.goal.title) == ["Website"])
        #expect(!recap.isEmpty)

        let quiet = TodayRecap(open: [AnchorSession(goal: AnchorGoal(title: "New", completionCriteria: ""),
                                                    startedAt: now.addingTimeInterval(-60))],
                               archived: [], now: now, calendar: calendar)
        #expect(quiet.isEmpty)
    }
}
