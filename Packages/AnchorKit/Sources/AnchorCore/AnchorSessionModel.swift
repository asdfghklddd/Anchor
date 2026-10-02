import Foundation
import Observation

@MainActor
@Observable
public final class AnchorSessionModel {
    public private(set) var projection: SessionProjection
    public private(set) var isLoading = false
    public private(set) var lastError: String?

    private let repository: any SessionRepository
    private let usesTaskDashboard: Bool
    private let presenceProvider: (any PresenceSignalProviding)?
    private let sourceHealthProvider: (any SourceHealthProviding)?
    private let durableSyncStatusProvider: (any DurableSyncStatusProviding)?
    private var projectionTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private var sourceHealthTask: Task<Void, Never>?
    private var durableSyncStatusTask: Task<Void, Never>?
    private var presenceEvaluationTask: Task<Void, Never>?
    private var presenceReducer: PresenceReducer
    private var currentPosture = DevicePosture.unknown
    private var latestSignals: PresenceSignals
    private var pendingPresenceStatus: PresenceStatus?
    private var lastReturnFeedbackKey: String?

    public init(
        repository: any SessionRepository,
        presenceProvider: (any PresenceSignalProviding)? = nil,
        sourceHealthProvider: (any SourceHealthProviding)? = nil,
        durableSyncStatusProvider: (any DurableSyncStatusProviding)? = nil,
        initialProjection: SessionProjection = .empty,
        presencePolicy: PresencePolicy = PresencePolicy(),
        usesTaskDashboard: Bool = false
    ) {
        self.repository = repository
        self.usesTaskDashboard = usesTaskDashboard
        self.presenceProvider = presenceProvider
        self.sourceHealthProvider = sourceHealthProvider
        self.durableSyncStatusProvider = durableSyncStatusProvider
        projection = usesTaskDashboard ? TaskDashboardPolicy.presentation(of: initialProjection) : initialProjection
        presenceReducer = PresenceReducer(
            status: initialProjection.session?.presence ?? .unknown,
            policy: presencePolicy
        )
        latestSignals = PresenceSignals(
            posture: .unknown,
            connection: initialProjection.connection,
            proximity: initialProjection.proximity
        )
        if initialProjection.connection == .connected,
           initialProjection.session?.presence != .away {
            presenceReducer.reduce(latestSignals)
        }
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
                self.projection = self.present(projection)
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

        if let sourceHealthProvider {
            sourceHealthTask = Task { [weak self] in
                let stream = await sourceHealthProvider.healthChanges()
                for await health in stream {
                    guard !Task.isCancelled else { break }
                    _ = await self?.send(.updateSourceHealth(health))
                }
            }
        }

        if let durableSyncStatusProvider {
            durableSyncStatusTask = Task { [weak self] in
                let stream = await durableSyncStatusProvider.statusChanges()
                for await state in stream {
                    guard !Task.isCancelled else { break }
                    _ = await self?.send(.updateDurableSyncState(state))
                }
            }
        }
    }

