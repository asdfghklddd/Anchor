import Foundation
import Testing
@testable import AnchorCore

@Suite("User-authored anchor plans")
struct AnchorUserPlanTests {
    @Test func legacyGoalsDecodeWithoutPlan() throws {
        let oldGoal = """
        {"id":"F6A4B3A2-4957-4FD4-93A8-A9EE26C30FAC","title":"Original goal","completionCriteria":"Done","note":"Original words","createdAt":0}
        """
        let decoded = try JSONDecoder().decode(AnchorGoal.self, from: Data(oldGoal.utf8))
        #expect(decoded.userPlan == nil)
        #expect(decoded.note == "Original words")
    }

    @Test func planWithoutProcessesSurvivesRestartAndGoalEdits() async throws {
        let url = URL.temporaryDirectory.appending(path: "plan-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let plan = AnchorUserPlan(steps: ["Sketch", "Build"], localImageNames: ["reference-1.jpg"])
        let goal = AnchorGoal(title: "Homepage", completionCriteria: "Clear hierarchy\nWorking prototype", note: "My own words", userPlan: plan)
        let session = AnchorSession(goal: goal, processes: [])
        try await repository.send(.hostSession(session))
        try await repository.send(.forSession(session.id, .updateGoal(title: "Revised homepage", completionCriteria: "Reviewed", note: goal.note)))
        let restarted = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let projection = await restarted.currentProjection()
        let restored = try #require(projection.session)
        #expect(restored.processes.isEmpty)
        #expect(restored.goal.userPlan == plan)
        #expect(restored.goal.id == goal.id)
        #expect(restored.goal.title == "Revised homepage")
        try await restarted.send(.completeSession)
        #expect(await restarted.currentProjection().archivedSessions.first?.goal.userPlan == plan)
    }
}
