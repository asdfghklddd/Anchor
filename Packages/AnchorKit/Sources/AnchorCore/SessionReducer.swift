import Foundation

public enum SessionReducer {
    public static func reduce(
        _ projection: SessionProjection,
        command: SessionCommand,
        now: Date = .now
    ) throws -> SessionProjection {
        var result = projection
        result.generatedAt = now

        switch command {
        case let .createSession(goal, processes):
            // A duplicate create can arrive after a retry. The command does
            // not carry the generated session ID, so an existing workspace is
            // left intact; the event-backed repository performs the stronger
            // envelope-level identity check for replicated creates.
            guard result.session == nil else { return result }
            result.session = AnchorSession(
                goal: goal,
                status: .active,
                presence: .atDesk,
                startedAt: now,
                processes: processes
            )
            result.dataObservedAt = now
            result.errorMessage = nil

        case let .updateGoal(title, completionCriteria, note):
            try result.withSession { session in
                session.goal.title = title
                session.goal.completionCriteria = completionCriteria
                session.goal.note = note
            }

        case let .addNote(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return result }
            try result.withSession { session in
                let note = AnchorNote(
                    sessionID: session.id,
                    origin: "session",
                    text: trimmed,
                    createdAt: now
                )
                session.notes.insert(note, at: 0)
                let event = ProcessEvent(
                    id: note.id,
                    sessionID: session.id,
                    occurredAt: now,
                    kind: .note,
                    title: trimmed
                )
                append(event, to: &session)
            }

        case let .resolveDecision(decisionID, optionID):
            try result.withSession { session in
                guard let index = session.decisions.firstIndex(where: { $0.id == decisionID }) else {
                    throw SessionRepositoryError.decisionNotFound
                }
                guard session.decisions[index].options.contains(where: { $0.id == optionID }) else {
                    throw SessionRepositoryError.invalidDecisionOption
                }
                guard session.decisions[index].status == .open else { return }
                session.decisions[index].status = .resolved
                session.decisions[index].selectedOptionID = optionID
                session.decisions[index].resolvedAt = now
                let processID = session.decisions[index].processID
                if let processIndex = session.processes.firstIndex(where: { $0.id == processID }) {
                    session.processes[processIndex].status = .running
                    session.processes[processIndex].updatedAt = now
                }
                let event = ProcessEvent(
                    id: UUID(),
                    sessionID: session.id,
                    processID: processID,
                    occurredAt: now,
                    kind: .decisionResolved,
                    title: session.decisions[index].title
                )
                append(event, to: &session)
            }

        case let .addProcess(process):
            try result.withSession { session in
                var normalized = process
                normalized.sessionID = session.id
                session.processes.append(normalized)
            }

        case let .updateProcess(process):
            try result.withSession { session in
                guard let index = session.processes.firstIndex(where: { $0.id == process.id }) else {
                    throw SessionRepositoryError.processNotFound
                }
                guard process.updatedAt >= session.processes[index].updatedAt else { return }
                var normalized = process
                normalized.sessionID = session.id
                session.processes[index] = normalized
            }

        case let .removeProcess(id):
            try result.withSession { session in
                session.processes.removeAll { $0.id == id }
                session.decisions.removeAll { $0.processID == id }
            }

        case let .reorderProcesses(ids):
            try result.withSession { session in
                let lookup = Dictionary(uniqueKeysWithValues: session.processes.map { ($0.id, $0) })
                let ordered = ids.compactMap { lookup[$0] }
                let remaining = session.processes.filter { !ids.contains($0.id) }
                session.processes = ordered + remaining
            }

        case let .updateTileSize(processID, size):
            try result.withSession { session in
                guard let index = session.processes.firstIndex(where: { $0.id == processID }) else {
                    throw SessionRepositoryError.processNotFound
                }
                session.processes[index].tileSize = size
            }

        case let .recordEvent(event):
            try result.withSession { session in
                append(event, to: &session)
            }

        case let .observeProcess(observation):
            return try reduce(
                result,
                operation: .observeProcess(observation),
                now: now
            )

        case let .applyEnvelope(envelope, event):
            try result.withSession { session in
                guard envelope.sessionID == session.id else { return }
                guard !session.processedEventIDs.contains(envelope.id) else { return }
                session.processedEventIDs.insert(envelope.id)
                append(event, to: &session)
            }

        case let .mergeRemoteSession(envelope, remoteSession):
            guard envelope.sessionID == remoteSession.id else { return result }
            if result.session?.processedEventIDs.contains(envelope.id) == true {
                return result
            }
            var merged = remoteSession
            merged.processedEventIDs.formUnion(result.session?.processedEventIDs ?? [])
            merged.processedEventIDs.insert(envelope.id)
            result.session = merged
            result.dataObservedAt = envelope.timestamp

        case let .updatePresence(presence, date):
            try result.withSession { session in
                let previous = session.presence
                session.presence = presence
                if presence == .away, previous != .away {
                    session.snapshots.insert(session.makeSnapshot(at: date), at: 0)
                }
                if presence == .returning, previous != .returning {
                    let awaySince = session.snapshots.first?.createdAt ?? date
                    let changes = session.timeline
                        .filter { $0.occurredAt >= awaySince }
                        .filter { $0.occurredAt <= date }
                        .filter { $0.kind != .presence && $0.kind != .connection }
                        .sorted { lhs, rhs in
                            if lhs.occurredAt != rhs.occurredAt {
                                return lhs.occurredAt > rhs.occurredAt
                            }
                            return lhs.id.uuidString > rhs.id.uuidString
                        }
                        .map {
                            ReturnChange(
                                occurredAt: $0.occurredAt,
                                title: $0.title,
                                detail: $0.detail,
                                kind: $0.kind
                            )
                        }
                    let openDecisions = session.decisions
                        .filter { $0.status == .open }
                        .sorted { lhs, rhs in
                            let lhsPriority = lhs.priority ?? 0
                            let rhsPriority = rhs.priority ?? 0
                            if lhsPriority != rhsPriority {
                                return lhsPriority > rhsPriority
                            }
                            if lhs.requestedAt != rhs.requestedAt {
                                return lhs.requestedAt < rhs.requestedAt
                            }
                            return lhs.id.uuidString < rhs.id.uuidString
                        }
                    let recommended = openDecisions.first?.processID
                    let completedCount = changes.filter {
                        $0.kind == .completed || $0.kind == .outputReady
                    }.count
                    let failedCount = changes.filter { $0.kind == .failed }.count
                    let newDecisionCount = changes.filter { $0.kind == .decisionRequired }.count
                    let impact = min(
                        100,
                        max(
                            0,
                            completedCount * 25
                                + newDecisionCount * 15
                                + changes.filter { $0.kind == .progress }.count * 5
                                - failedCount * 20
                        )
                    )
                    session.returnSummary = ReturnSummary(
                        awaySince: awaySince,
                        generatedAt: date,
                        changes: changes,
                        recommendedProcessID: recommended,
                        elapsedSeconds: max(0, date.timeIntervalSince(awaySince)),
                        completedCount: completedCount,
                        failedCount: failedCount,
                        newDecisionCount: newDecisionCount,
                        netChangeScore: impact
                    )
                }
                if previous != presence {
                    append(
                        ProcessEvent(
                            sessionID: session.id,
                            occurredAt: date,
                            kind: .presence,
                            title: "Presence: \(presence.rawValue)"
                        ),
                        to: &session
                    )
                }
            }

        case let .updateSignals(connection, proximity, _):
            result.connection = connection
            result.proximity = proximity
            // Presence and connection signals describe transport health, not
            // the age of the work data. Keep the last remote data timestamp
            // intact so stale projections remain visible to the UI.

        case let .updateSourceHealth(health):
            result.sourceHealth = Dictionary(uniqueKeysWithValues: health.map { ($0.id, $0) })

        case let .updateDurableSyncState(state):
            result.durableSyncState = state

        case .acknowledgeReturn:
            try result.withSession { session in
                session.presence = .atDesk
                session.returnSummary = nil
            }

        case .completeSession:
            try result.withSession { session in
                session.status = .completed
                session.completedAt = now
                session.snapshots.insert(session.makeSnapshot(at: now), at: 0)
            }

        case .resumeSession:
            try result.withSession { session in
                session.status = .active
                session.completedAt = nil
            }

        case .clearError:
            result.errorMessage = nil
        }

        return result
    }

