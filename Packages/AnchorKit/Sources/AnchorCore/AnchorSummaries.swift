import Foundation

/// How long the glance texts may be: a conversation's name on a desk card
/// (about 8 to 10 Chinese characters) and a task's state when the person left
/// (at most 60 characters). Every draft is held to these, whoever wrote it,
/// so a model that says too much still fits the card.
public enum SummaryLimit {
    /// `AnchorTitleLength` units: about 10 Chinese characters or 20 Latin ones.
    public static let conversationName = 20
    /// Characters, as the person counts them.
    public static let leaveRecap = 60

    /// One line, cut at a natural break when one is near; `nil` when nothing is left.
    public static func name(_ text: String) -> String? {
        let line = oneLine(text)
        guard !line.isEmpty else { return nil }
        let title = AnchorTitleLength.split(line, limit: conversationName).title
        return title.isEmpty ? nil : title
    }

    public static func recap(_ text: String) -> String? {
        let line = oneLine(text)
        guard !line.isEmpty else { return nil }
        return line.count > leaveRecap ? String(line.prefix(leaveRecap - 1)) + "…" : line
    }

    private static func oneLine(_ text: String) -> String {
        text.replacing(/\s+/, with: " ").trimmingCharacters(in: .whitespaces)
    }
}

/// What is known about a conversation when it is named.
public struct ConversationNameSource: Hashable, Sendable {
    /// The agent's or app's own name for it: Claude Code's title, Codex's thread name.
    public var ownName: String?
    /// The opening of the person's first request in it.
    public var firstRequest: String?

    public init(ownName: String? = nil, firstRequest: String? = nil) {
        self.ownName = ownName
        self.firstRequest = firstRequest
    }

    /// A name drawn from the facts alone: the conversation's own name when it
    /// has one, else the first clause of its first request without the polite
    /// opening ("帮我", "Please").
    public var gist: String? {
        if let ownName = ownName.flatMap(SummaryLimit.name) { return ownName }
        guard let request = firstRequest else { return nil }
        let clause = request.split(whereSeparator: { "\n。！？!?；;，,：:".contains($0) }).first.map(String.init) ?? request
        var text = clause.trimmingCharacters(in: .whitespaces)
        var trimmed = true
        while trimmed {
            trimmed = false
            for opening in Self.openings where text.lowercased().hasPrefix(opening) {
                text = String(text.dropFirst(opening.count)).trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
                trimmed = true
            }
        }
        return SummaryLimit.name(text)
    }

    private static let openings = [
        "帮我", "请你", "麻烦你", "麻烦", "请", "我想要", "我想", "我们来", "我们", "能不能", "可以", "你能",
        "please", "can you", "could you", "help me", "i want to", "i'd like to", "let's",
    ]
}

/// A task's state at the moment the person left: what a recap is written from.
public struct TaskLeaveFacts: Hashable, Sendable {
    /// One of the task's conversations, newest first.
    public struct Conversation: Hashable, Sendable {
        public let name: String
        public let status: ProcessStatus
        public let isInterrupted: Bool
        public let request: String?
        public let reply: String?
    }

    public let taskID: UUID
    public let title: String
    public let stepCount: Int
    public let stepsDone: Int
    /// The first step not done, numbered from 1.
    public let nextStepNumber: Int?
    public let nextStepText: String?
    /// What the task needed from the person, if anything.
    public let action: TaskNextAction?
    /// At most three, newest first.
    public let conversations: [Conversation]

    public init(task: AnchorSession) {
        taskID = task.id
        title = task.goal.title
        let plan = task.goal.userPlan
        stepCount = plan?.steps.count ?? 0
        stepsDone = plan?.doneCount ?? 0
        nextStepNumber = plan?.nextStepIndex.map { $0 + 1 }
        nextStepText = plan.flatMap { plan in plan.nextStepIndex.map { plan.items[$0].text } }
        action = TaskNextAction(task: task)
        conversations = task.taskProcesses.filter(\.isConversation)
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(TaskConversationStack.capacity)
            .map { Conversation(name: $0.title, status: $0.status, isInterrupted: $0.isInterrupted,
                                request: $0.request, reply: $0.latestReply) }
    }
}

/// Writes the glance texts. The app always has a local writer that works
/// offline from the facts; a model-backed writer (an LLM API) can be added
/// alongside it and is preferred once it answers.
public protocol AnchorSummarizer: Sendable {
    /// A name of about 8 to 10 Chinese characters.
    func conversationName(_ source: ConversationNameSource) async throws -> String
    /// The task's state when the person left, in at most 60 characters.
    func leaveRecap(_ facts: TaskLeaveFacts) async throws -> String
}

/// The glance texts the Mac sends and shows. It answers at once with the
/// local draft and never waits for a model: a model's name replaces the draft
/// on the next event once it arrives, and each name is asked for only once
/// per source text, so a conversation costs one model call.
public actor SummaryBook {
    private let local: any AnchorSummarizer
    private let model: (any AnchorSummarizer)?
    private var sources: [URL: ConversationNameSource] = [:]
    private var drafts: [ConversationNameSource: String] = [:]
    private var written: [ConversationNameSource: String] = [:]
    private var asked: Set<ConversationNameSource> = []

    public init(local: any AnchorSummarizer, model: (any AnchorSummarizer)? = nil) {
        self.local = local
        self.model = model
    }

    /// What the latest scan knows about conversations, by log file. A log the
    /// scan no longer lists keeps the name it had.
    public func note(_ seen: [URL: ConversationNameSource]) {
        sources.merge(seen) { _, new in new }
    }

    /// The short name of the conversation in this log, if the Mac knows it.
    public func name(for fileURL: URL) async -> String? {
        guard let source = sources[fileURL] else { return nil }
        if let written = written[source] { return written }
        if let model, asked.insert(source).inserted {
            Task { await self.write(source, with: model) }
        }
        if let draft = drafts[source] { return draft }
        let draft = (try? await local.conversationName(source)).flatMap(SummaryLimit.name)
        drafts[source] = draft
        return draft
    }

    /// Each open task's state as the person leaves, by task. The model writes
    /// a recap when it answers; otherwise, or when it fails, the local writer does.
    public func leaveRecaps(for tasks: [AnchorSession]) async -> [UUID: String] {
        var recaps: [UUID: String] = [:]
        for task in tasks {
            let facts = TaskLeaveFacts(task: task)
            let modelRecap: String? = if let model {
                (try? await model.leaveRecap(facts)).flatMap(SummaryLimit.recap)
            } else {
                nil
            }
            if let recap = modelRecap {
                recaps[task.id] = recap
            } else {
                recaps[task.id] = (try? await local.leaveRecap(facts)).flatMap(SummaryLimit.recap)
            }
        }
        return recaps
    }

    private func write(_ source: ConversationNameSource, with model: any AnchorSummarizer) async {
        if let name = (try? await model.conversationName(source)).flatMap(SummaryLimit.name) {
            written[source] = name
        } else {
            // A failed call may be asked again on the next event.
            asked.remove(source)
        }
    }
}
