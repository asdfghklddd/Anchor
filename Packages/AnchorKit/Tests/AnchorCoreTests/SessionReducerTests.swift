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
}

private struct LegacyContextSnapshot: Codable {
    let id: UUID
    let createdAt: Date
    let goalTitle: String
    let processStates: [UUID: ProcessStatus]
    let openDecisionIDs: [UUID]
    let latestNote: String?
}
