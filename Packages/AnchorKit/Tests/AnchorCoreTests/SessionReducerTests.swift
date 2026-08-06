import Foundation
import Testing
@testable import AnchorCore

@Suite("Session reducer")
struct SessionReducerTests {
    @Test("Replayed event envelope is idempotent")
    func envelopeDeduplication() throws {
        let sessionID = UUID()
        let processID = UUID()
        let process = AnchorProcess(
            id: processID,
            sourceName: "Test",
            sourceSymbol: "T",
            sourceTone: "cyan",
            title: "Test process",
            status: .running
        )
        let session = AnchorSession(
            id: sessionID,
            goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
            processes: [process]
        )
        let event = ProcessEvent(
            processID: processID,
            kind: .progress,
            title: "Halfway"
        )
        let envelope = EventEnvelope(
            sessionID: sessionID,
            sourceID: UUID(),
            sequence: 1,
            type: "process.progress",
            payload: Data()
        )
        let initial = SessionProjection(session: session)
        let once = try SessionReducer.reduce(initial, command: .applyEnvelope(envelope, event: event))
        let twice = try SessionReducer.reduce(once, command: .applyEnvelope(envelope, event: event))

        #expect(once.session?.timeline.count == 1)
        #expect(twice.session?.timeline.count == 1)
    }

    @Test("Resolving a decision updates its process")
    func decisionResolution() throws {
        let processID = UUID()
        let option = DecisionOption(title: "Choose me")
        let decision = Decision(
            processID: processID,
            title: "Choose",
            prompt: "Pick one",
            options: [option]
        )
        let process = AnchorProcess(
            id: processID,
            sourceName: "Test",
            sourceSymbol: "T",
            sourceTone: "sand",
            title: "Await choice",
            status: .needsDecision
        )
        let session = AnchorSession(
            goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
            processes: [process],
            decisions: [decision]
        )
        let result = try SessionReducer.reduce(
            SessionProjection(session: session),
            command: .resolveDecision(decisionID: decision.id, optionID: option.id)
        )

        #expect(result.session?.decisions.first?.status == .resolved)
        #expect(result.session?.processes.first?.status == .running)
    }

    @Test("A context snapshot owns its historical process values")
    func snapshotDoesNotReadLiveProcessState() throws {
        let process = AnchorProcess(
            sourceName: "Test",
            sourceSymbol: "T",
            sourceTone: "cyan",
            title: "Historical work",
            status: .running,
            progress: 0.25
        )
        let session = AnchorSession(
            goal: AnchorGoal(title: "Test", completionCriteria: "Done"),
            presence: .atDesk,
            processes: [process]
        )
        let away = try SessionReducer.reduce(
            SessionProjection(session: session),
            command: .updatePresence(.away, at: .now)
        )
        var completedProcess = process
        completedProcess.status = .completed
        completedProcess.progress = 1
        let updated = try SessionReducer.reduce(
            away,
            command: .updateProcess(completedProcess)
        )

        #expect(updated.session?.processes.first?.status == .completed)
        #expect(updated.session?.snapshots.first?.processes.first?.status == .running)
        #expect(updated.session?.snapshots.first?.processes.first?.progress == 0.25)
    }

    @Test("A remote envelope cannot mislabel a different session")
    func remoteSessionMustMatchEnvelope() throws {
        let local = AnchorSession(goal: AnchorGoal(title: "Local", completionCriteria: "Done"))
        let remote = AnchorSession(goal: AnchorGoal(title: "Remote", completionCriteria: "Done"))
        let envelope = EventEnvelope(
            sessionID: UUID(),
            sourceID: UUID(),
            sequence: 1,
            type: "session.projection.v1",
            payload: Data()
        )
        let result = try SessionReducer.reduce(
            SessionProjection(session: local),
            command: .mergeRemoteSession(envelope, session: remote)
        )

        #expect(result.session?.id == local.id)
    }

    @Test("Connection signals do not make stale work data look fresh")
    func connectionSignalsPreserveDataAge() throws {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let signalAt = Date(timeIntervalSince1970: 2_000)
        let initial = SessionProjection(
            generatedAt: observedAt,
            dataObservedAt: observedAt
        )

        let result = try SessionReducer.reduce(
            initial,
            command: .updateSignals(
                connection: .connected,
                proximity: .near,
                at: signalAt
            ),
            now: signalAt
        )

        #expect(result.connection == .connected)
        #expect(result.proximity == .near)
        #expect(result.dataObservedAt == observedAt)
        #expect(result.isStale)
    }