    public static func reduce(
        _ projection: SessionProjection,
        operation: SessionOperation,
        now: Date? = nil
    ) throws -> SessionProjection {
        var result = projection
        let operationDate = now ?? operation.occurredAt
        result.generatedAt = operationDate

        switch operation {
        case let .createSession(session):
            if let existing = result.session, existing.id != session.id {
                return result
            }
            result.session = session
            result.dataObservedAt = operationDate
            result.errorMessage = nil

        case let .updateGoal(goal, _):
            try result.withSession { $0.goal = goal }

        case let .addNote(note):
            try result.withSession { session in
                guard !session.notes.contains(where: { $0.id == note.id }) else { return }
                var normalizedNote = note
                if normalizedNote.sessionID == nil {
                    normalizedNote = AnchorNote(
                        id: note.id,
                        sessionID: session.id,
                        processID: note.processID,
                        decisionID: note.decisionID,
                        origin: note.origin,
                        text: note.text,
                        createdAt: note.createdAt
                    )
                }
                session.notes.insert(normalizedNote, at: 0)
                append(
                    ProcessEvent(
                        id: note.id,
                        sessionID: session.id,
                        occurredAt: note.createdAt,
                        kind: .note,
                        title: note.text
                    ),
                    to: &session
                )
            }

        case let .resolveDecision(decisionID, optionID, resolvedAt, eventID):
            try result.withSession { session in
                guard let index = session.decisions.firstIndex(where: { $0.id == decisionID }) else {
                    throw SessionRepositoryError.decisionNotFound
                }
                guard session.decisions[index].options.contains(where: { $0.id == optionID }) else {
                    throw SessionRepositoryError.invalidDecisionOption
                }
                guard session.decisions[index].status == .open else { return }

                session.decisions[index].status = .resolved
                session.decisions[index].selectedOptionID = optionID
                session.decisions[index].resolvedAt = resolvedAt
                let processID = session.decisions[index].processID
                if let processIndex = session.processes.firstIndex(where: { $0.id == processID }) {
                    session.processes[processIndex].status = .running
                    session.processes[processIndex].updatedAt = resolvedAt
                }
                append(
                    ProcessEvent(
                        id: eventID,
                        sessionID: session.id,
                        processID: processID,
                        occurredAt: resolvedAt,
                        kind: .decisionResolved,
                        title: session.decisions[index].title
                    ),
                    to: &session
                )
            }

        case let .addProcess(process):
            try result.withSession { session in
                guard !session.processes.contains(where: { $0.id == process.id }) else { return }
                var normalized = process
                normalized.sessionID = session.id
                session.processes.append(normalized)
            }

        case let .updateProcess(process):
            try result.withSession { session in
                guard let index = session.processes.firstIndex(where: { $0.id == process.id }) else {
                    throw SessionRepositoryError.processNotFound
                }
                var normalized = process
                normalized.sessionID = session.id
                // A delayed source snapshot must not roll process state back.
                guard normalized.updatedAt >= session.processes[index].updatedAt else { return }
                session.processes[index] = normalized
            }

        case let .removeProcess(id):
            try result.withSession { session in
                session.processes.removeAll { $0.id == id }
                session.decisions.removeAll { $0.processID == id }
            }

        case let .reorderProcesses(ids):
            try result.withSession { session in
                let lookup = Dictionary(uniqueKeysWithValues: session.processes.map { ($0.id, $0) })
                let requestedIDs = Set(ids)
                let ordered = ids.compactMap { lookup[$0] }
                let remaining = session.processes.filter { !requestedIDs.contains($0.id) }
                session.processes = ordered + remaining
            }

        case let .updateTileSize(processID, size):
            try result.withSession { session in
                guard let index = session.processes.firstIndex(where: { $0.id == processID }) else {
                    throw SessionRepositoryError.processNotFound
                }
                session.processes[index].tileSize = size
            }

        case let .recordEvent(event):
            try result.withSession { session in
                append(event, to: &session)
            }

        case let .observeProcess(observation):
            try result.withSession { session in
                if let index = session.processes.firstIndex(where: { $0.id == observation.process.id }) {
                    let existing = session.processes[index]
                    var process = observation.process
                    if process.updatedAt < existing.updatedAt {
                        process = existing
                    } else {
                        process.sessionID = session.id
                    }
                    var events = existing.events
                    for event in observation.process.events where !events.contains(where: { $0.id == event.id }) {
                        events.append(event)
                    }
                    process.events = events.sorted { $0.occurredAt > $1.occurredAt }
                    session.processes[index] = process
                } else {
                    var process = observation.process
                    process.sessionID = session.id
                    session.processes.append(process)
                }

                if let decision = observation.decision {
                    if let index = session.decisions.firstIndex(where: { $0.id == decision.id }) {
                        let existing = session.decisions[index]
                        // Resolution is first-valid-resolution-wins. A delayed
                        // open snapshot cannot reopen a resolved decision.
                        if existing.status == .open || decision.status != .open {
                            session.decisions[index] = decision
                        }
                    } else {
                        session.decisions.append(decision)
                    }
                }
                if let event = observation.event {
                    append(event, to: &session)
                }
            }

        case let .updatePresence(status, at, _):
            try result.withSession { session in
                let previous = session.presence
                session.presence = status
                if status == .away, previous != .away {
                    session.snapshots.insert(session.makeSnapshot(at: at), at: 0)
                }
                if status == .returning, previous != .returning {
                    let awaySince = session.snapshots.first?.createdAt ?? at
                    let changes = session.timeline
                        .filter { $0.occurredAt >= awaySince }
                        .filter { $0.occurredAt <= at }
                        .filter { $0.kind != .presence && $0.kind != .connection }
                        .sorted { lhs, rhs in
                            if lhs.occurredAt != rhs.occurredAt {
                                return lhs.occurredAt > rhs.occurredAt
                            }
                            return lhs.id.uuidString > rhs.id.uuidString
                        }
                        .map {
                            ReturnChange(
                                occurredAt: $0.occurredAt,
                                title: $0.title,
                                detail: $0.detail,
                                kind: $0.kind
                            )
                        }
                    let recommended = session.decisions
                        .filter { $0.status == .open }
                        .sorted { lhs, rhs in
                            let lhsPriority = lhs.priority ?? 0
                            let rhsPriority = rhs.priority ?? 0
                            if lhsPriority != rhsPriority {
                                return lhsPriority > rhsPriority
                            }
                            if lhs.requestedAt != rhs.requestedAt {
                                return lhs.requestedAt < rhs.requestedAt
                            }
                            return lhs.id.uuidString < rhs.id.uuidString
                        }
                        .first?.processID
                    let completedCount = changes.filter {
                        $0.kind == .completed || $0.kind == .outputReady
                    }.count
                    let failedCount = changes.filter { $0.kind == .failed }.count
                    let newDecisionCount = changes.filter { $0.kind == .decisionRequired }.count
                    let impact = min(
                        100,
                        max(
                            0,
                            completedCount * 25
                                + newDecisionCount * 15
                                + changes.filter { $0.kind == .progress }.count * 5
                                - failedCount * 20
                        )
                    )
                    session.returnSummary = ReturnSummary(
                        awaySince: awaySince,
                        generatedAt: at,
                        changes: changes,
                        recommendedProcessID: recommended,
                        elapsedSeconds: max(0, at.timeIntervalSince(awaySince)),
                        completedCount: completedCount,
                        failedCount: failedCount,
                        newDecisionCount: newDecisionCount,
                        netChangeScore: impact
                    )
                }
                if previous != status {
                    append(
                        ProcessEvent(
                            sessionID: session.id,
                            occurredAt: at,
                            kind: .presence,
                            title: "Presence: \(status.rawValue)"
                        ),
                        to: &session
                    )
                }
            }

        case .acknowledgeReturn:
            try result.withSession { session in
                session.presence = .atDesk
                session.returnSummary = nil
            }

        case let .completeSession(at):
            try result.withSession { session in
                session.status = .completed
                session.completedAt = at
                session.snapshots.insert(session.makeSnapshot(at: at), at: 0)
            }

        case .resumeSession:
            try result.withSession { session in
                session.status = .active
                session.completedAt = nil
            }
        }

        return result
    }
}

