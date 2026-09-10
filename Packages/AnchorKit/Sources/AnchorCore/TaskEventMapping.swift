import Foundation

/// Keeps source events independent from task ownership until association is known.
public struct AnchorEventAssociation: Codable, Hashable, Sendable {
    public let taskID: UUID
    public let workItemID: UUID
    public let confirmedByUser: Bool

    public init(taskID: UUID, workItemID: UUID, confirmedByUser: Bool = false) {
        self.taskID = taskID; self.workItemID = workItemID; self.confirmedByUser = confirmedByUser
    }
}

public struct AnchorSessionAssociation: Identifiable, Codable, Hashable, Sendable {
    public let sessionID: UUID
    public let sourceID: UUID?
    public let target: AnchorEventAssociation
    public let confirmedAt: Date

    public var id: String {
        sessionID.uuidString + "." + (sourceID?.uuidString ?? "legacy")
    }

    public init(
        sessionID: UUID,
        sourceID: UUID,
        target: AnchorEventAssociation,
        confirmedAt: Date = .now
    ) {
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.target = target
        self.confirmedAt = confirmedAt
    }

    private enum CodingKeys: String, CodingKey {
        case sessionID, sourceID, target, confirmedAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try values.decode(UUID.self, forKey: .sessionID)
        sourceID = try values.decodeIfPresent(UUID.self, forKey: .sourceID)
        target = try values.decode(AnchorEventAssociation.self, forKey: .target)
        confirmedAt = try values.decode(Date.self, forKey: .confirmedAt)
    }
}

public extension ExternalProcessEvent {
    func makeTaskEvent(
        association: AnchorEventAssociation,
        receivedAt: Date = .now
    ) -> AnchorTaskEvent {
        AnchorTaskEvent(
            id: id,
            taskID: association.taskID,
            workItemID: association.workItemID,
            runID: runID(association: association),
            sourceID: sourceID.uuidString,
            sourceSessionID: process.externalID,
            sourceSequence: sequence,
            occurredAt: occurredAt,
            receivedAt: receivedAt,
            kind: taskEventKind
        )
    }

    /// Projects an observed process into a run without inferring ownership.
    func makeRun(association: AnchorEventAssociation, now: Date = .now) -> AnchorRun {
        let execution: AnchorRunExecution
        let attention: Set<AnchorRunAttention>
        let outcome: AnchorRunOutcome
        switch process.status {
        case .queued:
            execution = .queued; attention = []; outcome = .none
        case .running:
            execution = .running; attention = []; outcome = .none
        case .needsDecision, .blocked:
            execution = .waitingBackground; attention = [.needsInput]; outcome = .none
        case .completed:
            execution = .idle; attention = []; outcome = .completed
        case .failed:
            execution = .idle
            attention = []
            outcome = observedOutcome == .interrupted ? .interrupted : .failed
        case .disconnected:
            execution = .idle; attention = [.stale]; outcome = .none
        }
        return AnchorRun(id: runID(association: association), taskID: association.taskID, workItemID: association.workItemID,
                         sourceID: sourceID.uuidString, sourceSessionID: process.externalID,
                         execution: execution, attention: attention, outcome: outcome,
                         startedAt: process.updatedAt,
                         finishedAt: outcome == .none ? nil : occurredAt)
    }

    private func runID(association: AnchorEventAssociation) -> UUID {
        StableProcessIdentity.id(
            namespace: "task.run." + sourceID.uuidString + "." + association.workItemID.uuidString,
            sessionID: association.taskID,
            externalID: process.id.uuidString
        )
    }

    private var taskEventKind: AnchorTaskEventKind {
        switch process.status {
        case .queued: .queued
        case .running: event?.kind == .progress ? .progress : .started
        case .needsDecision, .blocked: .needsInput
        case .completed: .completed
        case .failed: observedOutcome == .interrupted ? .interrupted : .failed
        case .disconnected: .stale
        }
    }
}
