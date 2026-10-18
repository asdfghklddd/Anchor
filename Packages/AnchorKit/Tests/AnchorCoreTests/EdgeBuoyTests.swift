import Foundation
import Testing
@testable import AnchorCore

@Suite("Edge buoy")
struct EdgeBuoyTests {
    private let seenAt = Date(timeIntervalSince1970: 1_800_000_000)

    private func task(_ events: [(ProcessEventKind, Double, String)]) -> AnchorSession {
        let mapped = events.map { kind, offset, title in
            ProcessEvent(occurredAt: seenAt.addingTimeInterval(offset), kind: kind, title: title)
        }
        let process = AnchorProcess(sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                                    title: "Conversation", status: .running, events: mapped)
        return AnchorSession(goal: AnchorGoal(title: "Task", completionCriteria: ""), processes: [process])
    }

    @Test("Nothing new means no buoy")
    func nothingNew() {
        #expect(EdgeBuoySignal.unseen(in: [task([(.completed, -60, "done")])], since: seenAt) == nil)
        #expect(EdgeBuoySignal.unseen(in: [task([(.created, 60, "started")])], since: seenAt) == nil)
    }

    @Test("A finish after the last look raises the finished buoy")
    func finished() {
        #expect(EdgeBuoySignal.unseen(in: [task([(.completed, 30, "done")])], since: seenAt) == .finished)
    }

    @Test("A failure outranks a finish; a person's own stop is not a signal")
    func severity() {
        let tasks = [task([(.completed, 30, "done")]), task([(.failed, 40, "Codex task_failed")])]
        #expect(EdgeBuoySignal.unseen(in: tasks, since: seenAt) == .failed)
        #expect(EdgeBuoySignal.unseen(in: [task([(.failed, 40, "Codex turn_aborted")])], since: seenAt) == nil)
        #expect(EdgeBuoySignal.unseen(in: [task([(.decisionRequired, 5, "waiting"), (.completed, 9, "done")])],
                                      since: seenAt) == .attention)
    }

    @Test("The buoy counts tasks that need the person; answering for the step counts as looking")
    func countsTasksNeedingYou() throws {
        let finished = task([(.completed, 30, "done")])
        let failed = task([(.failed, 40, "Codex task_failed")])
        let quiet = task([(.created, 50, "started")])
        #expect(EdgeBuoy.needsYou(in: [finished, failed, quiet], since: seenAt) == EdgeBuoy(signal: .failed, count: 2))
        #expect(EdgeBuoy.needsYou(in: [quiet], since: seenAt) == nil)

        // The person said "not yet" on the phone after the result came in.
        var answered = finished
        answered.goal = AnchorGoal(title: "Task", completionCriteria: "",
                                   userPlan: AnchorUserPlan(steps: ["Insert"]).markingReviewed(at: seenAt.addingTimeInterval(60)))
        #expect(EdgeBuoy.needsYou(in: [answered, failed], since: seenAt) == EdgeBuoy(signal: .failed, count: 1))

        let one = EdgeBuoy(signal: .finished, count: 1)
        #expect(EdgeBuoy(signal: .finished, count: 2).isNews(after: one))
        #expect(EdgeBuoy(signal: .failed, count: 1).isNews(after: one))
        #expect(!EdgeBuoy(signal: .finished, count: 1).isNews(after: EdgeBuoy(signal: .failed, count: 2)))
    }
}
