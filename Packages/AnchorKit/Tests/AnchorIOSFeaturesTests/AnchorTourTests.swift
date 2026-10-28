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
        // One conversation waits on the person, so the desk shows a red card.
        #expect(projection.hostedSessions.contains { $0.taskProcesses.contains(where: \.needsRescue) })
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
        #expect(tour.stage == .desk)
    }
}
