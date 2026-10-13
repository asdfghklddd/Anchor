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
}
