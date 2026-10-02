import Foundation

/// Shared production binding boundary: each file keeps an explicit task owner.
/// The same observer is exercised by the phone-to-Mac workflow tests.
public actor CodexSessionBinder {
    private let repository: any SessionRepository
    private let coordinator: ProcessSourceCoordinator
    private let taskRunStore: TaskRunStore
    private let checkpointStore: CodexLifecycleCheckpointStore

    public init(repository: any SessionRepository, coordinator: ProcessSourceCoordinator,
                taskRunStore: TaskRunStore, checkpointStore: CodexLifecycleCheckpointStore) {
        self.repository = repository
        self.coordinator = coordinator
        self.taskRunStore = taskRunStore
        self.checkpointStore = checkpointStore
    }

    public func bind(fileURL: URL, sessionID: UUID, automaticallyMatched: Bool) async throws {
        let projection = await repository.currentProjection()
        guard let session = projection.hostedSessions.first(where: { $0.id == sessionID }) else {
            throw SessionRepositoryError.noActiveSession
        }
        let sourceID = StableProcessIdentity.id(
            namespace: "anchor.source.codex-session",
            sessionID: session.id,
            externalID: fileURL.lastPathComponent
        )
        let task = AnchorTask(
            id: session.id,
            title: session.goal.title,
            completionCriteria: session.goal.completionCriteria,
            createdAt: session.startedAt
        )
        let workItemID = StableProcessIdentity.id(
            namespace: "anchor.work-item.codex",
            sessionID: session.id,
            externalID: fileURL.lastPathComponent
        )
        let workItem = AnchorWorkItem(
            id: workItemID,
            taskID: task.id,
            title: "Codex conversation",
            createdAt: session.startedAt
        )
        try await taskRunStore.host(task: task)
        try await taskRunStore.upsert(workItem: workItem)
        let repository = self.repository
        let boundSessionContext: @Sendable () async -> ProcessSourceSessionContext? = {
            guard let bound = await repository.currentProjection().hostedSessions.first(where: { $0.id == session.id }) else { return nil }
            return ProcessSourceSessionContext(sessionID: bound.id, startedAt: bound.startedAt)
        }
        let codexSource = CodexLifecycleFileSource(
            fileURL: fileURL,
            sessionContextProvider: boundSessionContext,
            checkpointStore: checkpointStore,
            descriptor: SourceDescriptor(
                id: sourceID,
                name: "Codex",
                kind: .integration,
                symbol: "C",
                tone: "cyan",
                capabilities: [.observe],
                permission: .granted
            )
        )
        try await coordinator.setAssociation(
            AnchorEventAssociation(taskID: task.id, workItemID: workItem.id, confirmedByUser: !automaticallyMatched, automaticallyMatched: automaticallyMatched),
            for: session.id,
            sourceID: codexSource.descriptor.id
        )
        await coordinator.register(codexSource)
    }
}
