import Foundation
import Testing
@testable import AnchorCore

@Suite("Return overview")
struct ReturnOverviewTests {
    private let now = Date(timeIntervalSince1970: 1_792_137_600)

    private func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

    private func codex(_ title: String, _ status: ProcessStatus, at date: Date) -> AnchorProcess {
        let sourceID = UUID()
        var events = [ProcessEvent(sourceID: sourceID, occurredAt: date.addingTimeInterval(-300), kind: .created,
                                   title: "Codex task_started")]
        if status == .completed || status == .failed {
            events.append(ProcessEvent(sourceID: sourceID, occurredAt: date, kind: status == .completed ? .completed : .failed,
                                       title: status == .completed ? "Codex task_complete" : "Codex error"))
        }
        return AnchorProcess(sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                             title: title, status: status, updatedAt: date, events: events)
    }

    private func task(_ title: String, plan: AnchorUserPlan?, _ processes: [AnchorProcess] = [],
                      status: SessionStatus = .active) -> AnchorSession {
        AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "", userPlan: plan), status: status,
                      startedAt: ago(240), processes: processes)
    }

    @Test("Every task that changed while away is listed, the one that needs the person first")
    func ordersByWhatNeedsYou() {
        let homework = task("Homework", plan: AnchorUserPlan(steps: ["Insert", "Delete"]),
                            [codex("rb-delete", .completed, at: ago(5)), codex("rb-insert", .completed, at: ago(90))])
        let website = task("Website", plan: AnchorUserPlan(steps: ["Deploy"]), [codex("deploy", .failed, at: ago(20))])
        let notes = task("Notes", plan: AnchorUserPlan(steps: ["Tidy"]), [codex("notes", .running, at: ago(10))])
        let quiet = task("Reading", plan: AnchorUserPlan(steps: ["Chapter 3"]))

        let overview = ReturnOverview(tasks: [homework, notes, quiet, website], awaySince: ago(60))

        #expect(overview.items.map(\.task.goal.title) == ["Website", "Homework", "Notes"])
        #expect(overview.first?.action == .fix(process: "deploy"))
        // Only what reported after leaving is news, newest first.
        #expect(overview.items[1].changes.map(\.title) == ["rb-delete"])
        #expect(overview.unchangedCount == 1)
    }

    @Test("A result from before leaving is not news, but one never looked at still asks for a look")
    func unseenResultFromBeforeLeaving() throws {
        let plan = AnchorUserPlan(steps: ["Insert"])
        let early = task("Homework", plan: plan, [codex("rb-insert", .completed, at: ago(90))])

        let overview = ReturnOverview(tasks: [early], awaySince: ago(60))
        let item = try #require(overview.first)
        #expect(item.changes.isEmpty)
        #expect(item.action == .review(process: "rb-insert"))

        let looked = task("Homework", plan: plan.markingReviewed(at: ago(70)), [codex("rb-insert", .completed, at: ago(90))])
        #expect(ReturnOverview(tasks: [looked], awaySince: ago(60)).items.isEmpty)
    }

    @Test("Without written steps a failure still comes first, then a finished result")
    func tasksWithoutStepsByState() {
        let stopped = task("Migration", plan: nil, [codex("migrate", .running, at: ago(3))])
        let notes = task("Notes", plan: nil, [codex("notes", .completed, at: ago(6))])
        let login = task("Login", plan: nil, [codex("login", .failed, at: ago(11))])

        let overview = ReturnOverview(tasks: [stopped, notes, login], awaySince: ago(45))

        #expect(overview.items.map(\.task.goal.title) == ["Login", "Notes", "Migration"])
    }

    @Test("Finished tasks are left out; without a time away nothing counts as a change")
    func finishedTasksAndNoAwayTime() {
        let finished = task("Old", plan: AnchorUserPlan(steps: ["Ship"]), [codex("ship", .completed, at: ago(5))],
                            status: .completed)
        let running = task("Notes", plan: AnchorUserPlan(steps: ["Tidy"]), [codex("notes", .running, at: ago(5))])

        let overview = ReturnOverview(tasks: [finished, running], awaySince: nil)

        #expect(overview.items.isEmpty)
        #expect(overview.unchangedCount == 1)
    }
}
