import Foundation

public extension SessionProjection {
    var hostedSessions: [AnchorSession] {
        ([session].compactMap { $0 } + additionalSessions)
            .filter { $0.status != .completed && $0.status != .archived }
            .sorted { $0.startedAt == $1.startedAt ? $0.id.uuidString < $1.id.uuidString : $0.startedAt < $1.startedAt }
    }

    mutating func selectHostedSession(_ id: UUID) throws {
        if session?.id == id { return }
        guard let index = additionalSessions.firstIndex(where: { $0.id == id }) else {
            throw SessionRepositoryError.noActiveSession
        }
        let target = additionalSessions.remove(at: index)
        if let session { additionalSessions.append(session) }
        session = target
    }
}

public extension AnchorSession {
    var conversationsInJoiningOrder: [AnchorProcess] {
        let order = processJoinOrder ?? processes.map(\.id)
        return taskProcesses.sorted {
            (order.firstIndex(of: $0.id) ?? Int.max) < (order.firstIndex(of: $1.id) ?? Int.max)
        }
    }

    mutating func captureJoiningOrder() {
        var order = processJoinOrder ?? processes.map(\.id)
        for process in processes where !order.contains(process.id) { order.append(process.id) }
        processJoinOrder = order
    }
}

public extension SessionReducer {
    /// Replay mutations against envelope ownership, never whichever task happens to be selected.
    static func reduce(_ projection: SessionProjection, operation: SessionOperation,
                       targetSessionID: UUID, now: Date) throws -> SessionProjection {
        switch operation {
        case .createSession, .hostSession, .selectSession:
            return try reduce(projection, operation: operation, now: now)
        default: break
        }
        guard projection.session?.id != targetSessionID else {
            return try reduce(projection, operation: operation, now: now)
        }
        // Late events cannot resurrect an explicitly ended task.
        if projection.archivedSessions.contains(where: { $0.id == targetSessionID }) { return projection }
        var focused = projection
        let previousID = focused.session?.id
        try focused.selectHostedSession(targetSessionID)
        var result = try reduce(focused, operation: operation, now: now)
        if let previousID {
            try result.selectHostedSession(previousID)
        } else if let updated = result.session {
            result.additionalSessions.append(updated)
            result.session = nil
        }
        return result
    }
}
