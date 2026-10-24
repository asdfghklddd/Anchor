import Foundation
import Testing
@testable import AnchorCore

@Suite("Conversation working time and the red light")
struct ConversationWorkTests {
    private func line(_ type: String, turn: String, at time: String, duration: Int? = nil, error: Bool = false) -> String {
        var payload = #""type":"\#(type)","turn_id":"\#(turn)""#
        if let duration { payload += #","duration_ms":\#(duration)"# }
        if type == "task_complete" { payload += error ? #","error":{"message":"boom"}"# : #","error":null"# }
        return #"{"timestamp":"2026-09-05T\#(time)Z","type":"event_msg","payload":{\#(payload)}}"# + "\n"
    }

    @Test("Turns add up: the reported duration when there is one, else start to end")
    func sumsTurns() {
        var scanner = CodexIncrementalScanner()
        let records = scanner.appendWithOffsets(Data((
            line("task_started", turn: "a", at: "01:00:00.000")
            + line("task_complete", turn: "a", at: "01:10:00.000", duration: 540_000)
            + line("task_started", turn: "b", at: "02:00:00.000")
            + line("turn_aborted", turn: "b", at: "02:03:00.000")
            + line("task_started", turn: "c", at: "03:00:00.000")
        ).utf8))
        #expect(records.map(\.work.seconds) == [0, 540, 540, 720, 720])
        let start = records.last?.record.timestamp ?? .now
        #expect(scanner.work.total(at: start.addingTimeInterval(60)) == 780)
    }

    @Test("A checkpoint keeps the working time; an older one is measured again from the log")
    func checkpointsKeepWork() throws {
        let text = line("task_started", turn: "a", at: "01:00:00.000")
            + line("task_complete", turn: "a", at: "01:02:00.000")
        var scanner = CodexIncrementalScanner()
        _ = scanner.appendWithOffsets(Data(text.utf8))
        let restored = try CodexIncrementalScanner(checkpoint: scanner.checkpoint())
        #expect(restored.work.seconds == 120 && !restored.needsWorkBackfill)

        let old = try CodexIncrementalScanner(checkpoint: Data(#"{"version":1,"offset":\#(text.utf8.count)}"#.utf8))
        #expect(old.needsWorkBackfill)
        let url = FileManager.default.temporaryDirectory.appending(path: "work-\(UUID()).jsonl")
        try Data(text.utf8).write(to: url)
        #expect(ConversationWork.measure(url, dialect: .codex, upTo: UInt64(text.utf8.count))?.seconds == 120)
    }

    @Test("A running turn counts on from what the Mac sent")
    func liveTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        let process = AnchorProcess(sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                                    title: "Chat", status: .running, updatedAt: start, workedSeconds: 600)
        #expect(process.workedTime(at: start.addingTimeInterval(90)) == 690)
        var done = process
        done.status = .completed
        #expect(done.workedTime(at: start.addingTimeInterval(90)) == 600)
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func turn(_ source: UUID, _ title: String, minutesAgo: Double, status: ProcessStatus = .completed,
                      request: String? = nil) -> AnchorProcess {
        AnchorProcess(sourceID: source, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan", title: title,
                      status: status, updatedAt: now.addingTimeInterval(-minutesAgo * 60), request: request)
    }

    private func task(_ processes: [AnchorProcess]) -> AnchorSession {
        var task = AnchorSession(goal: AnchorGoal(title: "Anchor", completionCriteria: ""), processes: processes)
        task.captureJoiningOrder()
        return task
    }

    @Test("A conversation's turns make one card: its latest turn, keeping the last request")
    func turnsGroup() {
        let chat = UUID(), other = UUID()
        let stack = TaskConversationStack(task: task([
            turn(chat, "Chat", minutesAgo: 30, request: "first ask"),
            turn(other, "Other", minutesAgo: 20),
            turn(chat, "Chat", minutesAgo: 5),
        ]))
        #expect(stack.cards.map(\.title) == ["Other", "Chat"])
        #expect(stack.front?.request == "first ask")
    }

    @Test("A red conversation comes to the front; a pick made after it holds until news")
    func redComesForward() {
        let red = turn(UUID(), "Failed", minutesAgo: 20, status: .failed)
        let fresh = turn(UUID(), "Fresh", minutesAgo: 5)
        let waiting = turn(UUID(), "Asks", minutesAgo: 30, status: .needsDecision)
        #expect(red.needsRescue && waiting.needsRescue && !fresh.needsRescue)
        #expect(TaskConversationStack(task: task([fresh, red])).front?.title == "Failed")
        #expect(TaskConversationStack(task: task([fresh, red, waiting])).front?.title == "Failed")

        let pick = TaskConversationStack.Pick(conversation: fresh.conversationKey, at: now.addingTimeInterval(-60))
        #expect(TaskConversationStack(task: task([fresh, red]), pick: pick).front?.title == "Fresh")
    }
}
