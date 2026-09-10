import Foundation
import Testing
@testable import AnchorCore

@Suite("Immutable task event history")
struct TaskEventStoreTests {
    @Test("Every process status maps to independent execution, attention, outcome and event facts")
    func mapsProcessStatus() {
        let cases: [(ProcessStatus, AnchorRunExecution, Set<AnchorRunAttention>, AnchorRunOutcome, AnchorTaskEventKind)] = [
            (.queued, .queued, [], .none, .queued),
            (.running, .running, [], .none, .started),
            (.needsDecision, .waitingBackground, [.needsInput], .none, .needsInput),
            (.blocked, .waitingBackground, [.needsInput], .none, .needsInput),
            (.completed, .idle, [], .completed, .completed),
            (.failed, .idle, [], .failed, .failed),
            (.disconnected, .idle, [.stale], .none, .stale),
        ]
        for (status, execution, attention, outcome, kind) in cases {
            let association = AnchorEventAssociation(taskID: UUID(), workItemID: UUID(), confirmedByUser: true)
            let observation = externalEvent(status: status)
            let run = observation.makeRun(association: association)
            let event = observation.makeTaskEvent(association: association)
            #expect(run.execution == execution)
            #expect(run.attention == attention)
            #expect(run.outcome == outcome)
            #expect(event.kind == kind)
            #expect(event.runID == run.id)
            #expect(event.taskID == association.taskID)
            #expect(event.workItemID == association.workItemID)
        }
    }

    @Test("Completion arriving before start keeps both facts and backfills time without reopening")
    func outOfOrderCompletionThenStart() async throws {
        let fixture = try await Fixture()
        let processID = UUID()
        let completion = externalEvent(
            id: UUID(),
            processID: processID,
            sessionID: fixture.sessionID,
            sourceID: fixture.sourceID,
            externalID: "turn-one",
            status: .completed,
            sequence: 20,
            at: 20
        )
        let start = externalEvent(
            id: UUID(),
            processID: processID,
            sessionID: fixture.sessionID,
            sourceID: fixture.sourceID,
            externalID: "turn-one",
            status: .running,
            sequence: 10,
            at: 10
        )

        try await fixture.store.record(
            event: completion.makeTaskEvent(association: fixture.association, receivedAt: Date(timeIntervalSince1970: 21)),
            run: completion.makeRun(association: fixture.association)
        )
        try await fixture.store.record(
            event: start.makeTaskEvent(association: fixture.association, receivedAt: Date(timeIntervalSince1970: 22)),
            run: start.makeRun(association: fixture.association)
        )
        // Re-delivery has a different receive time but is still the same source fact.
        try await fixture.store.record(
            event: completion.makeTaskEvent(association: fixture.association, receivedAt: Date(timeIntervalSince1970: 99)),
            run: completion.makeRun(association: fixture.association)
        )

        let snapshot = await fixture.store.snapshot()
        #expect(snapshot.events.count == 2)
        #expect(snapshot.runs.count == 1)
        #expect(snapshot.runs[0].outcome == .completed)
        #expect(snapshot.runs[0].execution == .idle)
        #expect(snapshot.runs[0].startedAt == Date(timeIntervalSince1970: 10))
        #expect(snapshot.runs[0].finishedAt == Date(timeIntervalSince1970: 20))
        #expect(await fixture.store.events(taskID: fixture.task.id).map(\.kind) == [.started, .completed])

        let restored = TaskRunStore(url: fixture.url)
        #expect(await restored.snapshot().events.count == 2)
        #expect(await restored.snapshot().runs.first?.outcome == .completed)
    }

