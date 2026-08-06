import Foundation
import Observation

@MainActor
@Observable
public final class AnchorSessionModel {
    public private(set) var projection: SessionProjection
    public private(set) var isLoading = false
    public private(set) var lastError: String?

    private let repository: any SessionRepository
    private let presenceProvider: (any PresenceSignalProviding)?
    private var projectionTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private var presenceEvaluationTask: Task<Void, Never>?
    private var presenceReducer: PresenceReducer
    private var currentPosture = DevicePosture.unknown
    private var latestSignals: PresenceSignals
    private var pendingPresenceStatus: PresenceStatus?

    public init(
        repository: any SessionRepository,
        presenceProvider: (any PresenceSignalProviding)? = nil,
        initialProjection: SessionProjection = .empty,
        presencePolicy: PresencePolicy = PresencePolicy()
    ) {
        self.repository = repository
        self.presenceProvider = presenceProvider
        projection = initialProjection
        presenceReducer = PresenceReducer(
            status: initialProjection.session?.presence ?? .unknown,
            policy: presencePolicy
        )
        latestSignals = PresenceSignals(
            posture: .unknown,
            connection: initialProjection.connection,
            proximity: initialProjection.proximity
        )
    }

    public func start() {
        guard projectionTask == nil else { return }
        isLoading = true
        let repository = self.repository
        projectionTask = Task { [weak self] in
            let stream = await repository.projections()
            for await projection in stream {
                guard !Task.isCancelled else { break }
                guard let self else { break }
                let previousSessionID = self.projection.session?.id
                let previousPresence = self.projection.session?.presence
                if let presence = projection.session?.presence {
                    if previousSessionID != projection.session?.id {
                        self.pendingPresenceStatus = nil
                        self.presenceReducer.correct(to: presence)
                    } else if self.pendingPresenceStatus == presence {
                        self.pendingPresenceStatus = nil
                    } else if previousPresence != presence {
                        self.presenceReducer.correct(to: presence)
                    }
                }
                self.latestSignals.connection = projection.connection
                self.latestSignals.proximity = projection.proximity
                self.projection = projection
                self.isLoading = false
            }
        }

        if let presenceProvider {
            presenceTask = Task { [weak self] in
                let stream = await presenceProvider.presenceSignals()
                for await signals in stream {
                    guard !Task.isCancelled else { break }
                    await self?.consume(signals)
                }
            }
        }
    }

    public func stop() {
        projectionTask?.cancel()
        projectionTask = nil
        presenceTask?.cancel()
        presenceTask = nil
        presenceEvaluationTask?.cancel()
        presenceEvaluationTask = nil
        isLoading = false
    }

    public func dismissLastError() {
        lastError = nil
    }

    public func clearError() async {
        _ = await send(.clearError)
    }

    @discardableResult
    public func send(_ command: SessionCommand) async -> Bool {
        do {
            try await repository.send(command)
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func createSession(goal: AnchorGoal, processes: [AnchorProcess]) async -> Bool {
        await send(.createSession(goal: goal, processes: processes))
    }

    @discardableResult
    public func addNote(_ text: String) async -> Bool {
        await send(.addNote(text))
    }

    @discardableResult
    public func resolve(decision: Decision, option: DecisionOption) async -> Bool {
        await send(.resolveDecision(decisionID: decision.id, optionID: option.id))
    }

    @discardableResult
    public func continueWorking() async -> Bool {
        presenceReducer.acknowledgeReturn()
        let succeeded = await send(.acknowledgeReturn)
        if !succeeded {
            presenceReducer.correct(to: projection.session?.presence ?? .unknown)
        }
        schedulePresenceEvaluation(for: latestSignals)
        return succeeded
    }

    @discardableResult
    public func correctPresence(to status: PresenceStatus) async -> Bool {
        presenceReducer.correct(to: status)
        let succeeded = await publishPresence(status, at: .now)
        schedulePresenceEvaluation(for: latestSignals)
        return succeeded
    }

    public func updatePosture(_ posture: DevicePosture) async {
        guard projection.session != nil else { return }
        currentPosture = posture
        var signals = latestSignals
        signals.posture = posture
        signals.observedAt = .now
        await consume(signals)
    }

    private func consume(_ incomingSignals: PresenceSignals) async {
        var signals = incomingSignals
        if currentPosture == .unknown {
            currentPosture = signals.posture
        } else {
            signals.posture = currentPosture
        }
        latestSignals = signals

        await send(
            .updateSignals(
                connection: signals.connection,
                proximity: signals.proximity,
                at: signals.observedAt
            )
        )
        // Connection health is meaningful on the setup screen, but presence is
        // session-scoped. Do not publish a presence command until an Anchor
        // session exists.
        guard projection.session != nil else { return }
        let newStatus = presenceReducer.reduce(signals)
        if newStatus != projection.session?.presence {
            await publishPresence(newStatus, at: signals.observedAt)
        }
        schedulePresenceEvaluation(for: signals)
    }

    @discardableResult
    private func publishPresence(_ status: PresenceStatus, at date: Date) async -> Bool {
        pendingPresenceStatus = status
        let succeeded = await send(.updatePresence(status, at: date))
        if !succeeded {
            pendingPresenceStatus = nil
            presenceReducer.correct(to: projection.session?.presence ?? .unknown)
        }
        return succeeded
    }

    private func schedulePresenceEvaluation(for signals: PresenceSignals) {
        presenceEvaluationTask?.cancel()
        presenceEvaluationTask = nil

        guard signals.posture == .portrait,
              signals.connection == .disconnected,
              signals.proximity == .far else { return }

        let deadline: Date
        switch presenceReducer.status {
        case .away, .returning, .unknown:
            return
        case .handingOff:
            guard let beganAt = presenceReducer.handoffBeganAt else { return }
            deadline = beganAt.addingTimeInterval(presenceReducer.policy.handoffDuration)
        case .atDesk:
            guard let beganAt = presenceReducer.absenceBeganAt else { return }
            deadline = beganAt.addingTimeInterval(presenceReducer.policy.absenceConfirmation)
        }

        let delay = max(0, deadline.timeIntervalSinceNow)
        presenceEvaluationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            var currentSignals = self.latestSignals
            currentSignals.observedAt = .now
            await self.consume(currentSignals)
        }
    }
}
