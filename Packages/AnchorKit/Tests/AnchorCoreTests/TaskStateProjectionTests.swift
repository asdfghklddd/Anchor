import Foundation
import Testing
@testable import AnchorCore

@Suite("Task state projection")
struct TaskStateProjectionTests {
    @Test("A retry reactivates the work item while preserving prior failure attention")
    func retryAfterFailure() {
        let taskID = UUID()
        let item = AnchorWorkItem(taskID: taskID, title: "Implement observer", generation: 3)
        let failed = run(
            item: item,
            execution: .idle,
            outcome: .failed,
            startedAt: 10,
            finishedAt: 20
        )
        let retry = run(item: item, execution: .running, startedAt: 30)

        let state = AnchorWorkItemStateProjector.project(workItem: item, runs: [retry, failed])
        #expect(state.execution == .running)
        #expect(state.outcome == .none)
        #expect(state.attention == [.hasFailure])
        #expect(state.generation == 4)
        #expect(state.runCount == 2)
        #expect(state.activeRunCount == 1)
    }

    @Test("A successful retry keeps failure in history but clears it from current attention")
    func successfulRetryClearsFailureAttention() {
        let item = AnchorWorkItem(taskID: UUID(), title: "Recover observer")
        let failed = run(
            item: item,
            execution: .idle,
            outcome: .failed,
            startedAt: 10,
            finishedAt: 20
        )
        let recovered = run(
            item: item,
            execution: .idle,
            outcome: .completed,
            startedAt: 30,
            finishedAt: 40
        )

        let state = AnchorWorkItemStateProjector.project(workItem: item, runs: [failed, recovered])
        #expect(state.execution == .idle)
        #expect(state.outcome == .completed)
        #expect(state.attention.isEmpty)
        #expect(state.generation == 1)
        #expect(state.runCount == 2)
    }

    @Test("Running and needs-input facts coexist without fabricating a terminal result")
    func concurrentAttention() {
        let item = AnchorWorkItem(taskID: UUID(), title: "Build module")
        let waiting = run(
            item: item,
            execution: .waitingBackground,
            attention: [.needsInput],
            startedAt: 10
        )
        let running = run(item: item, execution: .running, startedAt: 11)

        let state = AnchorWorkItemStateProjector.project(workItem: item, runs: [waiting, running])
        #expect(state.execution == .running)
        #expect(state.attention == [.needsInput])
        #expect(state.outcome == .none)
        #expect(state.generation == 0)
        #expect(state.activeRunCount == 2)
    }

    @Test("Stale is an attention fact and never becomes failed or completed")
    func staleRemainsUnknown() {
        let item = AnchorWorkItem(taskID: UUID(), title: "Observe source")
        let stale = run(
            item: item,
            execution: .idle,
            attention: [.stale],
            startedAt: 10
        )

        let state = AnchorWorkItemStateProjector.project(workItem: item, runs: [stale])
        #expect(state.execution == .idle)
        #expect(state.attention == [.stale])
        #expect(state.outcome == .none)
    }

    @Test("Projection is deterministic and ignores runs owned by another work item")
    func orderIndependent() {
        let item = AnchorWorkItem(taskID: UUID(), title: "One")
        let other = AnchorWorkItem(taskID: item.taskID, title: "Two")
        let first = run(item: item, execution: .idle, outcome: .completed, startedAt: 10, finishedAt: 20)
        let second = run(item: item, execution: .idle, outcome: .completed, startedAt: 30, finishedAt: 40)
        let unrelated = run(item: other, execution: .running, attention: [.needsInput], startedAt: 50)

        let forward = AnchorWorkItemStateProjector.project(workItem: item, runs: [first, second, unrelated])
        let reverse = AnchorWorkItemStateProjector.project(workItem: item, runs: [unrelated, second, first])
        #expect(forward == reverse)
        #expect(forward.generation == 1)
        #expect(forward.outcome == .completed)
        #expect(forward.runCount == 2)
    }

    @Test("Legacy run JSON decodes with no attention facts")
    func legacyRunDecoding() throws {
        let item = AnchorWorkItem(taskID: UUID(), title: "Legacy")
        let current = run(item: item, execution: .running, startedAt: 10)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
        )
        object.removeValue(forKey: "attention")
        let decoded = try JSONDecoder().decode(
            AnchorRun.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        #expect(decoded.attention.isEmpty)
    }

