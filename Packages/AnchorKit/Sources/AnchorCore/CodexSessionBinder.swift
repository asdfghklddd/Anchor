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

    public func bind(fileURL: URL, sessionID: UUID, automaticallyMatched: Bool, stepID: UUID? = nil) async throws {
        let projection = await repository.currentProjection()
        guard let session = projection.hostedSessions.first(where: { $0.id == sessionID }) else {
            throw SessionRepositoryError.noActiveSession
        }
        let sourceID = Self.sourceID(fileURL: fileURL, sessionID: session.id)
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
        let conversation = CodexSessionMetadata.read(from: fileURL)
        let isClaudeCode = conversation?.originator == CodexSessionMetadata.claudeCodeOriginator
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
                name: conversation?.sourceName ?? "Codex",
                kind: .integration,
                symbol: isClaudeCode ? "CC" : "C",
                tone: isClaudeCode ? "coral" : "cyan",
                capabilities: [.observe],
                permission: .granted
            ),
            conversationTitle: conversation?.workspaceName,
            stepID: stepID
        )
        try await coordinator.setAssociation(
            AnchorEventAssociation(taskID: task.id, workItemID: workItem.id, confirmedByUser: !automaticallyMatched, automaticallyMatched: automaticallyMatched),
            for: session.id,
            sourceID: codexSource.descriptor.id
        )
        await coordinator.register(codexSource)
    }

    /// Stops observing a conversation for one task and removes its rows there,
    /// as when the person moves it elsewhere. The task's history keeps what happened.
    public func unbind(fileURL: URL, sessionID: UUID) async throws {
        let sourceID = Self.sourceID(fileURL: fileURL, sessionID: sessionID)
        await coordinator.unregister(sourceID: sourceID)
        let projection = await repository.currentProjection()
        guard let session = projection.hostedSessions.first(where: { $0.id == sessionID }) else { return }
        for process in session.processes where process.sourceID == sourceID {
            try await repository.send(.forSession(sessionID, .removeProcess(process.id)))
        }
    }

    static func sourceID(fileURL: URL, sessionID: UUID) -> UUID {
        StableProcessIdentity.id(
            namespace: "anchor.source.codex-session",
            sessionID: sessionID,
            externalID: fileURL.lastPathComponent
        )
    }
}