    public func stop() {
        projectionTask?.cancel()
        projectionTask = nil
        presenceTask?.cancel()
        presenceTask = nil
        sourceHealthTask?.cancel()
        sourceHealthTask = nil
        durableSyncStatusTask?.cancel()
        durableSyncStatusTask = nil
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
            if usesTaskDashboard && !TaskDashboardPolicy.allows(command) {
                throw ProcessSourceError.unsupportedAction
            }
            // Bind UI mutations to the task displayed when the action began.
            // A peer changing selection cannot redirect an in-flight edit.
            let scoped: SessionCommand
            switch command {
            case .updateGoal, .addNote, .resolveDecision, .addProcess, .updateProcess,
                 .removeProcess, .reorderProcesses, .updateTileSize, .recordEvent,
                 .completeSession, .archiveSession:
                let id: UUID?
                if let visibleID = projection.session?.id { id = visibleID }
                else { id = await repository.currentProjection().session?.id }
                guard let id else { throw SessionRepositoryError.noActiveSession }
                scoped = .forSession(id, command)
            default: scoped = command
            }
            try await repository.send(scoped)
            switch command {
            case .updateSignals, .updateSourceHealth, .updateDurableSyncState, .updatePresence:
                break // Operational refreshes must not dismiss an actionable user error.
            default:
                lastError = nil
            }
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
    public func selectHostedTask(_ id: UUID) async -> Bool {
        guard await send(.selectSession(id)) else { return false }
        projection = present(await repository.currentProjection())
        return true
    }

    @discardableResult
    public func hostTask(id: UUID, goal: AnchorGoal, processes: [AnchorProcess]) async -> Bool {
        let normalized = processes.map { process in
            var copy = process
            copy.sessionID = id
            return copy
        }
        let current = await repository.currentProjection()
        if current.hostedSessions.contains(where: { $0.id == id }) { return true }
        let nextColor = (current.hostedSessions.map { $0.taskColorIndex ?? 0 }.max() ?? -1) + 1
        guard await send(.hostSession(AnchorSession(id: id, goal: goal, processes: normalized, taskColorIndex: nextColor))) else { return false }
        projection = present(await repository.currentProjection())
        return true
    }

    @discardableResult
    public func addNote(_ text: String) async -> Bool {
        await send(.addNote(text))
    }

    private func present(_ projection: SessionProjection) -> SessionProjection {
        usesTaskDashboard ? TaskDashboardPolicy.presentation(of: projection) : projection
    }

    /// Consumed by the visible return screen, once per return, including view rebuilds.
    public func claimReturnFeedback() -> Bool {
        guard let session = projection.session, session.presence == .returning,
              let summary = session.returnSummary else { return false }
        let key = "\(session.id):\(summary.generatedAt.timeIntervalSince1970)"
        guard lastReturnFeedbackKey != key else { return false }
        lastReturnFeedbackKey = key
        return true
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

    /// A manual return follows the same summary path as a confirmed
    /// authenticated reconnection. Only the summary's Back action
    /// acknowledges the return and restores the workspace.
    @discardableResult
    public func beginReturn() async -> Bool {
        guard await repository.currentProjection().session?.presence == .away else {
            return false
        }
        return await correctPresence(to: .returning)
    }

    /// A reliable explicit path when proximity is unavailable. A nearby radio
    /// reading must not immediately undo the user's choice to leave.
    @discardableResult
    public func leaveDesk() async -> Bool {
        guard projection.session != nil else { return false }
        return await correctPresence(to: .away)
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
        let absenceBeganAt = presenceReducer.absenceBeganAt
        let newStatus = presenceReducer.reduce(signals)
        if newStatus != projection.session?.presence {
            // If iOS suspended our timer, the reconnect itself can confirm a
            // long interruption. Save its start without inventing an old snapshot.
            if newStatus == .returning, projection.session?.presence != .away,
               let absenceBeganAt {
                guard await publishPresence(.away, at: signals.observedAt, awaySince: absenceBeganAt) else { return }
            }
            await publishPresence(newStatus, at: signals.observedAt,
                awaySince: newStatus == .away ? absenceBeganAt : nil)
        }
        schedulePresenceEvaluation(for: signals)
    }

    @discardableResult
    private func publishPresence(_ status: PresenceStatus, at date: Date, awaySince: Date? = nil) async -> Bool {
        pendingPresenceStatus = status
        let succeeded = await send(.updatePresence(status, at: date, awaySince: awaySince))
        if !succeeded {
            pendingPresenceStatus = nil
            presenceReducer.correct(to: projection.session?.presence ?? .unknown)
        }
        return succeeded
    }

    private func schedulePresenceEvaluation(for signals: PresenceSignals) {
        presenceEvaluationTask?.cancel()
        presenceEvaluationTask = nil

        guard presenceReducer.canConfirmAbsence(signals) else { return }

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
