import AnchorCore
import Foundation

public actor DemoSessionRepository: SessionRepository, PresenceSignalProviding, DemoControlling {
    private struct PersistedState: Codable, Sendable {
        var schemaVersion: Int
        var scenario: DemoScenario
        var projection: SessionProjection

        init(scenario: DemoScenario, projection: SessionProjection) {
            schemaVersion = DemoFixtureFactory.schemaVersion
            self.scenario = scenario
            self.projection = projection
        }
    }

    private var state: PersistedState
    private let storageURL: URL
    private var transitionTask: Task<Void, Never>?
    private var transitionID: UUID?
    private var projectionContinuations: [UUID: AsyncStream<SessionProjection>.Continuation] = [:]
    private var signalContinuations: [UUID: AsyncStream<PresenceSignals>.Continuation] = [:]

    public init(
        storageURL: URL? = nil,
        initialScenario: DemoScenario = .active,
        restoresSavedState: Bool = true
    ) {
        let resolvedURL = storageURL ?? Self.defaultStorageURL()
        self.storageURL = resolvedURL
        if restoresSavedState,
           let data = try? Data(contentsOf: resolvedURL),
           let persisted = try? JSONDecoder().decode(PersistedState.self, from: data),
           persisted.schemaVersion == DemoFixtureFactory.schemaVersion {
            state = persisted
        } else {
            var initialState = PersistedState(
                scenario: initialScenario,
                projection: DemoFixtureFactory.projection(for: initialScenario)
            )
            do {
                try Self.write(initialState, to: resolvedURL)
            } catch {
                initialState.projection.errorMessage = error.localizedDescription
            }
            state = initialState
        }
    }

    public func currentProjection() -> SessionProjection { state.projection }

    public func currentProcessSnapshot() async throws -> CurrentProcessSnapshot {
        let names = state.projection.session?.processes.map(\.sourceName)
            ?? ["Claude", "Gemini", "Seedance", "Final Cut"]
        return CurrentProcessSnapshot(processNames: names)
    }

    public func projections() -> AsyncStream<SessionProjection> {
        let id = UUID()
        return AsyncStream { continuation in
            projectionContinuations[id] = continuation
            continuation.yield(state.projection)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeProjectionContinuation(id) }
            }
        }
    }

    public func presenceSignals() -> AsyncStream<PresenceSignals> {
        let id = UUID()
        return AsyncStream { continuation in
            signalContinuations[id] = continuation
            continuation.yield(DemoFixtureFactory.signals(for: state.scenario))
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSignalContinuation(id) }
            }
        }
    }

    public func send(_ command: SessionCommand) throws {
        let previousScenario = state.scenario
        let wasHandoff = state.scenario == .away18Minutes
            && state.projection.session?.presence == .handingOff
        let endsReturn: Bool = {
            if case .acknowledgeReturn = command {
                return state.scenario == .returning
            }
            return false
        }()
        let correctsHandoff: Bool = {
            if case .updatePresence(.atDesk, at: _) = command {
                return wasHandoff
            }
            return false
        }()

        if endsReturn || correctsHandoff {
            cancelTransition()
        }

        state.projection = try SessionReducer.reduce(state.projection, command: command)
        if endsReturn {
            state.scenario = .active
        } else if correctsHandoff {
            state.scenario = .active
            state.projection = DemoFixtureFactory.projection(for: .active)
        }

        let scenarioChanged = state.scenario != previousScenario
        persist(clearExistingError: false)
        broadcastProjection()
        if scenarioChanged {
            broadcastSignals()
        }
    }

    public func activeScenario() -> DemoScenario { state.scenario }

    public func playScenario(to scenario: DemoScenario) {
        cancelTransition()

        switch scenario {
        case .away18Minutes:
            prepareHandoff()
            let token = UUID()
            transitionID = token
            transitionTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(1_850))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.finishTransition(to: scenario, token: token)
            }
        case .returning:
            prepareReturn()
            let token = UUID()
            transitionID = token
            transitionTask = Task { [weak self] in
                do {
                    try await Task.sleep(for: .milliseconds(180))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.finishTransition(to: scenario, token: token)
            }
        default:
            switchScenario(to: scenario)
        }
    }

    public func switchScenario(to scenario: DemoScenario) {
        cancelTransition()
        state = PersistedState(
            scenario: scenario,
            projection: DemoFixtureFactory.projection(for: scenario)
        )
        persist(clearExistingError: false)
        broadcastProjection()
        broadcastSignals()
    }

    public func reset() {
        cancelTransition()
        state = PersistedState(
            scenario: .active,
            projection: DemoFixtureFactory.projection(for: .active)
        )
        persist()
        broadcastProjection()
        broadcastSignals()
    }

    private func prepareHandoff() {
        state.scenario = .away18Minutes
        var projection = DemoFixtureFactory.projection(for: .away18Minutes)
        projection.session?.presence = .handingOff
        state.projection = projection
        broadcastProjection()
        broadcastSignals()
    }

    private func prepareReturn() {
        state.scenario = .returning
        state.projection = DemoFixtureFactory.projection(for: .away18Minutes)
        broadcastProjection()
    }

    private func finishTransition(to scenario: DemoScenario, token: UUID) {
        guard transitionID == token, state.scenario == scenario else { return }
        state.projection = DemoFixtureFactory.projection(for: scenario)
        persist(clearExistingError: false)
        broadcastProjection()
        broadcastSignals()
        transitionTask = nil
        transitionID = nil
    }

    private func cancelTransition() {
        transitionTask?.cancel()
        transitionTask = nil
        transitionID = nil
    }

    private func broadcastProjection() {
        for continuation in projectionContinuations.values {
            continuation.yield(state.projection)
        }
    }

    private func broadcastSignals() {
        let signals = DemoFixtureFactory.signals(for: state.scenario)
        for continuation in signalContinuations.values {
            continuation.yield(signals)
        }
    }

    private func persist(clearExistingError: Bool = true) {
        do {
            if clearExistingError {
                state.projection.errorMessage = nil
            }
            try Self.write(state, to: storageURL)
        } catch {
            state.projection.errorMessage = error.localizedDescription
        }
    }

    private func removeProjectionContinuation(_ id: UUID) {
        projectionContinuations[id] = nil
    }

    private func removeSignalContinuation(_ id: UUID) {
        signalContinuations[id] = nil
    }

    private static func defaultStorageURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "Anchor Demo", directoryHint: .isDirectory)
            .appending(path: "demo-state.json")
    }

    private static func write(_ state: PersistedState, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }
}
