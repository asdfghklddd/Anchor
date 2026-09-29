import Foundation

/// A versioned, deterministic mutation that can be persisted and replayed on
/// another device. UI-facing `SessionCommand` values intentionally remain
/// ergonomic; this operation is the wire and storage representation.
public enum SessionOperation: Codable, Hashable, Sendable {
    // Schema 3 adds concurrent hosting and task selection; older peers reject these operations safely.
    static let latestEnvelopeSchemaVersion = 3

    case createSession(AnchorSession)
    indirect case scoped(sessionID: UUID, operation: SessionOperation)
    case hostSession(AnchorSession)
    case selectSession(UUID, at: Date)
    case updateGoal(AnchorGoal, at: Date)
    case addNote(AnchorNote)
    case resolveDecision(
        decisionID: UUID,
        optionID: UUID,
        resolvedAt: Date,
        eventID: UUID
    )
    case addProcess(AnchorProcess)
    case updateProcess(AnchorProcess)
    case removeProcess(UUID)
    case reorderProcesses([UUID])
    case updateTileSize(processID: UUID, size: ProcessTileSize)
    case recordEvent(ProcessEvent)
    // Decode the retired task projection event without discarding immutable history.
    case syncTaskStructure(task: AnchorTask, workItems: [AnchorWorkItem], at: Date)
    case observeProcess(ProcessObservation)
    case updatePresence(status: PresenceStatus, at: Date, eventID: UUID)
    case acknowledgeReturn(at: Date)
    case completeSession(at: Date)
    case archiveSession(at: Date)
    case resumeSession(at: Date)

    public var sessionID: UUID? {
        switch self {
        case let .scoped(id, _): id
        case let .createSession(session), let .hostSession(session): session.id
        case let .selectSession(id, _): id
        case let .addNote(note): note.sessionID
        case let .addProcess(process), let .updateProcess(process): process.sessionID
        case let .syncTaskStructure(task, _, _): task.id
        case let .recordEvent(event): event.sessionID
        case let .observeProcess(observation): observation.process.sessionID
        default: nil
        }
    }

    public var occurredAt: Date {
        switch self {
        case let .scoped(_, operation): operation.occurredAt
        case let .createSession(session), let .hostSession(session): session.startedAt
        case let .selectSession(_, at): at
        case let .updateGoal(_, at): at
        case let .addNote(note): note.createdAt
        case let .resolveDecision(_, _, resolvedAt, _): resolvedAt
        case let .addProcess(process): process.updatedAt
        case let .updateProcess(process): process.updatedAt
        case let .syncTaskStructure(_, _, at): at
        case let .recordEvent(event): event.occurredAt
        case let .observeProcess(observation):
            observation.event?.occurredAt ?? observation.process.updatedAt
        case .removeProcess, .reorderProcesses, .updateTileSize:
            .now
        case let .updatePresence(_, at, _): at
        case let .acknowledgeReturn(at): at
        case let .completeSession(at): at
        case let .archiveSession(at): at
        case let .resumeSession(at): at
        }
    }

    var envelopeSchemaVersion: Int {
        if case .scoped = self { return 3 }
        if case .hostSession = self { return 3 }
        if case .selectSession = self { return 3 }
        if case .archiveSession = self { return 2 }
        return 1
    }

    public var deduplicationKey: String? {
        switch self {
        case let .scoped(_, operation): operation.deduplicationKey
        case let .recordEvent(event): event.deduplicationKey
        case let .observeProcess(observation): observation.deduplicationKey
        default: nil
        }
    }

    /// Resolving a decision is also an optional source-side command. The
    /// operation remains durable even when no adapter supports that command.
    public var sourceAction: SourceAction? {
        switch self {
        case let .scoped(_, operation): operation.sourceAction
        case let .resolveDecision(decisionID, optionID, _, _):
            .resolveDecision(decisionID: decisionID, optionID: optionID)
        default:
            nil
        }
    }

