import AnchorCore
import AnchorDemoSupport
import Foundation
import Testing

@Suite("Demo repository")
struct DemoRepositoryTests {
    @Test("Scenario switching and reset use the same repository projection")
    func switchAndReset() async {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)

        await repository.switchScenario(to: .returning)
        #expect(await repository.currentProjection().session?.presence == .returning)

        await repository.reset()
        #expect(await repository.activeScenario() == .active)
        #expect(await repository.currentProjection().session?.presence == .atDesk)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Persisted user actions survive repository recreation")
    func persistence() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let first = DemoSessionRepository(storageURL: storage, restoresSavedState: false)
        try await first.send(.addNote("Remember this"))

        let second = DemoSessionRepository(storageURL: storage)
        #expect(await second.currentProjection().session?.notes.first?.text == "Remember this")
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Every named demo scenario represents a distinct product state")
    func scenarioSemantics() {
        let active = DemoFixtureFactory.projection(for: .active)
        let needsDecision = DemoFixtureFactory.projection(for: .needsDecision)
        let returning = DemoFixtureFactory.projection(for: .returning)
        let completed = DemoFixtureFactory.projection(for: .completed)

        #expect(active.openDecisions.isEmpty)
        #expect(active.session?.processes.contains { $0.status == .needsDecision } == false)
        let confirmedStoryboard = active.session?.processes.first { $0.sourceName == "Gemini" }
        #expect(confirmedStoryboard?.progress == 0.85)
        #expect(confirmedStoryboard?.events.last?.kind == .decisionResolved)
        #expect(needsDecision.openDecisions.count == 1)
        #expect(needsDecision.session?.processes.contains { $0.status == .needsDecision } == true)
        #expect(returning.session?.snapshots.count == 1)
        #expect(returning.session?.returnSummary?.changes.count == 3)
        #expect(completed.openDecisions.isEmpty)
    }

    @Test("Retryable error scenario keeps its visible error")
    func retryableErrorPersists() async {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)

        await repository.switchScenario(to: .retryableError)
        let projection = await repository.currentProjection()

        #expect(projection.connection == .failed)
        #expect(projection.errorMessage != nil)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("The baseline fixture is copied before the first user action")
    func initialFixtureIsPersisted() {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        _ = DemoSessionRepository(storageURL: storage, restoresSavedState: false)

        #expect(FileManager.default.fileExists(atPath: storage.path))
        let data = try? Data(contentsOf: storage)
        let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        #expect(object?["schemaVersion"] as? Int == DemoFixtureFactory.schemaVersion)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("A new demo setup seeds its process list from the current Mac fixture")
    func currentProcessSnapshot() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(
            storageURL: storage,
            initialScenario: .empty,
            restoresSavedState: false
        )

        let snapshot = try await repository.currentProcessSnapshot()
        #expect(snapshot.processNames == ["Claude", "Gemini", "Seedance", "Final Cut"])
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Demo playback exposes handoff before away and then returning")
    @MainActor
    func playbackTransitions() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)
        let model = AnchorSessionModel(repository: repository, presenceProvider: repository)
        model.start()
        try await Task.sleep(for: .milliseconds(50))

        await repository.playScenario(to: .away18Minutes)
        try await waitUntil(timeout: .seconds(1)) { model.projection.session?.presence == .handingOff }
        try await waitUntil(timeout: .seconds(3)) { model.projection.session?.presence == .away }

        await repository.playScenario(to: .returning)
        try await waitUntil(timeout: .seconds(2)) { model.projection.session?.presence == .returning }

        model.stop()
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Acknowledging return persists the active demo scenario")
    func acknowledgeReturnPersistsActiveScenario() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(
            storageURL: storage,
            initialScenario: .returning,
            restoresSavedState: false
        )

        try await Task.sleep(for: .milliseconds(220))
        try await repository.send(.acknowledgeReturn)

        #expect(await repository.activeScenario() == .active)
        #expect(await repository.currentProjection().session?.presence == .atDesk)

        let restored = DemoSessionRepository(storageURL: storage)
        #expect(await restored.activeScenario() == .active)
        #expect(await restored.currentProjection().session?.presence == .atDesk)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Correcting handoff cancels the pending away transition")
    func correctingHandoffCancelsTransition() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)

        await repository.playScenario(to: .away18Minutes)
        #expect(await repository.currentProjection().session?.presence == .handingOff)
        try await repository.send(.updatePresence(.atDesk, at: .now))
        try await Task.sleep(for: .milliseconds(1_950))

        #expect(await repository.activeScenario() == .active)
        #expect(await repository.currentProjection().session?.presence == .atDesk)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Repeating the same demo scenario keeps the latest transition timing")
    func repeatingScenarioUsesLatestTransition() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)

        await repository.playScenario(to: .returning)
        try await Task.sleep(for: .milliseconds(120))
        await repository.playScenario(to: .returning)
        try await Task.sleep(for: .milliseconds(100))
        #expect(await repository.currentProjection().session?.presence == .away)
        try await Task.sleep(for: .milliseconds(120))
        #expect(await repository.currentProjection().session?.presence == .returning)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("An incompatible fixture version resets to the requested baseline")
    func incompatibleFixtureVersionResets() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        _ = DemoSessionRepository(
            storageURL: storage,
            initialScenario: .returning,
            restoresSavedState: false
        )
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: storage)) as? [String: Any]
        )
        object["schemaVersion"] = DemoFixtureFactory.schemaVersion + 1
        try JSONSerialization.data(withJSONObject: object).write(to: storage, options: .atomic)

        let repository = DemoSessionRepository(
            storageURL: storage,
            initialScenario: .active
        )
        #expect(await repository.activeScenario() == .active)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("The session model follows an external presence change for the same session")
    @MainActor
    func sameSessionPresenceChange() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)
        let model = AnchorSessionModel(repository: repository, presenceProvider: repository)
        model.start()

        await repository.switchScenario(to: .away18Minutes)
        try await waitUntil { model.projection.session?.presence == .away }
        await repository.switchScenario(to: .returning)
        try await waitUntil { model.projection.session?.presence == .returning }
        try await Task.sleep(for: .milliseconds(100))

        #expect(model.projection.session?.presence == .returning)
        model.stop()
        try? FileManager.default.removeItem(at: storage)
    }

    @MainActor
    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}
