import Foundation

public struct AnchorGoal: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var completionCriteria: String
    public var note: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        completionCriteria: String,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.completionCriteria = completionCriteria
        self.note = note
        self.createdAt = createdAt
    }
}

public struct ProcessEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sessionID: UUID?
    public let processID: UUID?
    public let sourceID: UUID?
    public let externalID: String?
    public let deduplicationKey: String?
    public let occurredAt: Date
    public let receivedAt: Date?
    public let kind: ProcessEventKind
    public let title: String
    public let detail: String
    public let progress: Double?
    public let metric: String?
    public let metricLabel: String?
    public let deepLink: URL?

    public init(
        id: UUID = UUID(),
        sessionID: UUID? = nil,
        processID: UUID? = nil,
        sourceID: UUID? = nil,
        externalID: String? = nil,
        deduplicationKey: String? = nil,
        occurredAt: Date = .now,
        receivedAt: Date? = nil,
        kind: ProcessEventKind,
        title: String,
        detail: String = "",
        progress: Double? = nil,
        metric: String? = nil,
        metricLabel: String? = nil,
        deepLink: URL? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.processID = processID
        self.sourceID = sourceID
        self.externalID = externalID
        self.deduplicationKey = deduplicationKey
        self.occurredAt = occurredAt
        self.receivedAt = receivedAt
        self.kind = kind
        self.title = title
        self.detail = detail
        self.progress = progress
        self.metric = metric
        self.metricLabel = metricLabel
        self.deepLink = deepLink
    }
}

public struct AnchorProcess: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var sessionID: UUID?
    public var sourceID: UUID?
    public var externalID: String?
    public var deepLink: URL?
    public var sourceName: String
    public var sourceSymbol: String
    public var sourceTone: String
    public var title: String
    public var status: ProcessStatus
    public var progress: Double?
    public var metric: String
    public var metricLabel: String
    public var detail: String
    public var estimatedCompletion: String
    public var updatedAt: Date
    public var tileSize: ProcessTileSize
    public var events: [ProcessEvent]

    public init(
        id: UUID = UUID(),
        sessionID: UUID? = nil,
        sourceID: UUID? = nil,
        externalID: String? = nil,
        deepLink: URL? = nil,
        sourceName: String,
        sourceSymbol: String,
        sourceTone: String,
        title: String,
        status: ProcessStatus,
        progress: Double? = nil,
        metric: String = "",
        metricLabel: String = "",
        detail: String = "",
        estimatedCompletion: String = "",
        updatedAt: Date = .now,
        tileSize: ProcessTileSize = .standard,
        events: [ProcessEvent] = []
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.externalID = externalID
        self.deepLink = deepLink
        self.sourceName = sourceName
        self.sourceSymbol = sourceSymbol
        self.sourceTone = sourceTone
        self.title = title
        self.status = status
        self.progress = progress
        self.metric = metric
        self.metricLabel = metricLabel
        self.detail = detail
        self.estimatedCompletion = estimatedCompletion
        self.updatedAt = updatedAt
        self.tileSize = tileSize
        self.events = events
    }
}

public struct DecisionOption: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String

    public init(id: UUID = UUID(), title: String, detail: String = "") {
        self.id = id
        self.title = title
        self.detail = detail
    }
}

public struct Decision: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let processID: UUID
    public var title: String
    public var prompt: String
    public var options: [DecisionOption]
    public var status: DecisionStatus
    public var selectedOptionID: UUID?
    public var requestedAt: Date
    public var resolvedAt: Date?
    /// Optional keeps the payload readable by the first v1 native builds.
    public var priority: Int?

    public init(
        id: UUID = UUID(),
        processID: UUID,
        title: String,
        prompt: String,
        options: [DecisionOption],
        status: DecisionStatus = .open,
        selectedOptionID: UUID? = nil,
        requestedAt: Date = .now,
        resolvedAt: Date? = nil,
        priority: Int? = nil
    ) {
        self.id = id
        self.processID = processID
        self.title = title
        self.prompt = prompt
        self.options = options
        self.status = status
        self.selectedOptionID = selectedOptionID
        self.requestedAt = requestedAt
        self.resolvedAt = resolvedAt
        self.priority = priority
    }
}

public struct AnchorNote: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sessionID: UUID?
    public let processID: UUID?
    public let decisionID: UUID?
    public let origin: String?
    public let text: String
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID? = nil,
        processID: UUID? = nil,
        decisionID: UUID? = nil,
        origin: String? = nil,
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sessionID = sessionID
        self.processID = processID
        self.decisionID = decisionID
        self.origin = origin
        self.text = text
        self.createdAt = createdAt
    }
}