    /// Converts a user command into an operation with all generated IDs and
    /// timestamps fixed before it is persisted or sent.
    public static func make(
        from command: SessionCommand,
        projection: SessionProjection,
        now: Date = .now
    ) throws -> SessionOperation? {
        switch command {
        case let .forSession(id, command):
            var context = projection
            try context.selectHostedSession(id)
            guard let operation = try make(from: command, projection: context, now: now) else {
                throw SessionRepositoryError.malformedEvent
            }
            return .scoped(sessionID: id, operation: operation)
        case let .hostSession(session): return .hostSession(session)
        case let .selectSession(id):
            guard projection.hostedSessions.contains(where: { $0.id == id }) else { throw SessionRepositoryError.noActiveSession }
            return .selectSession(id, at: now)
        case let .createSession(goal, processes):
            let sessionID = UUID()
            let normalizedProcesses = processes.map { process in
                var normalized = process
                normalized.sessionID = sessionID
                return normalized
            }
            return .createSession(AnchorSession(
                id: sessionID,
                goal: goal,
                status: .active,
                presence: .atDesk,
                startedAt: now,
                processes: normalizedProcesses
            ))

        case let .updateGoal(title, completionCriteria, note):
            guard let session = projection.session else {
                throw SessionRepositoryError.noActiveSession
            }
            return .updateGoal(
                AnchorGoal(
                    id: session.goal.id,
                    title: title,
                    completionCriteria: completionCriteria,
                    note: note,
                    userPlan: session.goal.userPlan,
                    createdAt: session.goal.createdAt
                ),
                at: now
            )

        case let .addNote(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return .addNote(AnchorNote(
                sessionID: projection.session?.id,
                origin: "session",
                text: trimmed,
                createdAt: now
            ))

        case let .resolveDecision(decisionID, optionID):
            return .resolveDecision(
                decisionID: decisionID,
                optionID: optionID,
                resolvedAt: now,
                eventID: UUID()
            )

        case let .addProcess(process):
            var normalized = process
            normalized.sessionID = projection.session?.id
            normalized.updatedAt = now
            return .addProcess(normalized)
        case let .updateProcess(process):
            var normalized = process
            normalized.sessionID = projection.session?.id
            normalized.updatedAt = now
            return .updateProcess(normalized)
        case let .removeProcess(id):
            return .removeProcess(id)
        case let .reorderProcesses(ids):
            return .reorderProcesses(ids)
        case let .updateTileSize(processID, size):
            return .updateTileSize(processID: processID, size: size)
        case let .recordEvent(event):
            guard projection.session != nil else {
                throw SessionRepositoryError.noActiveSession
            }
            return .recordEvent(
                normalizedEvent(event, sessionID: projection.session?.id, receivedAt: now)
            )
        case let .observeProcess(observation):
            guard !projection.hostedSessions.isEmpty else {
                throw SessionRepositoryError.noActiveSession
            }
            if let id = observation.process.sessionID,
               !projection.hostedSessions.contains(where: { $0.id == id }) {
                throw SessionRepositoryError.eventSessionMismatch
            }
            var process = observation.process
            process.sessionID = process.sessionID ?? projection.session?.id
            var event = observation.event
            if let eventValue = event {
                event = normalizedEvent(
                    eventValue,
                    sessionID: process.sessionID ?? eventValue.sessionID,
                    receivedAt: now
                )
            }
            return .observeProcess(ProcessObservation(
                process: process,
                event: event,
                decision: observation.decision,
                deduplicationKey: observation.deduplicationKey
            ))
        case let .updatePresence(status, at):
            return .updatePresence(status: status, at: at, eventID: UUID())
        case .acknowledgeReturn:
            return .acknowledgeReturn(at: now)
        case .completeSession:
            return .completeSession(at: now)
        case .archiveSession:
            return .archiveSession(at: now)
        case .resumeSession:
            return .resumeSession(at: now)
        case .updateSignals, .updateSourceHealth, .updateDurableSyncState,
             .applyEnvelope, .mergeRemoteSession, .clearError:
            return nil
        }
    }

    private static func normalizedEvent(
        _ event: ProcessEvent,
        sessionID: UUID?,
        receivedAt: Date
    ) -> ProcessEvent {
        ProcessEvent(
            id: event.id,
            sessionID: sessionID,
            processID: event.processID,
            sourceID: event.sourceID,
            externalID: event.externalID,
            deduplicationKey: event.deduplicationKey,
            occurredAt: event.occurredAt,
            receivedAt: event.receivedAt ?? receivedAt,
            kind: event.kind,
            title: event.title,
            detail: event.detail,
            progress: event.progress,
            metric: event.metric,
            metricLabel: event.metricLabel,
            deepLink: event.deepLink
        )
    }
}

public struct ProcessObservation: Codable, Hashable, Sendable {
    public let process: AnchorProcess
    public let event: ProcessEvent?
    public let decision: Decision?
    public let deduplicationKey: String?

    public init(
        process: AnchorProcess,
        event: ProcessEvent? = nil,
        decision: Decision? = nil,
        deduplicationKey: String? = nil
    ) {
        self.process = process
        self.event = event
        self.decision = decision
        self.deduplicationKey = deduplicationKey
    }
}
