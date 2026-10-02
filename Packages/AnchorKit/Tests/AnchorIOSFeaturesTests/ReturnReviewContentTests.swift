import AnchorCore
import Foundation
import Testing
@testable import AnchorIOSFeatures

@Suite("Return review content")
struct ReturnReviewContentTests {
    @Test("Counters distinguish failures, interruptions, completed and queued work")
    func countersAndNextTask() {
        let running = process(.running)
        let failed = process(.failed)
        var interrupted = process(.failed)
        interrupted.sourceName = "Codex"
        interrupted.events = [ProcessEvent(occurredAt: interrupted.updatedAt, kind: .failed, title: "Codex turn_aborted")]
        let tasks = [running, process(.completed), failed, interrupted, process(.disconnected), process(.queued)]
        let review = content(tasks)
        #expect(review.runningCount == 1)
        #expect(review.completedCount == 1)
        #expect(review.failedCount == 1)
        #expect(review.attentionCount == 2)
        #expect(review.queuedCount == 1)
        #expect(review.nextProcess?.id == failed.id)
        #expect(!review.allCompleted)
        #expect(content([process(.completed)]).allCompleted)
        #expect(content([process(.completed)]).nextProcess == nil)
        #expect(!content([]).allCompleted)
    }

    @Test("Return context uses the last note before departure, not a later note")
    func anchorContext() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done", note: "Goal context"))
        session.notes = [
            AnchorNote(sessionID: session.id, origin: "session", text: "Later note", createdAt: start.addingTimeInterval(10)),
            AnchorNote(sessionID: session.id, origin: "session", text: "Pick up here", createdAt: start.addingTimeInterval(-1))
        ]
        session.returnSummary = ReturnSummary(awaySince: start, generatedAt: start.addingTimeInterval(780), changes: [])
        let review = ReturnReviewContent(projection: SessionProjection(session: session))
        #expect(review.context == "Pick up here")
        #expect(review.elapsedSeconds == 780)
    }

    @Test("Legacy environment and decisions never become return recommendations")
    func scope() {
        var ambient = process(.failed)
        ambient.sourceID = BuiltInProcessSourceID.macWorkspace
        let running = process(.running)
        let review = content([ambient, running])
        #expect(review.failedCount == 0)
        #expect(review.nextProcess?.id == running.id)
    }

    private func content(_ processes: [AnchorProcess]) -> ReturnReviewContent {
        ReturnReviewContent(projection: SessionProjection(session: AnchorSession(
            goal: AnchorGoal(title: "Work", completionCriteria: "Done"), processes: processes)))
    }
    private func process(_ status: ProcessStatus) -> AnchorProcess {
        AnchorProcess(sourceName: "Terminal", sourceSymbol: ">_", sourceTone: "cyan", title: "Task", status: status)
    }
}
