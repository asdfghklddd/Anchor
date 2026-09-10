import Foundation

/// Current state for one semantic work item, deterministically derived from
/// immutable run history instead of overwriting historical outcomes.
public struct AnchorWorkItemState: Codable, Equatable, Sendable {
    public let taskID: UUID
    public let workItemID: UUID
    public let execution: AnchorRunExecution
    public let attention: Set<AnchorRunAttention>
    public let outcome: AnchorRunOutcome
    public let generation: Int
    public let runCount: Int
    public let activeRunCount: Int
    public let latestActivityAt: Date?
}

/// Aggregate observation for one semantic task. `outcome` reflects only the
/// latest observed work results; `lifecycle` remains user-controlled.
public struct AnchorTaskState: Codable, Equatable, Sendable {
    public let taskID: UUID
    public let lifecycle: AnchorTaskLifecycle
    public let execution: AnchorRunExecution
    public let attention: Set<AnchorRunAttention>
    public let outcome: AnchorRunOutcome
    public let workItemCount: Int
    public let activeWorkItemCount: Int
    public let runCount: Int
    public let latestActivityAt: Date?
}

public enum AnchorWorkItemStateProjector {
    public static func project(
        workItem: AnchorWorkItem,
        runs: [AnchorRun]
    ) -> AnchorWorkItemState {
        let ordered = runs
            .filter { $0.taskID == workItem.taskID && $0.workItemID == workItem.id }
            .sorted(by: runOrder)
        guard !ordered.isEmpty else {
            return AnchorWorkItemState(
                taskID: workItem.taskID,
                workItemID: workItem.id,
                execution: .idle,
                attention: [],
                outcome: .none,
                generation: workItem.generation,
                runCount: 0,
                activeRunCount: 0,
                latestActivityAt: nil
            )
        }

        var generation = workItem.generation
        var generationEnd: Date?
        var latestGenerationRuns: [AnchorRun] = []
        for run in ordered {
            if let currentGenerationEnd = generationEnd,
               run.startedAt >= currentGenerationEnd {
                generation += 1
                latestGenerationRuns.removeAll(keepingCapacity: true)
                selfUpdateGenerationEnd(&generationEnd, with: run)
            } else {
                selfUpdateGenerationEnd(&generationEnd, with: run)
            }
            latestGenerationRuns.append(run)
        }

        let activeRuns = latestGenerationRuns.filter { $0.outcome == .none }
        let execution = aggregateExecution(activeRuns)
        let outcome: AnchorRunOutcome
        if activeRuns.isEmpty {
            outcome = latestGenerationRuns.max(by: terminalOrder)?.outcome ?? .none
        } else {
            outcome = .none
        }

        var attention = Set(latestGenerationRuns.flatMap(\.attention))
        // A previous failure remains actionable while replacement work is active,
        // but becomes history once the latest generation reaches a terminal result.
        if !activeRuns.isEmpty,
           ordered.contains(where: { $0.outcome == .failed || $0.attention.contains(.hasFailure) }) {
            attention.insert(.hasFailure)
        }
        let latestActivityAt = ordered.compactMap { $0.finishedAt ?? $0.startedAt }.max()
        return AnchorWorkItemState(
            taskID: workItem.taskID,
            workItemID: workItem.id,
            execution: execution,
            attention: attention,
            outcome: outcome,
            generation: generation,
            runCount: ordered.count,
            activeRunCount: activeRuns.count,
            latestActivityAt: latestActivityAt
        )
    }

    private static func selfUpdateGenerationEnd(
        _ generationEnd: inout Date?,
        with run: AnchorRun
    ) {
        let end = run.outcome == .none ? Date.distantFuture : (run.finishedAt ?? run.startedAt)
        generationEnd = max(generationEnd ?? end, end)
    }

    private static func aggregateExecution(_ runs: [AnchorRun]) -> AnchorRunExecution {
        if runs.contains(where: { $0.execution == .running }) { return .running }
        if runs.contains(where: { $0.execution == .waitingBackground }) { return .waitingBackground }
        if runs.contains(where: { $0.execution == .queued }) { return .queued }
        return .idle
    }

    private static func runOrder(_ lhs: AnchorRun, _ rhs: AnchorRun) -> Bool {
        if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func terminalOrder(_ lhs: AnchorRun, _ rhs: AnchorRun) -> Bool {
        let lhsDate = lhs.finishedAt ?? lhs.startedAt
        let rhsDate = rhs.finishedAt ?? rhs.startedAt
        if lhsDate != rhsDate { return lhsDate < rhsDate }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

public enum AnchorTaskStateProjector {
    public static func project(
        task: AnchorTask,
        workItemStates: [AnchorWorkItemState]
    ) -> AnchorTaskState {
        let states = workItemStates.filter { $0.taskID == task.id }
        let activeStates = states.filter { $0.activeRunCount > 0 }
        let execution = aggregateExecution(states.map(\.execution))
        let outcome: AnchorRunOutcome
        if states.isEmpty || states.contains(where: { $0.outcome == .none }) {
            outcome = .none
        } else if states.contains(where: { $0.outcome == .failed }) {
            outcome = .failed
        } else if states.contains(where: { $0.outcome == .interrupted }) {
            outcome = .interrupted
        } else {
            outcome = .completed
        }

        return AnchorTaskState(
            taskID: task.id,
            lifecycle: task.lifecycle,
            execution: execution,
            attention: Set(states.flatMap(\.attention)),
            outcome: outcome,
            workItemCount: states.count,
            activeWorkItemCount: activeStates.count,
            runCount: states.reduce(0) { $0 + $1.runCount },
            latestActivityAt: states.compactMap(\.latestActivityAt).max()
        )
    }

    private static func aggregateExecution(_ executions: [AnchorRunExecution]) -> AnchorRunExecution {
        if executions.contains(.running) { return .running }
        if executions.contains(.waitingBackground) { return .waitingBackground }
        if executions.contains(.queued) { return .queued }
        return .idle
    }
}
