// Role: connects one conversation log to one task. Registers a `CodexLifecycleFileSource` for it with
// the coordinator and records the association, so its turns land on the right task.
// Used by: `MacSourceSetupModel` when `TaskMatcher` or the person places a conversation.

import Foundation

/// Shared production binding boundary: each file keeps an explicit task owner.
/// The same observer is exercised by the phone-to-Mac workflow tests.
public actor CodexSessionBinder {
    private let repository: any SessionRepository
    private let coordinator: ProcessSourceCoordinator
    private let taskRunStore: TaskRunStore
    private let checkpointStore: CodexLifecycleCheckpointStore
    /// Short conversation names for the phone; without it, the workspace folder names them.
    private let names: SummaryBook?
    /// Each bound conversation's log, by the source its turns arrive from.
    private var logFiles: [UUID: URL] = [:]

    public init(repository: any SessionRepository, coordinator: ProcessSourceCoordinator,
                taskRunStore: TaskRunStore, checkpointStore: CodexLifecycleCheckpointStore,
                names: SummaryBook? = nil) {
        self.repository = repository
        self.coordinator = coordinator
        self.taskRunStore = taskRunStore
        self.checkpointStore = checkpointStore
        self.names = names
    }

    /// Starts observing this log for this task. Binding the same pair again is harmless.
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
        let isHarness = conversation?.originator == HarnessSessionStatus.originator
        let isWorkBuddy = conversation?.originator == WorkBuddyLog.originator
        try await taskRunStore.host(task: task)
        try await taskRunStore.upsert(workItem: workItem)
        let repository = self.repository
        var conversationName: (@Sendable () async -> String?)?
        if let names = self.names {
            conversationName = { await names.name(for: fileURL) }
        }
        let boundSessionContext: @Sendable () async -> ProcessSourceSessionContext? = {
            guard let bound = await repository.currentProjection().hostedSessions.first(where: { $0.id == session.id }) else { return nil }
            return ProcessSourceSessionContext(sessionID: bound.id, startedAt: bound.startedAt)
        }
        let descriptor = SourceDescriptor(
            id: sourceID,
            name: conversation?.sourceName ?? "Codex",
            kind: .integration,
            symbol: isWorkBuddy ? "WB" : (isHarness ? "DS" : (isClaudeCode ? "CC" : "C")),
            tone: isWorkBuddy ? "seafoam" : (isHarness ? "periwinkle" : (isClaudeCode ? "coral" : "cyan")),
            capabilities: [.observe],
            permission: .granted
        )
        let source: any ProcessSource = isHarness
            ? DeepSeekHarnessSource(fileURL: fileURL, sessionContextProvider: boundSessionContext,
                                    descriptor: descriptor, conversationTitle: conversation?.workspaceName,
                                    conversationName: conversationName, stepID: stepID)
            : CodexLifecycleFileSource(fileURL: fileURL, sessionContextProvider: boundSessionContext,
                                       checkpointStore: checkpointStore, descriptor: descriptor,
                                       conversationTitle: conversation?.workspaceName,
                                       conversationName: conversationName, stepID: stepID)
        try await coordinator.setAssociation(
            AnchorEventAssociation(taskID: task.id, workItemID: workItem.id, confirmedByUser: !automaticallyMatched, automaticallyMatched: automaticallyMatched),
            for: session.id,
            sourceID: sourceID
        )
        await coordinator.register(source)
        logFiles[sourceID] = fileURL
    }

    /// The log of a bound conversation, for reading its latest rounds.
    public func logFile(forSource sourceID: UUID) -> URL? {
        logFiles[sourceID]
    }

    /// Stops observing a conversation for one task and removes its rows there,
    /// as when the person moves it elsewhere. The task's history keeps what happened.
    public func unbind(fileURL: URL, sessionID: UUID) async throws {
        let sourceID = Self.sourceID(fileURL: fileURL, sessionID: sessionID)
        await coordinator.unregister(sourceID: sourceID)
        logFiles[sourceID] = nil
        let projection = await repository.currentProjection()
        guard let session = projection.hostedSessions.first(where: { $0.id == sessionID }) else { return }
        for process in session.processes where process.sourceID == sourceID {
            try await repository.send(.forSession(sessionID, .removeProcess(process.id)))
        }
    }

    /// A stable source identity for one log + task pair, so relaunches keep the same conversation rows.
    static func sourceID(fileURL: URL, sessionID: UUID) -> UUID {
        StableProcessIdentity.id(
            namespace: "anchor.source.codex-session",
            sessionID: sessionID,
            externalID: fileURL.lastPathComponent
        )
    }
}
