import Foundation

/// Migration identifiers for retired recording builds. Contains no seed content.
/// Exact identities avoid treating user-authored titles as synthetic data.
enum RetiredRecordingCleanup {
    static let sessionIDs: Set<UUID> = Set((1...3).compactMap {
        UUID(uuidString: "AA202609-2900-4000-8000-00000000000\($0)")
    })

    static func isRecordingProcess(_ process: AnchorProcess) -> Bool {
        process.sourceID == nil && process.sourceName == "演示工作计划"
    }

    static func clean(_ projection: SessionProjection) -> SessionProjection {
        var result = projection
        result.session = projection.session.flatMap(clean)
        result.additionalSessions = projection.additionalSessions.compactMap(clean)
        result.archivedSessions = projection.archivedSessions.compactMap(clean)
        if result.session == nil, !result.additionalSessions.isEmpty {
            result.session = result.additionalSessions.removeFirst()
        }
        return result
    }

    static func clean(_ session: AnchorSession) -> AnchorSession? {
        guard !sessionIDs.contains(session.id) else { return nil }
        let ids = Set((session.processes + session.snapshots.flatMap(\.processes))
            .filter(isRecordingProcess).map(\.id))
        guard !ids.isEmpty else { return session }
        var result = session
        result.processes.removeAll { ids.contains($0.id) }
        result.processJoinOrder?.removeAll { ids.contains($0) }
        result.decisions.removeAll { ids.contains($0.processID) }
        result.timeline.removeAll { $0.processID.map(ids.contains) ?? false }
        result.snapshots = session.snapshots.map { snapshot in
            ContextSnapshot(id: snapshot.id, createdAt: snapshot.createdAt,
                goalTitle: snapshot.goalTitle,
                processes: snapshot.processes.filter { !ids.contains($0.id) },
                openDecisionIDs: snapshot.openDecisionIDs.filter { id in
                    !session.decisions.contains { $0.id == id && ids.contains($0.processID) }
                }, latestNote: snapshot.latestNote)
        }
        // A previously generated summary can contain prose derived from removed processes.
        result.returnSummary = nil
        if result.presence == .returning { result.presence = .unknown }
        return result
    }

    static func filteredEvents(_ events: [EventEnvelope]) -> [EventEnvelope] {
        var processIDs = Set<UUID>()
        var decisionIDs = Set<UUID>()
        var recordingTimes: [UUID: [Date]] = [:]
        for envelope in events {
            guard let operation = try? JSONDecoder.anchor.decode(SessionOperation.self, from: envelope.payload),
                  case let .observeProcess(observation) = unscoped(operation),
                  isRecordingProcess(observation.process) else { continue }
            processIDs.insert(observation.process.id)
            if let decision = observation.decision { decisionIDs.insert(decision.id) }
            recordingTimes[envelope.sessionID, default: []].append(observation.process.updatedAt)
        }
        return events.filter { envelope in
            guard !sessionIDs.contains(envelope.sessionID) else { return false }
            guard let operation = try? JSONDecoder.anchor.decode(SessionOperation.self, from: envelope.payload) else {
                return true // Keep undecodable history for recovery.
            }
            switch unscoped(operation) {
            case let .observeProcess(observation):
                return !processIDs.contains(observation.process.id)
            case let .addProcess(process), let .updateProcess(process):
                return !processIDs.contains(process.id) && !isRecordingProcess(process)
            case let .removeProcess(id), let .updateTileSize(id, _):
                return !processIDs.contains(id)
            case let .recordEvent(event):
                return !(event.processID.map(processIDs.contains) ?? false)
            case let .resolveDecision(id, _, _, _):
                return !decisionIDs.contains(id)
            case let .updatePresence(_, at, _, _):
                // The retired recorder wrote presence at t and t+3ms, and observations
                // at t+1ms/t+2ms. Do not remove ordinary presence events at other times.
                return !(recordingTimes[envelope.sessionID] ?? []).contains {
                    abs($0.timeIntervalSince(at)) <= 0.0021
                }
            default: return true
            }
        }
    }

    static func unscoped(_ operation: SessionOperation) -> SessionOperation {
        if case let .scoped(_, nested) = operation { return unscoped(nested) }
        return operation
    }
}
