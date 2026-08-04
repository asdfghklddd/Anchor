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
                let note = AnchorNote(text: trimmed, createdAt: now)
                session.notes.insert(note, at: 0)
                let event = ProcessEvent(
                    occurredAt: now,
                    kind: .note,
                    title: trimmed
                )
                session.timeline.insert(event, at: 0)
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
                    processID: processID,
                    occurredAt: now,
                    kind: .decisionResolved,
                    title: session.decisions[index].title
                )
                session.timeline.insert(event, at: 0)
            }

        case let .addProcess(process):
            try result.withSession { $0.processes.append(process) }

        case let .updateProcess(process):
            try result.withSession { session in
                guard let index = session.processes.firstIndex(where: { $0.id == process.id }) else {
                    throw SessionRepositoryError.processNotFound
                }
                session.processes[index] = process
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
                guard !session.processedEventIDs.contains(event.id) else { return }
                session.processedEventIDs.insert(event.id)
                session.timeline.insert(event, at: 0)
                if let processID = event.processID,
                   let index = session.processes.firstIndex(where: { $0.id == processID }) {
                    session.processes[index].events.insert(event, at: 0)
                    session.processes[index].updatedAt = event.occurredAt
                }
            }

        case let .applyEnvelope(envelope, event):
            try result.withSession { session in
                guard envelope.sessionID == session.id else { return }
                guard !session.processedEventIDs.contains(envelope.id) else { return }
                session.processedEventIDs.insert(envelope.id)
                guard !session.processedEventIDs.contains(event.id) else { return }
                session.processedEventIDs.insert(event.id)
                session.timeline.insert(event, at: 0)
                if let processID = event.processID,
                   let index = session.processes.firstIndex(where: { $0.id == processID }) {
                    session.processes[index].events.insert(event, at: 0)
                    session.processes[index].updatedAt = event.occurredAt
                }
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
                        .map {
                            ReturnChange(
                                occurredAt: $0.occurredAt,
                                title: $0.title,
                                detail: $0.detail,
                                kind: $0.kind
                            )
                        }
                    let recommended = session.decisions.first(where: { $0.status == .open })?.processID
                    session.returnSummary = ReturnSummary(
                        awaySince: awaySince,
                        generatedAt: date,
                        changes: changes,
                        recommendedProcessID: recommended
                    )
                }
            }

        case let .updateSignals(connection, proximity, observedAt):
            result.connection = connection
            result.proximity = proximity
            result.dataObservedAt = observedAt

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
}

private extension SessionProjection {
    mutating func withSession(_ operation: (inout AnchorSession) throws -> Void) throws {
        guard var session else { throw SessionRepositoryError.noActiveSession }
        try operation(&session)
        self.session = session
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
