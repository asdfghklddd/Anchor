import Foundation

/// What a conversation's recap is written from.
public struct ConversationRecapFacts: Hashable, Sendable {
    public let taskTitle: String
    public let conversationName: String
    /// A turn is still working.
    public let isRunning: Bool
    public let transcript: ConversationTranscript

    public init(taskTitle: String, conversationName: String, isRunning: Bool, transcript: ConversationTranscript) {
        self.taskTitle = taskTitle
        self.conversationName = conversationName
        self.isRunning = isRunning
        self.transcript = transcript
    }

    /// Without a model: the latest request, which is where the conversation stands.
    var localRecap: String? {
        transcript.rounds.last.flatMap { SummaryLimit.recap($0.request) }
    }
}

/// Writes a conversation's recap: what it is about, what its latest rounds
/// did, where it stands; at most 60 characters.
public protocol ConversationRecapWriting: Sendable {
    func recap(_ facts: ConversationRecapFacts) async throws -> String
}

/// Recaps every open task's newest conversations when the phone reports a
/// return, and sends each task's recap to the phone as soon as it is written.
/// Runs on the Mac, which has the logs. A conversation that has not moved
/// since its last recap keeps it without asking the model again.
public actor ReturnRecapper {
    private let repository: any SessionRepository
    private let writer: any ConversationRecapWriting
    /// The log of the conversation a process belongs to, by its source.
    private let logFile: @Sendable (UUID) async -> URL?
    private var written: [URL: (transcript: ConversationTranscript, text: String)] = [:]
    private var started: Set<Date> = []
    private var watch: Task<Void, Never>?

    public init(repository: any SessionRepository, writer: any ConversationRecapWriting,
                logFile: @escaping @Sendable (UUID) async -> URL?) {
        self.repository = repository
        self.writer = writer
        self.logFile = logFile
    }

    public func start() {
        guard watch == nil else { return }
        let repository = self.repository
        watch = Task { [weak self] in
            for await projection in await repository.projections() {
                await self?.consider(projection)
            }
        }
    }

    public func stop() {
        watch?.cancel()
        watch = nil
    }

    /// Starts the recaps of a return not recapped yet, including one that was
    /// under way when the Mac quit.
    func consider(_ projection: SessionProjection) async {
        guard let returnedAt = projection.returnMoment, started.insert(returnedAt).inserted else { return }
        let tasks = projection.hostedSessions.filter { $0.returnRecap(for: returnedAt) == nil }
        await withTaskGroup(of: Void.self) { group in
            for task in tasks {
                group.addTask { await self.recapAndSend(task, returnedAt: returnedAt) }
            }
        }
    }

    private func recapAndSend(_ task: AnchorSession, returnedAt: Date) async {
        let recap = await recap(task, returnedAt: returnedAt)
        try? await repository.send(.forSession(task.id, .recordReturnRecap(recap)))
    }

    /// The task's three newest conversations, newest first, each recapped at once.
    func recap(_ task: AnchorSession, returnedAt: Date) async -> ReturnRecap {
        let conversations = TaskConversationStack(task: task).cards.sorted { $0.updatedAt > $1.updatedAt }
        var texts: [UUID: String] = [:]
        await withTaskGroup(of: (UUID, String?).self) { group in
            for conversation in conversations {
                group.addTask { (conversation.id, await self.text(for: conversation, in: task)) }
            }
            for await (id, text) in group { texts[id] = text }
        }
        return ReturnRecap(
            returnedAt: returnedAt,
            conversations: conversations.map { conversation in
                ConversationRecap(id: conversation.id, name: conversation.title,
                                  text: texts[conversation.id] ?? conversation.request.flatMap(SummaryLimit.recap) ?? "")
            }
        )
    }

    private func text(for conversation: AnchorProcess, in task: AnchorSession) async -> String? {
        guard let source = conversation.sourceID, let url = await logFile(source),
              let transcript = ConversationTranscript.read(at: url) else { return nil }
        if let cached = written[url], cached.transcript == transcript { return cached.text }
        let facts = ConversationRecapFacts(taskTitle: task.goal.title, conversationName: conversation.title,
                                           isRunning: conversation.status == .running, transcript: transcript)
        guard let text = (try? await writer.recap(facts)).flatMap(SummaryLimit.recap) else {
            // A failed call is asked again at the next return.
            return facts.localRecap
        }
        written[url] = (transcript, text)
        return text
    }
}
