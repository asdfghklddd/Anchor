import Foundation
import Testing
@testable import AnchorCore

@Suite("Meanwhile and the desk hold")
struct TaskMeanwhileTests {
    private let now = Date(timeIntervalSince1970: 1_792_137_600)

    private func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

    private func codex(_ title: String, _ status: ProcessStatus, at date: Date, step: UUID? = nil) -> AnchorProcess {
        let sourceID = UUID()
        var events = [ProcessEvent(sourceID: sourceID, occurredAt: date.addingTimeInterval(-300), kind: .created,
                                   title: "Codex task_started")]
        if status == .completed {
            events.append(ProcessEvent(sourceID: sourceID, occurredAt: date, kind: .completed, title: "Codex task_complete"))
        } else if status == .failed {
            events.append(ProcessEvent(sourceID: sourceID, occurredAt: date, kind: .failed, title: "Codex error"))
        }
        var process = AnchorProcess(sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                                    title: title, status: status, updatedAt: date, events: events)
        process.stepID = step
        return process
    }

    private func task(_ title: String, _ steps: [String], done: [Int] = [], started: Double,
                      _ processes: [AnchorProcess] = []) throws -> AnchorSession {
        var plan = AnchorUserPlan(steps: steps)
        for index in done { plan = try #require(plan.marking(step: index, done: true, at: ago(200))) }
        return AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "", userPlan: plan),
                             startedAt: ago(started), processes: processes)
    }

    @Test("Only a task waiting on its agent has a meanwhile")
    func onlyWhileWaiting() throws {
        let idle = try task("Homework", ["Insert", "Delete"], started: 60)
        #expect(TaskMeanwhile(current: idle, among: [idle]) == nil)
        let finished = try task("Homework", ["Insert", "Delete"], started: 60, [codex("Insert", .completed, at: ago(1))])
        #expect(TaskMeanwhile(current: finished, among: [finished]) == nil)
    }

    @Test("While the agent works, another task that needs the person comes next")
    func pointsAtAnotherTask() throws {
        let homework = try task("Homework", ["Insert", "Delete"], started: 90, [codex("Insert", .running, at: ago(2))])
        let website = try task("Website", ["Hero", "Footer"], started: 60, [codex("Hero", .completed, at: ago(5))])
        let meanwhile = try #require(TaskMeanwhile(current: homework, among: [homework, website]))
        #expect(meanwhile == .other(task: website.id, title: "Website", action: .review(process: "Hero")))
        #expect(meanwhile.taskID == website.id)
    }

    @Test("A question beats a failure, a failure beats a result, a result beats a step to start")
    func readingOrder() throws {
        let current = try task("Homework", ["Insert"], started: 100, [codex("Insert", .running, at: ago(1))])
        let start = try task("Notes", ["Outline"], started: 90)
        let review = try task("Website", ["Hero"], started: 80, [codex("Hero", .completed, at: ago(30))])
        let fix = try task("Thesis", ["Draft"], started: 70, [codex("Draft", .failed, at: ago(3))])
        var asking = codex("Slides", .needsDecision, at: ago(1))
        asking.events = [ProcessEvent(sourceID: asking.sourceID, occurredAt: ago(1), kind: .decisionRequired, title: "ask")]
        let answer = try task("Slides", ["Deck"], started: 60, [asking])

        let all = [current, start, review, fix, answer]
        #expect(TaskMeanwhile(current: current, among: all)?.taskID == answer.id)
        #expect(TaskMeanwhile(current: current, among: [current, start, review, fix])?.taskID == fix.id)
        #expect(TaskMeanwhile(current: current, among: [current, start, review])?.taskID == review.id)
        #expect(TaskMeanwhile(current: current, among: [current, start])?.taskID == start.id)
    }

    @Test("Between two results, the one that has waited longest comes first")
    func longestWaitingFirst() throws {
        let current = try task("Homework", ["Insert"], started: 100, [codex("Insert", .running, at: ago(1))])
        let fresh = try task("Website", ["Hero"], started: 80, [codex("Hero", .completed, at: ago(2))])
        let stale = try task("Thesis", ["Draft"], started: 70, [codex("Draft", .completed, at: ago(40))])
        #expect(TaskMeanwhile(current: current, among: [current, fresh, stale])?.taskID == stale.id)
    }

    @Test("Other tasks only running: get the step after the agent's ready")
    func prepareTheNextStep() throws {
        let other = try task("Website", ["Hero"], started: 60, [codex("Hero", .running, at: ago(1))])
        let homework = try task("Homework", ["Insert", "Delete", "Report"], started: 90,
                                [codex("Insert", .running, at: ago(2))])
        #expect(TaskMeanwhile(current: homework, among: [homework, other]) == .prepare(step: 1, text: "Delete"))
    }

    @Test("The agent's matched step decides which step comes after it; the last one leaves nothing to prepare")
    func matchedStep() throws {
        var plan = AnchorUserPlan(steps: ["Insert", "Delete", "Report"])
        plan = try #require(plan.marking(step: 0, done: true, at: ago(100)))
        let report = plan.items[2].id
        let delete = plan.items[1].id
        func homework(on step: UUID) -> AnchorSession {
            AnchorSession(goal: AnchorGoal(title: "Homework", completionCriteria: "", userPlan: plan), startedAt: ago(90),
                          processes: [codex("Agent", .running, at: ago(2), step: step)])
        }
        #expect(TaskMeanwhile(current: homework(on: delete), among: []) == .prepare(step: 2, text: "Report"))
        #expect(TaskMeanwhile(current: homework(on: report), among: []) == .prepare(step: nil, text: nil))
    }

    @Test("The desk holds the person while their agent works or a result waits, and not otherwise")
    func deskHold() throws {
        let idle = try task("Homework", ["Insert"], started: 90)
        #expect(DeskHold(current: idle, among: [idle]) == nil)
        #expect(DeskHold(current: nil, among: []) == nil)

        let running = try task("Homework", ["Insert", "Delete"], started: 90, [codex("Insert", .running, at: ago(2))])
        guard case let .waiting(id, _, action, meanwhile) = DeskHold(current: running, among: [running]) else {
            Issue.record("expected waiting")
            return
        }
        #expect(id == running.id)
        #expect(action.needsPerson == false)
        #expect(meanwhile == .prepare(step: 1, text: "Delete"))

        let website = try task("Website", ["Hero"], started: 60, [codex("Hero", .completed, at: ago(5))])
        #expect(DeskHold(current: idle, among: [idle, website])
            == .needsYou(task: website.id, title: "Website", action: .review(process: "Hero")))
    }
}
