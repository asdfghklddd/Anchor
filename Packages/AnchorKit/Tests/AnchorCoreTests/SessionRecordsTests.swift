import Testing
@testable import AnchorCore

@Suite("Task records")
struct SessionRecordsTests {
    @Test("Presence and link bookkeeping never shows as a record")
    func recordsHideBookkeeping() {
        let note = ProcessEvent(kind: .note, title: "Wrote the outline")
        let done = ProcessEvent(kind: .completed, title: "portfolio")
        let presence = ProcessEvent(kind: .presence, title: "Presence: unknown")
        let link = ProcessEvent(kind: .connection, title: "Connected")
        let session = AnchorSession(goal: AnchorGoal(title: "个人网站", completionCriteria: ""),
                                    timeline: [note, presence, done, link])

        #expect(session.records.map(\.id) == [note.id, done.id])
        #expect(session.timeline.count == 4)
    }
}
