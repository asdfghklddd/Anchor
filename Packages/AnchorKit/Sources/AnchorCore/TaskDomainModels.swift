import Foundation

/// Task-centric contract shared by the iPhone history and macOS observers.
public enum AnchorTaskLifecycle: String, Codable, Hashable, Sendable {
    case active
    case awaitingUserConfirmation
    case archived
}

public enum AnchorRunExecution: String, Codable, Hashable, Sendable {
    case queued
    case running
    case waitingBackground
    case idle
}

public enum AnchorRunOutcome: String, Codable, Hashable, Sendable {
    case none
    case completed
    case failed
    case interrupted
}

/// Attention facts are independent from execution and outcome. An empty set
/// represents `none`, allowing multiple facts such as stale + prior failure.
public enum AnchorRunAttention: String, Codable, Hashable, Sendable {
    case needsInput
    case hasFailure
    case stale
}

public enum AnchorTaskEventKind: String, Codable, Hashable, Sendable {
    case queued
    case started
    case progress
    case needsInput
    case completed
    case failed
    case interrupted
    case stale
}

public enum AnchorTaskEventCodingError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
}

/// Privacy-minimal immutable fact retained for deterministic replay and history.
/// Titles, prompts, output, command arguments and paths never enter this type.
public struct AnchorTaskEvent: Identifiable, Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let id: UUID
    public let taskID: UUID
    public let workItemID: UUID
    public let runID: UUID
    public let sourceID: String
    public let sourceSessionID: String?
    public let sourceSequence: UInt64
    public let occurredAt: Date
    public let receivedAt: Date
    public let kind: AnchorTaskEventKind

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        workItemID: UUID,
        runID: UUID,
        sourceID: String,
        sourceSessionID: String? = nil,
        sourceSequence: UInt64,
        occurredAt: Date,
        receivedAt: Date = .now,
        kind: AnchorTaskEventKind
    ) {
        self.version = Self.currentVersion
        self.id = id
        self.taskID = taskID
        self.workItemID = workItemID
        self.runID = runID
        self.sourceID = sourceID
        self.sourceSessionID = sourceSessionID
        self.sourceSequence = sourceSequence
        self.occurredAt = occurredAt
        self.receivedAt = receivedAt
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case version, id, taskID, workItemID, runID, sourceID, sourceSessionID
        case sourceSequence, occurredAt, receivedAt, kind
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard decodedVersion == Self.currentVersion else {
            throw AnchorTaskEventCodingError.unsupportedVersion(decodedVersion)
        }
        version = decodedVersion
        id = try values.decode(UUID.self, forKey: .id)
        taskID = try values.decode(UUID.self, forKey: .taskID)
        workItemID = try values.decode(UUID.self, forKey: .workItemID)
        runID = try values.decode(UUID.self, forKey: .runID)
        sourceID = try values.decode(String.self, forKey: .sourceID)
        sourceSessionID = try values.decodeIfPresent(String.self, forKey: .sourceSessionID)
        sourceSequence = try values.decode(UInt64.self, forKey: .sourceSequence)
        occurredAt = try values.decode(Date.self, forKey: .occurredAt)
        receivedAt = try values.decode(Date.self, forKey: .receivedAt)
        kind = try values.decode(AnchorTaskEventKind.self, forKey: .kind)
    }
}

public struct AnchorTask: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var completionCriteria: String
    public var createdAt: Date
    public var lifecycle: AnchorTaskLifecycle
    public var endedAt: Date?

    public init(id: UUID = UUID(), title: String, completionCriteria: String, createdAt: Date = .now,
                lifecycle: AnchorTaskLifecycle = .active, endedAt: Date? = nil) {
        self.id = id; self.title = title; self.completionCriteria = completionCriteria
        self.createdAt = createdAt; self.lifecycle = lifecycle; self.endedAt = endedAt
    }
}

public struct AnchorWorkItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public var title: String
    public var generation: Int
    public var createdAt: Date

    public init(id: UUID = UUID(), taskID: UUID, title: String, generation: Int = 0, createdAt: Date = .now) {
        self.id = id; self.taskID = taskID; self.title = title; self.generation = generation; self.createdAt = createdAt
    }
}

public struct AnchorRun: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let workItemID: UUID
    public let sourceID: String
    public let sourceSessionID: String?
    public var execution: AnchorRunExecution
    public var attention: Set<AnchorRunAttention>
    public var outcome: AnchorRunOutcome
    public let startedAt: Date
    public var finishedAt: Date?

    public init(id: UUID = UUID(), taskID: UUID, workItemID: UUID, sourceID: String,
                sourceSessionID: String? = nil, execution: AnchorRunExecution = .queued,
                attention: Set<AnchorRunAttention> = [], outcome: AnchorRunOutcome = .none,
                startedAt: Date = .now, finishedAt: Date? = nil) {
        self.id = id; self.taskID = taskID; self.workItemID = workItemID; self.sourceID = sourceID
        self.sourceSessionID = sourceSessionID; self.execution = execution; self.attention = attention; self.outcome = outcome
        self.startedAt = startedAt; self.finishedAt = finishedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, taskID, workItemID, sourceID, sourceSessionID, execution, attention, outcome, startedAt, finishedAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        taskID = try values.decode(UUID.self, forKey: .taskID)
        workItemID = try values.decode(UUID.self, forKey: .workItemID)
        sourceID = try values.decode(String.self, forKey: .sourceID)
        sourceSessionID = try values.decodeIfPresent(String.self, forKey: .sourceSessionID)
        execution = try values.decode(AnchorRunExecution.self, forKey: .execution)
        attention = try values.decodeIfPresent(Set<AnchorRunAttention>.self, forKey: .attention) ?? []
        outcome = try values.decode(AnchorRunOutcome.self, forKey: .outcome)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        finishedAt = try values.decodeIfPresent(Date.self, forKey: .finishedAt)
    }
}

/// Complete task-scoped history kept separate from the single foreground task.
public struct AnchorTaskRecord: Codable, Equatable, Sendable {
    public let task: AnchorTask
    public let state: AnchorTaskState
    public let workItems: [AnchorWorkItem]
    public let runs: [AnchorRun]
    public let events: [AnchorTaskEvent]

    public init(
        task: AnchorTask,
        state: AnchorTaskState,
        workItems: [AnchorWorkItem],
        runs: [AnchorRun],
        events: [AnchorTaskEvent]
    ) {
        self.task = task
        self.state = state
        self.workItems = workItems
        self.runs = runs
        self.events = events
    }
}
