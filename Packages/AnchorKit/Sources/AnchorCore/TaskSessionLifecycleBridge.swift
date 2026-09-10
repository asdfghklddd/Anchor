import Foundation

/// Keeps the task history boundary aligned with the current user-owned session.
/// Source completion never archives a task; only the session's explicit final
/// completion or creation of a later user task can move it into history.
public actor TaskSessionLifecycleBridge {
    private let repository: any SessionRepository
    private let taskRunStore: TaskRunStore
    private var observationTask: Task<Void, Never>?
    public private(set) var lastErrorDescription: String?

    public init(repository: any SessionRepository, taskRunStore: TaskRunStore) {
        self.repository = repository
        self.taskRunStore = taskRunStore
    }

    public func start() {
        guard observationTask == nil else { return }
        let repository = repository
        observationTask = Task { [weak self] in
            let projections = await repository.projections()
            for await projection in projections {
                guard !Task.isCancelled, let self else { return }
                await self.consume(projection)
            }
        }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
    }

    public func synchronize(_ projection: SessionProjection) async throws {
        guard let session = projection.session else { return }
        let task = AnchorTask(
            id: session.id,
            title: session.goal.title,
            completionCriteria: session.goal.completionCriteria,
            createdAt: session.startedAt
        )

        switch session.status {
        case .draft, .active:
            try await taskRunStore.activate(task: task)
        case .completed, .archived:
            if await taskRunStore.taskState(id: task.id)?.lifecycle == .archived {
                return
            }
            try await taskRunStore.activate(task: task)
            try await taskRunStore.confirmTaskEnded(
                taskID: task.id,
                at: session.completedAt ?? projection.generatedAt
            )
        }
    }

    private func consume(_ projection: SessionProjection) async {
        do {
            try await synchronize(projection)
            lastErrorDescription = nil
        } catch {
            lastErrorDescription = String(describing: error)
        }
    }
}
