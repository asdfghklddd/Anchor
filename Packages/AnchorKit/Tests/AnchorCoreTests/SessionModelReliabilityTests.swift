import Foundation
import Testing
@testable import AnchorCore

@Suite("Session model reliability")
struct SessionModelReliabilityTests {
    @Test("Repeated process identities in a reorder cannot duplicate or crash the next snapshot")
    func duplicateReorderIDs() throws {
        let a = AnchorProcess(sourceName: "Source", sourceSymbol: "S", sourceTone: "cyan", title: "A", status: .running)
        let b = AnchorProcess(sourceName: "Source", sourceSymbol: "S", sourceTone: "cyan", title: "B", status: .queued)
        let session = AnchorSession(goal: AnchorGoal(title: "Task", completionCriteria: "Done"), processes: [a, b])
        let projection = SessionProjection(session: session)
        let ids = [b.id, b.id, UUID(), a.id]
        let direct = try SessionReducer.reduce(projection, command: .reorderProcesses(ids))
        let replayed = try SessionReducer.reduce(projection, operation: .reorderProcesses(ids))
        for result in [direct, replayed] {
            #expect(result.session?.processes.map(\.id) == [b.id, a.id])
            let completed = try SessionReducer.reduce(result, command: .completeSession)
            #expect(completed.archivedSessions.first?.snapshots.first?.processes.count == 2)
        }
        let legacySnapshot = ContextSnapshot(createdAt: .now, goalTitle: "Legacy", processes: [a, a], openDecisionIDs: [], latestNote: nil)
        #expect(legacySnapshot.processStates.count == 1)
    }

    @Test("Operational refreshes preserve failed user actions until explicitly dismissed")
    @MainActor
    func errorsSurviveHealthRefresh() async throws {
        let repository = InMemorySessionRepository()
        let model = AnchorSessionModel(repository: repository)
        #expect(await model.addNote("No active session") == false)
        let error = try #require(model.lastError)
        #expect(await model.send(.updateSignals(connection: .connected, proximity: .near, at: .now)))
        #expect(await model.send(.updateSourceHealth([])))
        #expect(await model.send(.updateDurableSyncState(.available)))
        #expect(model.lastError == error)
        model.dismissLastError()
        #expect(model.lastError == nil)
    }

    @Test("Repeated confirmation of a saved decision never repeats the external action")
    @MainActor
    func decisionConfirmationIsIdempotent() async throws {
        let process = AnchorProcess(sourceID: UUID(), sourceName: "Source", sourceSymbol: "S", sourceTone: "cyan", title: "Work", status: .needsDecision)
        let option = DecisionOption(title: "Continue", detail: "")
        let decision = Decision(processID: process.id, title: "Choose", prompt: "Next", options: [option])
        let repository = InMemorySessionRepository(initialProjection: SessionProjection(session:
            AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done"), processes: [process], decisions: [decision])))
        let source = ActionCounter()
        let model = AnchorSessionModel(repository: repository, sourceActionProvider: source,
            initialProjection: await repository.currentProjection())
        #expect(await model.resolve(decision: decision, option: option))
        // Intentionally keep model.projection stale to reproduce reopening an old sheet.
        #expect(await model.resolve(decision: decision, option: option))
        #expect(await source.count == 1)
        #expect(await repository.currentProjection().session?.processes.first?.status == .needsDecision)
    }
}

private actor ActionCounter: SourceActionPerforming {
    var count = 0
    func perform(_ action: SourceAction, on sourceID: UUID) async throws -> SourceActionReceipt {
        count += 1
        return SourceActionReceipt(sourceID: sourceID, action: action)
    }
}
