import Foundation

/// Owns source lifetimes and serializes normalized observations into the
/// repository. A source failure is recorded per source and does not stop other
/// adapters or discard events that were already committed locally.
public actor ProcessSourceCoordinator: SourceHealthProviding, SourceActionPerforming {
    private let repository: any SessionRepository
    private let sources: [UUID: any ProcessSource]
    private var sourceTasks: [UUID: Task<Void, Never>] = [:]
    private var sourceGenerations: [UUID: UUID] = [:]
    private var projectionTask: Task<Void, Never>?
    private var healthByID: [UUID: SourceHealth]
    private var healthContinuations: [UUID: AsyncStream<[SourceHealth]>.Continuation] = [:]

    public init(
        repository: any SessionRepository,
        sources: [any ProcessSource]
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
        healthByID = health
    }

    public func start() {
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
                    let observation = try externalEvent.observation()
                    try await repository.send(.observeProcess(observation))
                    updateHealth(sourceID) { health in
                        health.status = .running
                        health.lastEventAt = externalEvent.occurredAt
                        health.eventCount += 1
                        health.consecutiveFailures = 0
                        health.lastError = nil
                    }
                } catch {
                    // A source observation is moved out of the inbox before
                    // it reaches the repository. Only the absence of an
                    // Anchor session is retryable here; malformed or stale
                    // observations stay in the processed audit trail.
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
                    updateHealth(sourceID) { health in
                        health.lastError = error.localizedDescription
                        health.consecutiveFailures += 1
                    }
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

    private func removeHealthContinuation(_ id: UUID) {
        healthContinuations[id] = nil
    }
}