public struct ContextSnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let goalTitle: String
    public let processes: [AnchorProcess]
    public let processStates: [UUID: ProcessStatus]
    public let openDecisionIDs: [UUID]
    public let latestNote: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        goalTitle: String,
        processes: [AnchorProcess],
        openDecisionIDs: [UUID],
        latestNote: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.goalTitle = goalTitle
        self.processes = processes
        processStates = Dictionary(uniqueKeysWithValues: processes.map { ($0.id, $0.status) })
        self.openDecisionIDs = openDecisionIDs
        self.latestNote = latestNote
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case goalTitle
        case processes
        case processStates
        case openDecisionIDs
        case latestNote
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        goalTitle = try container.decode(String.self, forKey: .goalTitle)
        processes = try container.decodeIfPresent([AnchorProcess].self, forKey: .processes) ?? []
        processStates = try container.decodeIfPresent(
            [UUID: ProcessStatus].self,
            forKey: .processStates
        ) ?? Dictionary(uniqueKeysWithValues: processes.map { ($0.id, $0.status) })
        openDecisionIDs = try container.decode([UUID].self, forKey: .openDecisionIDs)
        latestNote = try container.decodeIfPresent(String.self, forKey: .latestNote)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(goalTitle, forKey: .goalTitle)
        try container.encode(processes, forKey: .processes)
        // Keep the original v1 field so a peer running the previous build can
        // still decode a session while newer peers receive immutable details.
        try container.encode(processStates, forKey: .processStates)
        try container.encode(openDecisionIDs, forKey: .openDecisionIDs)
        try container.encodeIfPresent(latestNote, forKey: .latestNote)
    }
}

public struct ReturnChange: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let occurredAt: Date
    public let title: String
    public let detail: String
    public let kind: ProcessEventKind

    public init(
        id: UUID = UUID(),
        occurredAt: Date = .now,
        title: String,
        detail: String,
        kind: ProcessEventKind
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.title = title
        self.detail = detail
        self.kind = kind
    }
}

public struct ReturnSummary: Codable, Hashable, Sendable {
    public var awaySince: Date
    public var generatedAt: Date
    public var changes: [ReturnChange]
    public var recommendedProcessID: UUID?
    /// These metrics are optional for compatibility with pre-MVP snapshots.
    public var elapsedSeconds: TimeInterval?
    public var completedCount: Int?
    public var failedCount: Int?
    public var newDecisionCount: Int?
    public var netChangeScore: Int?

    public init(
        awaySince: Date,
        generatedAt: Date = .now,
        changes: [ReturnChange],
        recommendedProcessID: UUID? = nil,
        elapsedSeconds: TimeInterval? = nil,
        completedCount: Int? = nil,
        failedCount: Int? = nil,
        newDecisionCount: Int? = nil,
        netChangeScore: Int? = nil
    ) {
        self.awaySince = awaySince
        self.generatedAt = generatedAt
        self.changes = changes
        self.recommendedProcessID = recommendedProcessID
        self.elapsedSeconds = elapsedSeconds
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.newDecisionCount = newDecisionCount
        self.netChangeScore = netChangeScore
    }

    public var impactPercent: Int {
        if let netChangeScore { return max(0, min(100, netChangeScore)) }
        return changes.isEmpty ? 0 : min(100, changes.count * 10)
    }
}

public struct AnchorNotification: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let processID: UUID?
    public let sourceName: String
    public let title: String
    public let body: String
    public let createdAt: Date
    public var isUnread: Bool

    public init(
        id: UUID = UUID(),
        processID: UUID? = nil,
        sourceName: String,
        title: String,
        body: String,
        createdAt: Date = .now,
        isUnread: Bool = true
    ) {
        self.id = id
        self.processID = processID
        self.sourceName = sourceName
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.isUnread = isUnread
    }
}

public struct AnchorSession: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var goal: AnchorGoal
    public var status: SessionStatus
    public var presence: PresenceStatus
    public var startedAt: Date
    public var completedAt: Date?
    public var processes: [AnchorProcess]
    public var decisions: [Decision]
    public var notes: [AnchorNote]
    public var timeline: [ProcessEvent]
    public var snapshots: [ContextSnapshot]
    public var returnSummary: ReturnSummary?
    public var processedEventIDs: Set<UUID>

    public init(
        id: UUID = UUID(),
        goal: AnchorGoal,
        status: SessionStatus = .active,
        presence: PresenceStatus = .atDesk,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        processes: [AnchorProcess] = [],
        decisions: [Decision] = [],
        notes: [AnchorNote] = [],
        timeline: [ProcessEvent] = [],
        snapshots: [ContextSnapshot] = [],
        returnSummary: ReturnSummary? = nil,
        processedEventIDs: Set<UUID> = []
    ) {
        self.id = id
        self.goal = goal
        self.status = status
        self.presence = presence
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.processes = processes
        self.decisions = decisions
        self.notes = notes
        self.timeline = timeline
        self.snapshots = snapshots
        self.returnSummary = returnSummary
        self.processedEventIDs = processedEventIDs
    }
}