    @Test("Context snapshots remain compatible with the v1 wire payload")
    func contextSnapshotWireCompatibility() throws {
        let process = AnchorProcess(
            sourceName: "Test",
            sourceSymbol: "T",
            sourceTone: "cyan",
            title: "Historical work",
            status: .running
        )
        let legacy = LegacyContextSnapshot(
            id: UUID(),
            createdAt: .now,
            goalTitle: "Legacy goal",
            processStates: [process.id: .running],
            openDecisionIDs: [],
            latestNote: "Legacy note"
        )

        let decodedCurrent = try JSONDecoder().decode(
            ContextSnapshot.self,
            from: JSONEncoder().encode(legacy)
        )
        #expect(decodedCurrent.processes.isEmpty)
        #expect(decodedCurrent.processStates == legacy.processStates)

        let current = ContextSnapshot(
            goalTitle: "Current goal",
            processes: [process],
            openDecisionIDs: [],
            latestNote: nil
        )
        let decodedLegacy = try JSONDecoder().decode(
            LegacyContextSnapshot.self,
            from: JSONEncoder().encode(current)
        )
        #expect(decodedLegacy.processStates == [process.id: .running])
    }

    @Test("Return summary is derived from event history and prioritizes the top decision")
    func returnSummaryUsesRealChanges() throws {
        let started = Date(timeIntervalSince1970: 10_000)
        let returned = started.addingTimeInterval(20 * 60)
        let firstProcess = AnchorProcess(
            sourceName: "Source A",
            sourceSymbol: "A",
            sourceTone: "cyan",
            title: "Completed work",
            status: .running,
            updatedAt: started
        )
        let secondProcess = AnchorProcess(
            sourceName: "Source B",
            sourceSymbol: "B",
            sourceTone: "sand",
            title: "Waiting for a decision",
            status: .needsDecision,
            updatedAt: started
        )
        let lowPriority = Decision(
            processID: firstProcess.id,
            title: "Low priority",
            prompt: "Choose later",
            options: [DecisionOption(title: "Later")],
            requestedAt: started,
            priority: 1
        )
        let highPriority = Decision(
            processID: secondProcess.id,
            title: "High priority",
            prompt: "Choose now",
            options: [DecisionOption(title: "Now")],
            requestedAt: started.addingTimeInterval(30),
            priority: 9
        )
        let session = AnchorSession(
            goal: AnchorGoal(title: "Return to work", completionCriteria: "Resume"),
            processes: [firstProcess, secondProcess],
            decisions: [lowPriority, highPriority]
        )
        var projection = try SessionReducer.reduce(
            SessionProjection(session: session),
            command: .updatePresence(.away, at: started)
        )
        projection = try SessionReducer.reduce(
            projection,
            command: .recordEvent(
                ProcessEvent(
                    processID: firstProcess.id,
                    occurredAt: started.addingTimeInterval(5 * 60),
                    kind: .completed,
                    title: "Completed while away"
                )
            )
        )
        projection = try SessionReducer.reduce(
            projection,
            command: .recordEvent(
                ProcessEvent(
                    processID: secondProcess.id,
                    occurredAt: started.addingTimeInterval(10 * 60),
                    kind: .decisionRequired,
                    title: "A decision is waiting"
                )
            )
        )
        let returning = try SessionReducer.reduce(
            projection,
            command: .updatePresence(.returning, at: returned)
        )

        let summary = try #require(returning.session?.returnSummary)
        #expect(summary.elapsedSeconds ?? -1 == 1_200)
        #expect(summary.completedCount == 1)
        #expect(summary.newDecisionCount == 1)
        #expect(summary.failedCount == 0)
        #expect(summary.recommendedProcessID == secondProcess.id)
        #expect(summary.impactPercent == 40)
        #expect(summary.changes.map(\.title) == ["A decision is waiting", "Completed while away"])
    }
}

private struct LegacyContextSnapshot: Codable {
    let id: UUID
    let createdAt: Date
    let goalTitle: String
    let processStates: [UUID: ProcessStatus]
    let openDecisionIDs: [UUID]
    let latestNote: String?
}
