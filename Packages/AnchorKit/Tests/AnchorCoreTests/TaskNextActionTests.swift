import Foundation
import Testing
@testable import AnchorCore

@Suite("Task next action")
struct TaskNextActionTests {
    private let now = Date(timeIntervalSince1970: 1_792_137_600)

    private func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

    private func codex(_ title: String, _ status: ProcessStatus, at date: Date, interrupted: Bool = false) -> AnchorProcess {
        let sourceID = UUID()
        let started = ProcessEvent(sourceID: sourceID, occurredAt: date.addingTimeInterval(-300), kind: .created, title: "Codex task_started")
        var events = [started]
        if status == .completed {
            events.append(ProcessEvent(sourceID: sourceID, occurredAt: date, kind: .completed, title: "Codex task_complete"))
        } else if status == .failed {
            events.append(ProcessEvent(sourceID: sourceID, occurredAt: date, kind: .failed,
                                       title: interrupted ? "Codex turn_aborted" : "Codex error"))
        }
        return AnchorProcess(sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                             title: title, status: status, updatedAt: date, events: events)
    }

    private func task(_ plan: AnchorUserPlan?, _ processes: [AnchorProcess] = []) -> AnchorSession {
        AnchorSession(goal: AnchorGoal(title: "Data structures homework", completionCriteria: "Tests pass", userPlan: plan),
                      startedAt: ago(120), processes: processes)
    }

    @Test("A task without written steps has no plan to follow")
    func noPlanNoAction() {
        #expect(TaskNextAction(task: task(nil)) == nil)
        #expect(TaskNextAction(task: task(AnchorUserPlan(steps: []))) == nil)
    }

    @Test("With nothing running or waiting, the next open step of the person's plan comes next")
    func nextOpenStep() throws {
        let plan = try #require(AnchorUserPlan(steps: ["Insert", "Delete", "Edge cases"]).marking(step: 0, done: true, at: ago(30)))
        #expect(TaskNextAction(task: task(plan)) == .start(step: 1, text: "Delete"))
    }

    @Test("A running agent means waiting; a result it finished afterwards asks for a look")
    func waitThenReview() throws {
        let plan = try #require(AnchorUserPlan(steps: ["Insert", "Delete"]).marking(step: 0, done: true, at: ago(30)))
        let running = codex("Anchor", .running, at: ago(2))
        #expect(TaskNextAction(task: task(plan, [running])) == .wait(process: "Anchor", since: ago(7)))
        #expect(TaskNextAction(task: task(plan, [running]))?.needsPerson == false)

        let finished = codex("Anchor", .completed, at: ago(1))
        #expect(TaskNextAction(task: task(plan, [finished])) == .review(process: "Anchor"))
        // A finished result outranks waiting on another conversation.
        #expect(TaskNextAction(task: task(plan, [finished, codex("Other", .running, at: ago(2))])) == .review(process: "Anchor"))
    }

    @Test("Answering for the step, or saying not yet, counts as having looked")
    func lookingClearsTheReview() throws {
        let finished = codex("Anchor", .completed, at: ago(5))
        let plan = AnchorUserPlan(steps: ["Insert", "Delete"])
        #expect(TaskNextAction(task: task(plan, [finished])) == .review(process: "Anchor"))

        let notYet = plan.markingReviewed(at: ago(1))
        #expect(TaskNextAction(task: task(notYet, [finished])) == .start(step: 0, text: "Insert"))

        let done = try #require(plan.marking(step: 0, done: true, at: ago(1)))
        #expect(TaskNextAction(task: task(done, [finished])) == .start(step: 1, text: "Delete"))
    }

    @Test("An unseen failure comes first; a turn the person stopped is not a failure")
    func failuresFirst() {
        let plan = AnchorUserPlan(steps: ["Insert"])
        let failed = codex("Website", .failed, at: ago(3))
        let finished = codex("Anchor", .completed, at: ago(1))
        #expect(TaskNextAction(task: task(plan, [finished, failed])) == .fix(process: "Website"))

        let stopped = codex("Website", .failed, at: ago(1), interrupted: true)
        #expect(TaskNextAction(task: task(plan, [stopped])) == .start(step: 0, text: "Insert"))
    }

    @Test("Every step done means offering to finish, which stays the person's decision")
    func allDone() throws {
        var plan = AnchorUserPlan(steps: ["Insert", "Delete"])
        plan = try #require(plan.marking(step: 0, done: true, at: ago(2)))
        plan = try #require(plan.marking(step: 1, done: true, at: ago(1)))
        #expect(TaskNextAction(task: task(plan, [codex("Anchor", .completed, at: ago(3))])) == .finish)
    }
}
