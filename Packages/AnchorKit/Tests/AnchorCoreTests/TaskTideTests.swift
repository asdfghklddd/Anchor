import Foundation
import Testing
@testable import AnchorCore

@Suite("Task tide")
struct TaskTideTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func event(_ kind: ProcessEventKind, minutesAgo: Double, title: String = "Codex event",
                       metric: String? = nil, sourceID: UUID? = nil) -> ProcessEvent {
        ProcessEvent(sourceID: sourceID, occurredAt: now.addingTimeInterval(-minutesAgo * 60), kind: kind,
                     title: title, metric: metric)
    }

    private func process(_ status: ProcessStatus, updatedMinutesAgo: Double, events: [ProcessEvent]) -> AnchorProcess {
        AnchorProcess(sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                      title: "Conversation", status: status,
                      updatedAt: now.addingTimeInterval(-updatedMinutesAgo * 60), events: events)
    }

    @Test("A running conversation stays open until now")
    func runningExtendsToNow() {
        let segments = TaskTide.segments(for: process(.running, updatedMinutesAgo: 20,
            events: [event(.created, minutesAgo: 20)]), now: now)
        #expect(segments == [TideSegment(start: now.addingTimeInterval(-1200), end: now, state: .running, isOpen: true)])
    }

    @Test("Finishing closes the run and leaves a completion marker")
    func completionClosesRun() {
        let segments = TaskTide.segments(for: process(.completed, updatedMinutesAgo: 5,
            events: [event(.created, minutesAgo: 30), event(.completed, minutesAgo: 5)]), now: now)
        #expect(segments.map(\.state) == [.running, .completed])
        #expect(segments[0].end == now.addingTimeInterval(-300))
        #expect(segments[1].start == segments[1].end)
        #expect(!segments.contains { $0.isOpen })
    }

    @Test("A stopped Codex turn is an interruption, not a failure")
    func abortedTurnIsInterruption() {
        let segments = TaskTide.segments(for: process(.failed, updatedMinutesAgo: 2,
            events: [event(.created, minutesAgo: 12), event(.failed, minutesAgo: 2, title: "Codex turn_aborted")]),
            now: now)
        #expect(segments.last?.state == .interrupted)
    }

    @Test("A later turn reopens the conversation")
    func laterTurnReopens() {
        let segments = TaskTide.segments(for: process(.running, updatedMinutesAgo: 3, events: [
            event(.created, minutesAgo: 40), event(.completed, minutesAgo: 25), event(.created, minutesAgo: 3)
        ]), now: now)
        #expect(segments.map(\.state) == [.running, .completed, .running])
        #expect(segments.last?.isOpen == true)
    }

    @Test("Source status without a lifecycle event still moves the tide")
    func statusWithoutEvent() {
        let segments = TaskTide.segments(for: process(.blocked, updatedMinutesAgo: 4,
            events: [event(.created, minutesAgo: 15)]), now: now)
        #expect(segments.map(\.state) == [.running, .attention])
        #expect(segments.last?.isOpen == true)
    }

    @Test("A queued process with no events draws nothing")
    func queuedDrawsNothing() {
        #expect(TaskTide.segments(for: process(.queued, updatedMinutesAgo: 1, events: []), now: now).isEmpty)
    }

    @Test("The glance puts failures before attention and running work")
    func glanceHeadlineOrder() {
        func task(_ processes: [AnchorProcess]) -> AnchorSession {
            AnchorSession(goal: AnchorGoal(title: "Task", completionCriteria: ""), processes: processes)
        }
        let running = process(.running, updatedMinutesAgo: 1, events: [event(.created, minutesAgo: 1)])
        let stopped = process(.failed, updatedMinutesAgo: 1,
                              events: [event(.failed, minutesAgo: 1, title: "Codex turn_aborted")])
        let failed = process(.failed, updatedMinutesAgo: 1, events: [event(.failed, minutesAgo: 1)])
        let done = process(.completed, updatedMinutesAgo: 1, events: [event(.completed, minutesAgo: 1)])

        #expect(WorkGlance(tasks: []).headline == .empty)
        #expect(WorkGlance(tasks: [task([])]).headline == .awaitingSources)
        #expect(WorkGlance(tasks: [task([running])]).headline == .running(1))
        #expect(WorkGlance(tasks: [task([running, stopped])]).headline == .attention(1))
        #expect(WorkGlance(tasks: [task([running, stopped]), task([failed])]).headline == .failed(1))
        #expect(WorkGlance(tasks: [task([done])]).headline == .allCompleted)
    }

    @Test("A finished result the person has not looked at needs them; an open plan is never all done")
    func finishedResultNeedsYou() throws {
        let done = process(.completed, updatedMinutesAgo: 5,
                           events: [event(.created, minutesAgo: 30), event(.completed, minutesAgo: 5)])
        func task(_ plan: AnchorUserPlan) -> AnchorSession {
            AnchorSession(goal: AnchorGoal(title: "Homework", completionCriteria: "", userPlan: plan),
                          startedAt: now.addingTimeInterval(-7_200), processes: [done])
        }
        let plan = AnchorUserPlan(steps: ["Insert", "Delete"])
        #expect(WorkGlance(tasks: [task(plan)]).headline == .needsYou(1))

        let looked = plan.markingReviewed(at: now)
        #expect(WorkGlance(tasks: [task(looked)]).headline == .quiet)

        let finished = try #require(looked.marking(step: 0, done: true, at: now)?.marking(step: 1, done: true, at: now))
        #expect(WorkGlance(tasks: [task(finished)]).headline == .allCompleted)
    }

    @Test("The latest change is the newest meaningful event across tasks")
    func latestChange() {
        let older = process(.completed, updatedMinutesAgo: 8, events: [event(.completed, minutesAgo: 8)])
        let newer = process(.running, updatedMinutesAgo: 2, events: [
            event(.created, minutesAgo: 2), event(.note, minutesAgo: 1)
        ])
        let tasks = [
            AnchorSession(goal: AnchorGoal(title: "A", completionCriteria: ""), processes: [older]),
            AnchorSession(goal: AnchorGoal(title: "B", completionCriteria: ""), processes: [newer])
        ]
        let change = WorkGlance(tasks: tasks).latestChange
        #expect(change?.taskTitle == "B")
        #expect(change?.event.kind == .created)
    }
}
