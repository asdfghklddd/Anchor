import Foundation

/// A versioned, deterministic mutation that can be persisted and replayed on
/// another device. UI-facing `SessionCommand` values intentionally remain
/// ergonomic; this operation is the wire and storage representation.
public enum SessionOperation: Codable, Hashable, Sendable {
    case createSession(AnchorSession)
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
    case observeProcess(ProcessObservation)
    case updatePresence(status: PresenceStatus, at: Date, eventID: UUID)
    case acknowledgeReturn(at: Date)
    case completeSession(at: Date)
    case resumeSession(at: Date)

    public var sessionID: UUID? {
        switch self {
        case let .createSession(session): session.id
        case let .addNote(note): note.sessionID
        case let .addProcess(process), let .updateProcess(process): process.sessionID
        case let .recordEvent(event): event.sessionID
        case let .observeProcess(observation): observation.process.sessionID
        default: nil
        }
    }

    public var occurredAt: Date {
        switch self {
        case let .createSession(session): session.startedAt
        case let .updateGoal(_, at): at
        case let .addNote(note): note.createdAt
        case let .resolveDecision(_, _, resolvedAt, _): resolvedAt
        case let .addProcess(process): process.updatedAt
        case let .updateProcess(process): process.updatedAt
        case let .recordEvent(event): event.occurredAt
        case let .observeProcess(observation):
            observation.event?.occurredAt ?? observation.process.updatedAt
        case .removeProcess, .reorderProcesses, .updateTileSize:
            .now
        case let .updatePresence(_, at, _): at
        case let .acknowledgeReturn(at): at
        case let .completeSession(at): at
        case let .resumeSession(at): at
        }
    }

    public var deduplicationKey: String? {
        switch self {
        case let .recordEvent(event): event.deduplicationKey
        case let .observeProcess(observation): observation.deduplicationKey
        default: nil
        }
    }

    /// Resolving a decision is also an optional source-side command. The
    /// operation remains durable even when no adapter supports that command.
    public var sourceAction: SourceAction? {
        switch self {
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
            guard projection.session != nil else {
                throw SessionRepositoryError.noActiveSession
            }
            var process = observation.process
            process.sessionID = projection.session?.id ?? process.sessionID
            var event = observation.event
            if let eventValue = event {
                event = normalizedEvent(
                    eventValue,
                    sessionID: projection.session?.id ?? eventValue.sessionID,
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