    private func run(
        item: AnchorWorkItem,
        execution: AnchorRunExecution,
        attention: Set<AnchorRunAttention> = [],
        outcome: AnchorRunOutcome = .none,
        startedAt: TimeInterval,
        finishedAt: TimeInterval? = nil
    ) -> AnchorRun {
        AnchorRun(
            taskID: item.taskID,
            workItemID: item.id,
            sourceID: "test",
            execution: execution,
            attention: attention,
            outcome: outcome,
            startedAt: Date(timeIntervalSince1970: startedAt),
            finishedAt: finishedAt.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

@Suite("Task aggregate state projection")
struct TaskAggregateStateProjectionTests {
    @Test("Running work and attention override terminal siblings without ending the task")
    func activeWorkTakesPrecedence() {
        let task = AnchorTask(title: "Ship module", completionCriteria: "Tests pass")
        let completed = state(taskID: task.id, execution: .idle, outcome: .completed, runCount: 2)
        let active = state(
            taskID: task.id,
            execution: .running,
            attention: [.hasFailure, .needsInput],
            outcome: .none,
            activeRunCount: 1,
            runCount: 3
        )

        let projection = AnchorTaskStateProjector.project(task: task, workItemStates: [completed, active])
        #expect(projection.lifecycle == .active)
        #expect(projection.execution == .running)
        #expect(projection.attention == [.hasFailure, .needsInput])
        #expect(projection.outcome == .none)
        #expect(projection.workItemCount == 2)
        #expect(projection.activeWorkItemCount == 1)
        #expect(projection.runCount == 5)
    }

    @Test("All current work results complete without archiving the user task")
    func completedObservationKeepsLifecycleSeparate() {
        let task = AnchorTask(title: "Prepare deck", completionCriteria: "Exported")
        let first = state(taskID: task.id, execution: .idle, outcome: .completed)
        let second = state(taskID: task.id, execution: .idle, outcome: .completed)

        let projection = AnchorTaskStateProjector.project(task: task, workItemStates: [second, first])
        #expect(projection.lifecycle == .active)
        #expect(projection.execution == .idle)
        #expect(projection.outcome == .completed)
        #expect(projection.attention.isEmpty)
    }

    @Test("Failure wins only when no work item is active and input order is irrelevant")
    func terminalFailureIsDeterministic() {
        let task = AnchorTask(title: "Build app", completionCriteria: "Launches")
        let completed = state(taskID: task.id, execution: .idle, outcome: .completed)
        let failed = state(taskID: task.id, execution: .idle, outcome: .failed)
        let unrelated = state(taskID: UUID(), execution: .running, outcome: .none, activeRunCount: 1)

        let forward = AnchorTaskStateProjector.project(task: task, workItemStates: [completed, failed, unrelated])
        let reverse = AnchorTaskStateProjector.project(task: task, workItemStates: [unrelated, failed, completed])
        #expect(forward == reverse)
        #expect(forward.execution == .idle)
        #expect(forward.outcome == .failed)
        #expect(forward.workItemCount == 2)
    }

    @Test("Archiving preserves unresolved observed state without fabricating completion")
    func archivedTaskPreservesUnknownOutcome() {
        let task = AnchorTask(
            title: "Stop early",
            completionCriteria: "User decides",
            lifecycle: .archived,
            endedAt: Date(timeIntervalSince1970: 50)
        )
        let unresolved = state(
            taskID: task.id,
            execution: .idle,
            attention: [.stale],
            outcome: .none,
            activeRunCount: 1
        )

        let projection = AnchorTaskStateProjector.project(task: task, workItemStates: [unresolved])
        #expect(projection.lifecycle == .archived)
        #expect(projection.outcome == .none)
        #expect(projection.attention == [.stale])
    }

    @Test("A task with no observed work remains idle and unknown")
    func emptyTask() {
        let task = AnchorTask(title: "New task", completionCriteria: "Defined")
        let projection = AnchorTaskStateProjector.project(task: task, workItemStates: [])
        #expect(projection.execution == .idle)
        #expect(projection.outcome == .none)
        #expect(projection.workItemCount == 0)
        #expect(projection.runCount == 0)
    }

    private func state(
        taskID: UUID,
        execution: AnchorRunExecution,
        attention: Set<AnchorRunAttention> = [],
        outcome: AnchorRunOutcome,
        activeRunCount: Int = 0,
        runCount: Int = 1
    ) -> AnchorWorkItemState {
        AnchorWorkItemState(
            taskID: taskID,
            workItemID: UUID(),
            execution: execution,
            attention: attention,
            outcome: outcome,
            generation: 0,
            runCount: runCount,
            activeRunCount: activeRunCount,
            latestActivityAt: Date(timeIntervalSince1970: 10)
        )
    }
}
