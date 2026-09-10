import Foundation

/// Owns source lifetimes and serializes normalized observations into the
/// repository. A source failure is recorded per source and does not stop other
/// adapters or discard events that were already committed locally.
public actor ProcessSourceCoordinator: SourceHealthProviding, SourceActionPerforming {
    private struct AssociationKey: Hashable {
        let sessionID: UUID
        let sourceID: UUID
    }

    private let repository: any SessionRepository
    private var sources: [UUID: any ProcessSource]
    private var sourceTasks: [UUID: Task<Void, Never>] = [:]
    private var sourceGenerations: [UUID: UUID] = [:]
    private var projectionTask: Task<Void, Never>?
    private var healthByID: [UUID: SourceHealth]
    private var healthContinuations: [UUID: AsyncStream<[SourceHealth]>.Continuation] = [:]
    private let taskRunStore: TaskRunStore?
    private var associations: [AssociationKey: AnchorEventAssociation] = [:]
    private var isStarted = false

    public init(
        repository: any SessionRepository,
        sources: [any ProcessSource],
        taskRunStore: TaskRunStore? = nil
    ) {
        self.repository = repository
        var indexed: [UUID: any ProcessSource] = [:]
        var health: [UUID: SourceHealth] = [:]
        for source in sources {
            let descriptor = source.descriptor
            indexed[descriptor.id] = source
            health[descriptor.id] = SourceHealth(descriptor: descriptor)
        }
        self.sources = indexed
        self.taskRunStore = taskRunStore
        healthByID = health
    }

    /// Persists a source observation only after the caller has established ownership.
    public func record(_ observation: ExternalProcessEvent, association: AnchorEventAssociation) async throws {
        guard let taskRunStore else { return }
        let receivedAt = Date.now
        try await taskRunStore.record(
            event: observation.makeTaskEvent(association: association, receivedAt: receivedAt),
            run: observation.makeRun(association: association)
        )
    }

    public func setAssociation(
        _ association: AnchorEventAssociation,
        for sessionID: UUID,
        sourceID: UUID
    ) async throws {
        if let taskRunStore {
            try await taskRunStore.confirmAssociation(
                AnchorSessionAssociation(
                    sessionID: sessionID,
                    sourceID: sourceID,
                    target: association
                )
            )
        }
        associations[AssociationKey(sessionID: sessionID, sourceID: sourceID)] = association
    }

    public func start() async {
        if let taskRunStore {
            for saved in await taskRunStore.associations() {
                guard let sourceID = saved.sourceID else { continue }
                associations[AssociationKey(sessionID: saved.sessionID, sourceID: sourceID)] = saved.target
            }
        }
        isStarted = true
        for sourceID in sources.keys where sourceTasks[sourceID] == nil {
            start(sourceID: sourceID)
        }

        guard projectionTask == nil else { return }
        let repository = self.repository
        projectionTask = Task { [weak self] in
            let stream = await repository.projections()
            for await projection in stream {
                guard !Task.isCancelled else { break }
                await self?.handleProjection(projection)
            }
        }
    }

    public func stop() {
        isStarted = false
        projectionTask?.cancel()
        projectionTask = nil
        for task in sourceTasks.values {
            task.cancel()
        }
        sourceTasks.removeAll()
        for sourceID in sources.keys {
            updateHealth(sourceID) { health in
                health.status = .stopped
            }
        }
        for continuation in healthContinuations.values {
            continuation.finish()
        }
        healthContinuations.removeAll()
    }

    public func retry(sourceID: UUID) {
        sourceTasks[sourceID]?.cancel()
        sourceTasks[sourceID] = nil
        guard sources[sourceID] != nil else { return }
        start(sourceID: sourceID)
    }

    public func register(_ source: any ProcessSource) {
        let descriptor = source.descriptor
        sourceTasks[descriptor.id]?.cancel()
        sourceTasks[descriptor.id] = nil
        sources[descriptor.id] = source
        healthByID[descriptor.id] = SourceHealth(descriptor: descriptor)
        publishHealth()
        if isStarted { start(sourceID: descriptor.id) }
    }

    public func healthSnapshot() -> [SourceHealth] {
        healthByID.values.sorted { $0.descriptor.name < $1.descriptor.name }
    }

    public func healthChanges() -> AsyncStream<[SourceHealth]> {
        let id = UUID()
        return AsyncStream { continuation in
            healthContinuations[id] = continuation
            continuation.yield(healthSnapshot())
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeHealthContinuation(id) }
            }
        }
    }

    public func perform(
        _ action: SourceAction,
        on sourceID: UUID
    ) async throws -> SourceActionReceipt {
        guard let source = sources[sourceID] else {
            throw ProcessSourceError.unsupportedAction
        }
        do {
            let receipt = try await source.perform(action)
            updateHealth(sourceID) { health in
                health.lastError = nil
                health.consecutiveFailures = 0
            }
            return receipt
        } catch {
            updateHealth(sourceID) { health in
                health.lastError = error.localizedDescription
                health.consecutiveFailures += 1
            }
            throw error
        }
    }

    private func start(sourceID: UUID) {
        guard let source = sources[sourceID] else { return }
        let generation = UUID()
        sourceGenerations[sourceID] = generation
        updateHealth(sourceID) { health in
            health.status = .running
            health.lastAttemptAt = .now
            health.lastError = nil
        }

        sourceTasks[sourceID] = Task { [weak self, source] in
            await self?.consume(source, sourceID: sourceID, generation: generation)
        }
    }

    private func consume(
        _ source: any ProcessSource,
        sourceID: UUID,
        generation: UUID
    ) async {
        do {
            for try await externalEvent in source.events() {
                try Task.checkCancellation()

                do {
                    guard let currentSessionID = await repository.currentProjection().session?.id else {
                        throw SessionRepositoryError.noActiveSession
                    }
                    guard currentSessionID == externalEvent.sessionID else {
                        throw ProcessSourceError.sessionMismatch
                    }
                    let observation = try externalEvent.observation()
                    try await repository.send(.observeProcess(observation))
                    let associationKey = AssociationKey(
                        sessionID: externalEvent.sessionID,
                        sourceID: externalEvent.sourceID
                    )
                    if let association = associations[associationKey], let taskRunStore {
                        let receivedAt = Date.now
                        try await taskRunStore.record(
                            event: externalEvent.makeTaskEvent(
                                association: association,
                                receivedAt: receivedAt
                            ),
                            run: externalEvent.makeRun(association: association)
                        )
                    }
                    // A durable source cursor advances only after every local
                    // projection owned by this ingestion path has committed.
                    try await source.acknowledge(externalEvent)
                    updateHealth(sourceID) { health in
                        health.status = .running
                        health.lastEventAt = externalEvent.occurredAt
                        health.eventCount += 1
                        health.consecutiveFailures = 0
                        health.lastError = nil
                    }
                } catch {
                    if case SessionRepositoryError.noActiveSession = error {
                        do {
                            try await source.retry(externalEvent)
                            updateHealth(sourceID) { health in
                                health.status = .waitingForSession
                                health.lastError = error.localizedDescription
                            }
                        } catch {
                            updateHealth(sourceID) { health in
                                health.status = .failed
                                health.lastError = error.localizedDescription
                                health.consecutiveFailures += 1
                            }
                        }
                        // Stop until a projection with an active session
                        // arrives. This prevents a requeued event from
                        // spinning indefinitely at the polling interval.
                        if sourceGenerations[sourceID] == generation {
                            sourceTasks[sourceID] = nil
                        }
                        return
                    }

                    // Invalid or stale domain observations are intentionally
                    // discarded. They must still be acknowledged so a durable
                    // source does not replay the same unusable row forever.
                    if error is ProcessSourceError || error is TaskRunStoreError {
                        do {
                            try await source.acknowledge(externalEvent)
                        } catch {
                            do { try await source.retry(externalEvent) } catch {}
                            updateHealth(sourceID) { health in
                                health.status = .failed
                                health.lastError = error.localizedDescription
                                health.consecutiveFailures += 1
                            }
                            if sourceGenerations[sourceID] == generation {
                                sourceTasks[sourceID] = nil
                            }
                            return
                        }
                        updateHealth(sourceID) { health in
                            health.lastError = error.localizedDescription
                            health.consecutiveFailures += 1
                        }
                        continue
                    }

                    // Repository or disk failures are retryable. Leave the
                    // durable cursor uncommitted and stop until the user or
                    // caller restarts this source.
                    do { try await source.retry(externalEvent) } catch {}
                    updateHealth(sourceID) { health in
                        health.status = .failed
                        health.lastError = error.localizedDescription
                        health.consecutiveFailures += 1
                    }
                    if sourceGenerations[sourceID] == generation {
                        sourceTasks[sourceID] = nil
                    }
                    return
                }
            }

            updateHealth(sourceID) { health in
                health.status = .stopped
            }
        } catch is CancellationError {
            updateHealth(sourceID) { health in
                health.status = .stopped
            }
        } catch {
            updateHealth(sourceID) { health in
                health.status = .failed
                health.lastError = error.localizedDescription
                health.consecutiveFailures += 1
            }
        }

        if sourceGenerations[sourceID] == generation {
            sourceTasks[sourceID] = nil
        }
    }

    private func handleProjection(_ projection: SessionProjection) {
        guard projection.session != nil else { return }
        for sourceID in sources.keys where sourceTasks[sourceID] == nil {
            guard healthByID[sourceID]?.status == .waitingForSession else { continue }
            start(sourceID: sourceID)
        }
    }

    private func updateHealth(
        _ sourceID: UUID,
        _ change: (inout SourceHealth) -> Void
    ) {
        guard var health = healthByID[sourceID] else { return }
        change(&health)
        healthByID[sourceID] = health
        let snapshot = healthSnapshot()
        for continuation in healthContinuations.values {
            continuation.yield(snapshot)
        }
    }

    private func publishHealth() {
        let snapshot = healthSnapshot()
        for continuation in healthContinuations.values { continuation.yield(snapshot) }
    }

    private func removeHealthContinuation(_ id: UUID) {
        healthContinuations[id] = nil
    }
}
