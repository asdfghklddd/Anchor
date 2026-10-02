import AnchorCore
import Foundation

/// Derived from the live task projection; no sample content or inferred progress.
struct ReturnReviewContent {
    let session: AnchorSession?
    let changes: [ReturnChange]
    let processes: [AnchorProcess]

    init(projection: SessionProjection) {
        session = TaskDashboardPolicy.presentation(of: projection).session
        changes = session?.returnSummary?.changes ?? []
        processes = session?.taskProcesses ?? []
    }

    var runningCount: Int { processes.filter { $0.status == .running }.count }
    var completedCount: Int { processes.filter { $0.status == .completed }.count }
    var failedCount: Int { processes.filter { $0.status == .failed && !$0.isInterrupted }.count }
    var attentionCount: Int {
        processes.filter { $0.isInterrupted || [.blocked, .needsDecision, .disconnected].contains($0.status) }.count
    }
    var queuedCount: Int { processes.filter { $0.status == .queued }.count }
    var allCompleted: Bool { !processes.isEmpty && completedCount == processes.count }

    var anchorNote: AnchorNote? {
        guard let session, let start = session.returnSummary?.awaySince else { return nil }
        return session.notes.filter { $0.createdAt <= start }
            .max { $0.createdAt < $1.createdAt }
    }

    var context: String? {
        let text = anchorNote?.text ?? session?.goal.note ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    var elapsedSeconds: TimeInterval? {
        guard let summary = session?.returnSummary else { return nil }
        return max(0, summary.generatedAt.timeIntervalSince(summary.awaySince))
    }

    /// A deterministic review order, not a decision or action on the source app.
    var nextProcess: AnchorProcess? {
        processes.filter { $0.status != .completed }.sorted {
            let lhs = Self.priority($0), rhs = Self.priority($1)
            if lhs != rhs { return lhs < rhs }
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }.first
    }

    func process(for change: ReturnChange) -> AnchorProcess? {
        guard let event = session?.timeline.first(where: { $0.id == change.id }) else { return nil }
        return processes.first { $0.id == event.processID }
    }

    private static func priority(_ process: AnchorProcess) -> Int {
        if process.status == .failed && !process.isInterrupted { return 0 }
        if process.isInterrupted || [.blocked, .needsDecision, .disconnected].contains(process.status) { return 1 }
        return process.status == .running ? 2 : 3
    }
}
