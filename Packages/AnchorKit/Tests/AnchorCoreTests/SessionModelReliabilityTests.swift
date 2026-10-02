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

}
