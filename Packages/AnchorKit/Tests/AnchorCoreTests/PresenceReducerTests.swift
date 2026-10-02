import Foundation
import Testing
@testable import AnchorCore

@Suite("Presence reducer")
struct PresenceReducerTests {
    @Test("Landscape does not imply presence or return")
    func landscapeDoesNotOverrideConnectionFailure() {
        var reducer = PresenceReducer(status: .unknown)
        let status = reducer.reduce(
            PresenceSignals(
                posture: .landscape,
                connection: .failed,
                proximity: .unknown
            )
        )
        #expect(status == .unknown)
    }

    @Test("Confirmed absence passes through handoff before away")
    func confirmedAbsence() {
        let start = Date(timeIntervalSince1970: 1_000)
        var reducer = PresenceReducer(
            status: .atDesk,
            policy: PresencePolicy(absenceConfirmation: 60, handoffDuration: 3)
        )
        reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .near, observedAt: start.addingTimeInterval(-1)))
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

    @Test("Nearby interruptions remain work while Wi-Fi stays connected")
    func wifiConnectionKeepsWorking() {
        let start = Date(timeIntervalSince1970: 1_000)
        var reducer = PresenceReducer(status: .atDesk)
        for offset in [0.0, 600, 1_200] {
            #expect(reducer.reduce(PresenceSignals(posture: .portrait,
                connection: .connected, proximity: .far,
                observedAt: start.addingTimeInterval(offset), bluetoothConnection: .disconnected)) == .atDesk)
            #expect(reducer.absenceBeganAt == nil)
        }
        #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected,
            proximity: .near, bluetoothConnection: .connected)) == .atDesk)
    }

    @Test("Short loss reconnects without a return screen; five minutes qualifies")
    func durationControlsReturn() {
        let start = Date(timeIntervalSince1970: 1_000)
        for (duration, expected) in [(299.0, PresenceStatus.atDesk), (300.0, .returning), (301.0, .returning), (1_200.0, .returning)] {
            var reducer = PresenceReducer(status: .atDesk)
            reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .near, observedAt: start.addingTimeInterval(-1)))
            #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .disconnected, proximity: .unknown, observedAt: start)) == .atDesk)
            // No intermediate callback: models an iOS timer suspended in background.
            #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .unknown, observedAt: start.addingTimeInterval(duration))) == expected)
        }
    }

    @Test("Bluetooth alone keeps working, confirms loss at five minutes, then returns")
    func bluetoothOnlyLifecycle() {
        let start = Date(timeIntervalSince1970: 1_000)
        var reducer = PresenceReducer(status: .atDesk)
        func signal(_ state: ConnectionState, _ offset: Double) -> PresenceSignals {
            // `connection` is the effective link; here BLE is its only provider.
            PresenceSignals(posture: .portrait, connection: state, proximity: .unknown,
                observedAt: start.addingTimeInterval(offset), bluetoothConnection: state)
        }
        #expect(reducer.reduce(signal(.connected, -1)) == .atDesk)
        #expect(reducer.reduce(signal(.disconnected, 0)) == .atDesk)
        #expect(reducer.reduce(signal(.disconnected, 299)) == .atDesk)
        #expect(reducer.reduce(signal(.disconnected, 300)) == .handingOff)
        #expect(reducer.reduce(signal(.disconnected, 303)) == .away)
        #expect(reducer.reduce(signal(.connected, 310)) == .returning)
        reducer.acknowledgeReturn()
        #expect(reducer.reduce(signal(.connected, 311)) == .atDesk)
    }

    @Test("Rotation and near RSSI cannot finish an away state")
    func returnNeedsAuthenticatedConnection() {
        var reducer = PresenceReducer(status: .away)
        #expect(reducer.reduce(PresenceSignals(posture: .landscape, connection: .disconnected, proximity: .near)) == .away)
        #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .unknown)) == .returning)
        #expect(reducer.reduce(PresenceSignals(posture: .landscape, connection: .connected, proximity: .near)) == .returning)
        reducer.acknowledgeReturn()
        #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .near)) == .atDesk)
    }

    @Test("An unpaired app and permission loss never invent a departure")
    func noUnobservedDeparture() {
        let start = Date(timeIntervalSince1970: 1_000)
        var reducer = PresenceReducer(status: .atDesk)
        for offset in [0.0, 1_200] {
            #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .disconnected, proximity: .unknown, observedAt: start.addingTimeInterval(offset))) == .unknown)
        }
        reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .near, observedAt: start))
        reducer.reduce(PresenceSignals(posture: .portrait, connection: .disconnected, proximity: .unknown, observedAt: start))
        reducer.reduce(PresenceSignals(posture: .portrait, connection: .permissionDenied, proximity: .permissionDenied, observedAt: start.addingTimeInterval(120)))
        #expect(reducer.absenceBeganAt == nil)
        #expect(reducer.reduce(PresenceSignals(posture: .portrait, connection: .connected, proximity: .unknown, observedAt: start.addingTimeInterval(1_200))) == .atDesk)
    }

    @Test("Explicit leave survives nearby signals until explicit return")
    @MainActor
    func manualLeaveIsStable() async throws {
        let initial = SessionProjection(session: AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done")), connection: .connected, proximity: .near)
        let repository = InMemorySessionRepository(initialProjection: initial)
        let model = AnchorSessionModel(repository: repository, initialProjection: initial)
        #expect(await model.leaveDesk())
        await model.updatePosture(.landscape)
        #expect(await repository.currentProjection().session?.presence == .away)
        #expect(await model.beginReturn())
        #expect(await repository.currentProjection().session?.presence == .returning)
    }

    @Test("Manual return opens the summary before resuming the workspace")
    @MainActor
    func manualReturnRequiresSummaryAcknowledgement() async throws {
        let awayAt = Date(timeIntervalSince1970: 1_000)
        let repository = InMemorySessionRepository(initialProjection: SessionProjection(
            session: AnchorSession(goal: AnchorGoal(title: "Return task", completionCriteria: "Resume"))
        ))
        try await repository.send(.updatePresence(.away, at: awayAt))
        try await repository.send(.recordEvent(ProcessEvent(
            occurredAt: awayAt.addingTimeInterval(10),
            kind: .progress,
            title: "Work progressed while away"
        )))
        let model = AnchorSessionModel(
            repository: repository,
            initialProjection: await repository.currentProjection()
        )

        #expect(await model.beginReturn())
        let reviewing = await repository.currentProjection()
        #expect(reviewing.session?.presence == .returning)
        let feedbackModel = AnchorSessionModel(repository: repository, initialProjection: reviewing)
        #expect(feedbackModel.claimReturnFeedback())
        #expect(!feedbackModel.claimReturnFeedback())
        #expect(reviewing.session?.returnSummary?.awaySince == awayAt)
        #expect(reviewing.session?.returnSummary?.changes.first?.title == "Work progressed while away")

        #expect(await model.continueWorking())
        let resumed = await repository.currentProjection()
        #expect(resumed.session?.presence == .atDesk)
        #expect(resumed.session?.returnSummary == nil)
        #expect(await model.beginReturn() == false)
    }

    @Test("Long interruption includes the waiting period without backdating its snapshot")
    func longInterruptionSummaryAndLegacyOperation() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        var projection = SessionProjection(session: AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done")))
        projection = try SessionReducer.reduce(projection, command: .recordEvent(ProcessEvent(occurredAt: start.addingTimeInterval(100), kind: .progress, title: "Progress during grace period")))
        let away = SessionOperation.updatePresence(status: .away, at: start.addingTimeInterval(303), eventID: UUID(), awaySince: start)
        let encoded = try JSONEncoder().encode(away)
        projection = try SessionReducer.reduce(projection, operation: JSONDecoder().decode(SessionOperation.self, from: encoded))
        projection = try SessionReducer.reduce(projection, command: .updatePresence(.returning, at: start.addingTimeInterval(1_200)))
        #expect(projection.session?.returnSummary?.awaySince == start)
        #expect(projection.session?.returnSummary?.changes.first?.title == "Progress during grace period")
        #expect(projection.session?.snapshots.first?.createdAt == start.addingTimeInterval(303))
        #expect(projection.session?.returnSummary?.elapsedSeconds == 1_200)
        let legacy = "{\"updatePresence\":{\"status\":\"away\",\"at\":1000,\"eventID\":\"\(UUID().uuidString)\"}}"
        _ = try JSONDecoder().decode(SessionOperation.self, from: Data(legacy.utf8))
    }

    @Test("A long reconnect opens a portrait summary and preserves the full interruption")
    @MainActor
    func modelHandlesLongReconnect() async throws {
        let leftAt = Date.now.addingTimeInterval(-1_200)
        let initial = SessionProjection(session: AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done")), connection: .connected, proximity: .near)
        let repository = InMemorySessionRepository(initialProjection: initial)
        try await repository.send(.recordEvent(ProcessEvent(occurredAt: leftAt.addingTimeInterval(100), kind: .progress, title: "Progress while away")))
        let provider = SignalSequenceProvider(values: [
            PresenceSignals(posture: .portrait, connection: .connected, proximity: .near, observedAt: leftAt.addingTimeInterval(-1)),
            PresenceSignals(posture: .portrait, connection: .disconnected, proximity: .unknown, observedAt: leftAt),
            PresenceSignals(posture: .portrait, connection: .connected, proximity: .unknown)
        ])
        let model = AnchorSessionModel(repository: repository, presenceProvider: provider, initialProjection: initial)
        model.start()
        defer { model.stop() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while model.projection.session?.presence != .returning, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.projection.session?.presence == .returning)
        #expect(model.projection.session?.returnSummary?.awaySince == leftAt)
        #expect(model.projection.session?.returnSummary?.changes.first?.title == "Progress while away")
        #expect(model.claimReturnFeedback())
        #expect(!model.claimReturnFeedback())
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
            connection: .connected,
            proximity: .near
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

private struct SignalSequenceProvider: PresenceSignalProviding {
    let values: [PresenceSignals]
    func presenceSignals() async -> AsyncStream<PresenceSignals> {
        AsyncStream { continuation in
            for value in values { continuation.yield(value) }
            continuation.finish()
        }
    }
}