private extension SessionProjection {
    mutating func withSession(_ operation: (inout AnchorSession) throws -> Void) throws {
        guard var session else { throw SessionRepositoryError.noActiveSession }
        try operation(&session)
        self.session = session
    }
}

private extension SessionReducer {
    static func append(_ event: ProcessEvent, to session: inout AnchorSession) {
        guard !session.processedEventIDs.contains(event.id) else { return }
        guard !session.timeline.contains(where: { $0.id == event.id }) else {
            session.processedEventIDs.insert(event.id)
            return
        }
        if let deduplicationKey = event.deduplicationKey,
           session.timeline.contains(where: {
               $0.sourceID == event.sourceID && $0.deduplicationKey == deduplicationKey
           }) {
            return
        }
        session.processedEventIDs.insert(event.id)
        session.timeline.append(event)
        session.timeline.sort { lhs, rhs in
            if lhs.occurredAt != rhs.occurredAt {
                return lhs.occurredAt > rhs.occurredAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
        if let processID = event.processID,
           let index = session.processes.firstIndex(where: { $0.id == processID }) {
            guard !session.processes[index].events.contains(where: { $0.id == event.id }) else {
                return
            }
            session.processes[index].events.append(event)
            session.processes[index].events.sort { lhs, rhs in
                if lhs.occurredAt != rhs.occurredAt {
                    return lhs.occurredAt > rhs.occurredAt
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }
            session.processes[index].updatedAt = max(
                session.processes[index].updatedAt,
                event.occurredAt
            )
        }
    }
}

private extension AnchorSession {
    func makeSnapshot(at date: Date) -> ContextSnapshot {
        ContextSnapshot(
            createdAt: date,
            goalTitle: goal.title,
            processes: processes,
            openDecisionIDs: decisions.filter { $0.status == .open }.map(\.id),
            latestNote: notes.first?.text
        )
    }
}
