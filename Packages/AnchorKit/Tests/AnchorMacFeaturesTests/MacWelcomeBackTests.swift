#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@Suite("Mac welcome back")
struct MacWelcomeBackTests {
    private let now = Date(timeIntervalSince1970: 1_792_137_600)

    private func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

    @Test("Ten idle minutes are time away; the next input is the return, reported once")
    func idleAwayAndBack() {
        var tracker = MacAwayTracker()
        #expect(tracker.idle(9 * 60, now: ago(20)) == nil)
        #expect(!tracker.isAway)
        #expect(tracker.idle(10 * 60, now: ago(14)) == nil)
        #expect(tracker.awaySince == ago(24))
        #expect(tracker.idle(30, now: ago(1)) == nil)
        #expect(tracker.idle(1, now: now) == ago(24))
        #expect(tracker.idle(1, now: now) == nil)
    }

    @Test("A short lock is not worth a card; a long one is, from the moment it began")
    func locks() {
        var tracker = MacAwayTracker()
        tracker.screenDidLock(now: ago(2))
        #expect(tracker.screenDidUnlock(now: now) == nil)

        tracker.screenDidLock(now: ago(30))
        // Idle time keeps growing behind the lock screen; it does not end the lock.
        #expect(tracker.idle(29 * 60, now: ago(1)) == nil)
        #expect(tracker.screenDidUnlock(now: now) == ago(30))
    }

    @Test("Waking onto a locked screen waits for the unlock; idle time before a sleep counts")
    func sleepAndWake() {
        var tracker = MacAwayTracker()
        #expect(tracker.idle(12 * 60, now: ago(40)) == nil)
        tracker.didSleep(now: ago(35))
        tracker.screenDidLock(now: ago(35))
        #expect(tracker.didWake(now: ago(1)) == nil)
        #expect(tracker.screenDidUnlock(now: now) == ago(52))

        tracker.didSleep(now: ago(20))
        #expect(tracker.didWake(now: now) == ago(20))
    }

    @Test("The card names the task the person was on and opens what needs them first")
    func content() throws {
        let sourceID = UUID()
        let finished = AnchorProcess(sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                                     title: "deploy", status: .failed, updatedAt: ago(5),
                                     events: [ProcessEvent(sourceID: sourceID, occurredAt: ago(5), kind: .failed,
                                                           title: "Codex task_failed")])
        let homework = AnchorSession(goal: AnchorGoal(title: "Homework", completionCriteria: "",
                                                      userPlan: AnchorUserPlan(steps: ["Insert", "Delete"])),
                                     status: .active, startedAt: ago(120))
        let website = AnchorSession(goal: AnchorGoal(title: "Website", completionCriteria: "",
                                                     userPlan: AnchorUserPlan(steps: ["Deploy"])),
                                    status: .active, startedAt: ago(200), processes: [finished])

        let welcome = MacWelcomeBack(tasks: [homework, website], currentID: homework.id, awaySince: ago(30), returnedAt: now)
        #expect(welcome.current?.id == homework.id)
        #expect(welcome.overview.items.map(\.task.id) == [website.id])
        #expect(welcome.taskToOpen == website.id)

        let quiet = MacWelcomeBack(tasks: [homework], currentID: homework.id, awaySince: ago(30), returnedAt: now)
        #expect(quiet.overview.items.isEmpty)
        #expect(quiet.taskToOpen == homework.id)
        #expect(MacWelcomeBack(tasks: [], currentID: nil, awaySince: ago(30), returnedAt: now).isEmpty)
    }
}
#endif
