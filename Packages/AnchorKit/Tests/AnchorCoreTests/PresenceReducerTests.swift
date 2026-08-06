import Foundation
import Testing
@testable import AnchorCore

@Suite("Presence reducer")
struct PresenceReducerTests {
    @Test("Landscape always counts as at desk")
    func landscapeOverridesConnectionFailure() {
        var reducer = PresenceReducer(status: .unknown)
        let status = reducer.reduce(
            PresenceSignals(
                posture: .landscape,
                connection: .failed,
                proximity: .unknown
            )
        )
        #expect(status == .atDesk)
    }

    @Test("Confirmed absence passes through handoff before away")
    func confirmedAbsence() {
        let start = Date(timeIntervalSince1970: 1_000)
        var reducer = PresenceReducer(
            status: .atDesk,
            policy: PresencePolicy(absenceConfirmation: 60, handoffDuration: 3)
        )
        let missing = { (date: Date) in
            PresenceSignals(
                posture: .portrait,
                connection: .disconnected,
                proximity: .far,
                observedAt: date
            )
        }

        #expect(reducer.reduce(missing(start)) == .atDesk)
        #expect(reducer.reduce(missing(start.addingTimeInterval(59))) == .atDesk)
        #expect(reducer.reduce(missing(start.addingTimeInterval(60))) == .handingOff)
        #expect(reducer.reduce(missing(start.addingTimeInterval(63))) == .away)
    }

    @Test("Ambiguous system signals are unknown, never away")
    func ambiguityIsUnknown() {
        var reducer = PresenceReducer(status: .atDesk)
        let status = reducer.reduce(
            PresenceSignals(
                posture: .portrait,
                connection: .permissionDenied,
                proximity: .permissionDenied
            )
        )
        #expect(status == .unknown)
    }

    @Test("Recovery enters returning until acknowledged")
    func returningRequiresAcknowledgement() {
        var reducer = PresenceReducer(status: .away)
        let status = reducer.reduce(
            PresenceSignals(
                posture: .portrait,
                connection: .connected,
                proximity: .near
            )
        )
        #expect(status == .returning)
        reducer.acknowledgeReturn()
        #expect(reducer.status == .atDesk)
    }

    @Test("A confirmed away state remains away while signals are still absent")
    func awayRemainsAway() {
        var reducer = PresenceReducer(status: .away)
        let status = reducer.reduce(
            PresenceSignals(
                posture: .portrait,
                connection: .disconnected,
                proximity: .far
            )
        )
        #expect(status == .away)
    }

    @Test("The session model advances absence without requiring another radio callback")
    @MainActor
    func modelSchedulesPresenceDeadlines() async throws {
        let session = AnchorSession(
            goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
            status: .active,
            presence: .atDesk,
            processes: []
        )
        let initial = SessionProjection(
            session: session,
            connection: .disconnected,
            proximity: .far
        )
        let repository = InMemorySessionRepository(initialProjection: initial)
        let provider = OneSignalProvider(
            value: PresenceSignals(
                posture: .portrait,
                connection: .disconnected,
                proximity: .far
            )
        )
        let model = AnchorSessionModel(
            repository: repository,
            presenceProvider: provider,
            initialProjection: initial,
            presencePolicy: PresencePolicy(absenceConfirmation: 0.02, handoffDuration: 0.02)
        )

        model.start()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        var projection = await repository.currentProjection()
        while projection.session?.presence != .away,
              ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
            projection = await repository.currentProjection()
        }
        model.stop()

        #expect(projection.session?.presence == .away)
    }
}

private struct OneSignalProvider: PresenceSignalProviding {
    let value: PresenceSignals

    func presenceSignals() async -> AsyncStream<PresenceSignals> {
        AsyncStream { continuation in
            continuation.yield(value)
        }
    }
}
