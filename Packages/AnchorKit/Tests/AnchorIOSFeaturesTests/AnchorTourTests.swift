import Foundation
import Testing
import AnchorCore
@testable import AnchorIOSFeatures

@Suite("First-run tour")
@MainActor
struct AnchorTourTests {
    @Test func aNewPhoneOwesTheTourOnce() throws {
        let defaults = try #require(UserDefaults(suiteName: "anchor.tour.tests.\(UUID().uuidString)"))
        #expect(AnchorTourGate.isPending(bluetoothAsked: false, defaults: defaults))
        AnchorTourGate.markDone(defaults: defaults)
        #expect(!AnchorTourGate.isPending(bluetoothAsked: false, defaults: defaults))
    }

    @Test func someoneWhoAnsweredBluetoothAlreadyNeverSeesItUnasked() throws {
        let defaults = try #require(UserDefaults(suiteName: "anchor.tour.tests.\(UUID().uuidString)"))
        #expect(!AnchorTourGate.isPending(bluetoothAsked: true, defaults: defaults))
        #expect(!AnchorTourGate.isPending(bluetoothAsked: false, defaults: defaults))
    }

    @Test func theHomeOpensOnTwoTasksFromAConnectedMac() {
        let tour = AnchorTour()
        defer { tour.end() }
        let projection = tour.model.projection
        #expect(projection.connection == .connected)
        #expect(projection.hostedSessions.count == 2)
        #expect(projection.hostedSessions.allSatisfy { !TaskConversationStack.conversations(of: $0).isEmpty })
        // The question arrives later, on the desk, so the person sees the card turn red.
        #expect(!projection.hostedSessions.contains { $0.taskProcesses.contains(where: \.needsRescue) })
        #expect(projection.hostedSessions.contains { $0.id == tour.waitingTaskID })
    }

    @Test func stagesFollowThePersonForward() {
        let tour = AnchorTour()
        defer { tour.end() }
        #expect(tour.stage == .tasks)
        tour.next()
        tour.next()
        #expect(tour.stage == .anchorButton)
        tour.setupOpened()
        tour.setupClosed()
        #expect(tour.stage == .anchorButton)
        tour.setupOpened()
        tour.leave()
        #expect(tour.stage == .setup)
        tour.dropped(UUID())
        #expect(tour.stage == .turn)
        tour.reachedDesk()
        #expect(tour.stage == .desk)
        tour.next()
        #expect(tour.stage == .waiting)
        tour.next()
        #expect(tour.stage == .called)
        // Back to Home only ends the tour from the return page.
        tour.leave()
        #expect(tour.stage == .called)
        tour.leftDesk()
        #expect(tour.stage == .walkingAway)
        tour.next()
        tour.leftDesk()
        #expect(tour.stage == .walkingAway)
    }

    @Test func pickingThePhoneUpEarlyStillLeavesTheDesk() {
        let tour = AnchorTour()
        defer { tour.end() }
        tour.next()
        tour.next()
        tour.setupOpened()
        // Before the desk, turning upright is nothing to the tour.
        tour.leftDesk()
        #expect(tour.stage == .setup)
        tour.dropped(UUID())
        tour.reachedDesk()
        tour.leftDesk()
        #expect(tour.stage == .walkingAway)
    }

    @Test func theMacRecapsEveryTaskYoursFirst() {
        let mac = TourMac()
        let tasks = mac.seed(now: .now)
        let own = UUID()
        let back = Date.now
        let recaps = mac.recaps(returnedAt: back, ownTask: own)
        #expect(recaps.map(\.0) == [own] + tasks.map(\.id))
        #expect(recaps.allSatisfy { $0.1.returnedAt == back && !$0.1.conversations.isEmpty })
        // Every recap names a conversation the task really has, or gets while the person is away.
        let news = mac.awayNews(ownTask: own)
        #expect(news.count == 3)
    }

    @Test func dictationArrivesAWordAtATime() {
        #expect(SpeechInputController.spokenChunks(of: "First list the colors, then check")
            == ["First ", "list ", "the ", "colors, ", "then ", "check"])
        let chinese = SpeechInputController.spokenChunks(of: "先梳理颜色变量，然后替换")
        #expect(chinese.joined() == "先梳理颜色变量，然后替换")
        #expect(chinese.allSatisfy { $0.count <= 4 })
        #expect(chinese.contains { $0.hasSuffix("，") })
    }
}