    @Test("An event ID cannot be reused for a different immutable fact")
    func conflictingIdentityIsRejectedWithoutChangingDisk() async throws {
        let fixture = try await Fixture()
        let observation = externalEvent(
            sessionID: fixture.sessionID,
            sourceID: fixture.sourceID,
            status: .running,
            at: 10
        )
        let original = observation.makeTaskEvent(association: fixture.association)
        let run = observation.makeRun(association: fixture.association)
        try await fixture.store.record(event: original, run: run)
        let before = try Data(contentsOf: fixture.url)
        let conflicting = AnchorTaskEvent(
            id: original.id,
            taskID: original.taskID,
            workItemID: original.workItemID,
            runID: original.runID,
            sourceID: original.sourceID,
            sourceSessionID: original.sourceSessionID,
            sourceSequence: original.sourceSequence,
            occurredAt: original.occurredAt,
            receivedAt: original.receivedAt,
            kind: .failed
        )

        await #expect(throws: TaskRunStoreError.eventIdentityConflict) {
            try await fixture.store.record(event: conflicting, run: run)
        }
        #expect(try Data(contentsOf: fixture.url) == before)
        #expect(await fixture.store.snapshot().events == [original])
    }

    @Test("Events outside the task boundary or after archive are rejected")
    func taskBoundaryIsEnforced() async throws {
        let fixture = try await Fixture(taskCreatedAt: 10)
        let early = externalEvent(
            sessionID: fixture.sessionID,
            sourceID: fixture.sourceID,
            status: .running,
            at: 5
        )
        await #expect(throws: TaskRunStoreError.eventOutsideTaskBoundary) {
            try await fixture.store.record(
                event: early.makeTaskEvent(association: fixture.association),
                run: early.makeRun(association: fixture.association)
            )
        }
        try await fixture.store.confirmTaskEnded(taskID: fixture.task.id, at: Date(timeIntervalSince1970: 20))
        let late = externalEvent(
            sessionID: fixture.sessionID,
            sourceID: fixture.sourceID,
            status: .completed,
            at: 15
        )
        await #expect(throws: TaskRunStoreError.taskArchived) {
            try await fixture.store.record(
                event: late.makeTaskEvent(association: fixture.association),
                run: late.makeRun(association: fixture.association)
            )
        }
        #expect(await fixture.store.snapshot().events.isEmpty)
    }

    @Test("A store written before the event field existed remains readable")
    func legacyStoreWithoutEventsMigrates() async throws {
        let fixture = try await Fixture()
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixture.url)) as? [String: Any]
        )
        object.removeValue(forKey: "events")
        try JSONSerialization.data(withJSONObject: object).write(to: fixture.url, options: .atomic)

        let restored = TaskRunStore(url: fixture.url)
        #expect(await restored.snapshot().events.isEmpty)
        let observation = externalEvent(
            sessionID: fixture.sessionID,
            sourceID: fixture.sourceID,
            status: .running,
            at: 10
        )
        try await restored.record(
            event: observation.makeTaskEvent(association: fixture.association),
            run: observation.makeRun(association: fixture.association)
        )
        #expect(await restored.snapshot().events.count == 1)
    }

    @Test("Task events carry a version, accept legacy v1 bytes and reject future versions")
    func eventProtocolVersionIsExplicit() throws {
        let event = externalEvent(status: .running).makeTaskEvent(
            association: AnchorEventAssociation(
                taskID: UUID(),
                workItemID: UUID(),
                confirmedByUser: true
            )
        )
        let encoded = try JSONEncoder().encode(event)
        let current = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        #expect(current["version"] as? Int == AnchorTaskEvent.currentVersion)

        var legacy = current
        legacy.removeValue(forKey: "version")
        let decodedLegacy = try JSONDecoder().decode(
            AnchorTaskEvent.self,
            from: JSONSerialization.data(withJSONObject: legacy)
        )
        #expect(decodedLegacy == event)

        var future = current
        future["version"] = AnchorTaskEvent.currentVersion + 1
        #expect(throws: AnchorTaskEventCodingError.unsupportedVersion(2)) {
            try JSONDecoder().decode(
                AnchorTaskEvent.self,
                from: JSONSerialization.data(withJSONObject: future)
            )
        }
    }

    private final class Fixture: @unchecked Sendable {
        let directory: URL
        let url: URL
        let store: TaskRunStore
        let task: AnchorTask
        let item: AnchorWorkItem
        let sessionID = UUID()
        let sourceID = UUID()
        var association: AnchorEventAssociation {
            AnchorEventAssociation(taskID: task.id, workItemID: item.id, confirmedByUser: true)
        }

        init(taskCreatedAt: TimeInterval = 0) async throws {
            directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            url = directory.appendingPathComponent("task-events.json")
            store = TaskRunStore(url: url)
            task = AnchorTask(
                title: "Test task",
                completionCriteria: "Verified",
                createdAt: Date(timeIntervalSince1970: taskCreatedAt)
            )
            item = AnchorWorkItem(taskID: task.id, title: "Observed work", createdAt: task.createdAt)
            try await store.upsert(task: task)
            try await store.upsert(workItem: item)
        }

        deinit {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func externalEvent(
        id: UUID = UUID(),
        processID: UUID = UUID(),
        sessionID: UUID = UUID(),
        sourceID: UUID = UUID(),
        externalID: String = "turn",
        status: ProcessStatus,
        sequence: UInt64 = 1,
        at: TimeInterval = 10
    ) -> ExternalProcessEvent {
        let date = Date(timeIntervalSince1970: at)
        return ExternalProcessEvent(
            id: id,
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: sequence,
            occurredAt: date,
            process: AnchorProcess(
                id: processID,
                sessionID: sessionID,
                sourceID: sourceID,
                externalID: externalID,
                sourceName: "Test source",
                sourceSymbol: "T",
                sourceTone: "cyan",
                title: "Observed run",
                status: status,
                updatedAt: date
            )
        )
    }
}
