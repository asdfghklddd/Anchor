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

    @Test func plansSavedBeforeCheckingDecodeWithNothingDone() throws {
        let oldPlan = #"{"steps":["Sketch","Build"],"localImageNames":[]}"#
        let decoded = try JSONDecoder().decode(AnchorUserPlan.self, from: Data(oldPlan.utf8))
        #expect(decoded.completedSteps.isEmpty)
        #expect(decoded.reviewedAt == nil)
        #expect(decoded.nextStepIndex == 0)
    }

    @Test func checkedStepsSurviveRestartAndKeepTheirOrder() async throws {
        let url = URL.temporaryDirectory.appending(path: "plan-steps-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let plan = AnchorUserPlan(steps: ["Sketch", "Build", "Test"])
        let session = AnchorSession(goal: AnchorGoal(title: "Homepage", completionCriteria: "Done", userPlan: plan), processes: [])
        try await repository.send(.hostSession(session))

        let ids = plan.items.map(\.id)
        try await repository.send(.forSession(session.id, .setPlanStep(id: ids[1], done: true)))
        try await repository.send(.forSession(session.id, .setPlanStep(id: ids[0], done: true)))
        try await repository.send(.forSession(session.id, .setPlanStep(id: ids[1], done: false)))
        try await repository.send(.forSession(session.id, .markPlanReviewed))

        let restored = try #require(await LocalSessionRepository(storageURL: url, sourceID: UUID()).currentProjection().session)
        let saved = try #require(restored.goal.userPlan)
        #expect(saved.steps == plan.steps)
        #expect(saved.completedSteps == [0])
        #expect(saved.nextStepIndex == 1)
        #expect(saved.doneCount == 1)
        #expect(saved.reviewedAt != nil)
        #expect(restored.goal.title == "Homepage")
    }

    @Test func aStepOutsideThePlanIsRefused() async throws {
        let repository = InMemorySessionRepository(initialProjection: SessionProjection())
        let session = AnchorSession(goal: AnchorGoal(title: "Homepage", completionCriteria: "Done",
                                                     userPlan: AnchorUserPlan(steps: ["Sketch"])), processes: [])
        try await repository.send(.hostSession(session))
        await #expect(throws: (any Error).self) {
            try await repository.send(.forSession(session.id, .setPlanStep(id: UUID(), done: true)))
        }
        #expect(await repository.currentProjection().session?.goal.userPlan?.completedSteps == [])
    }

    @Test func checkingEveryStepFinishesThePlanButNotTheTask() throws {
        var plan = AnchorUserPlan(steps: ["Sketch", "Build"])
        plan = try #require(plan.marking(step: 0, done: true, at: .now))
        plan = try #require(plan.marking(step: 1, done: true, at: .now))
        #expect(plan.isFinished)
        #expect(plan.nextStepIndex == nil)
        #expect(plan.marking(step: 2, done: true, at: .now) == nil)
    }

    @Test func earlierPlansGetTheSameStepIdentityOnEveryDevice() throws {
        let phaseOne = #"{"steps":["Sketch","Build"],"localImageNames":[],"completedSteps":[0],"reviewedAt":0}"#
        let phone = try JSONDecoder().decode(AnchorUserPlan.self, from: Data(phaseOne.utf8))
        let mac = try JSONDecoder().decode(AnchorUserPlan.self, from: Data(phaseOne.utf8))
        #expect(phone == mac)
        #expect(phone.items.map(\.text) == ["Sketch", "Build"])
        #expect(phone.completedSteps == [0])
        #expect(Set(phone.items.map(\.id)).count == 2)
    }

    @Test func newPlansStillWriteTheirStepTextsForOlderBuilds() throws {
        let plan = try #require(AnchorUserPlan(steps: ["Sketch", "Build"]).marking(step: 0, done: true, at: .now))
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        #expect(json["steps"] as? [String] == ["Sketch", "Build"])
        #expect((json["items"] as? [[String: Any]])?.count == 2)
        #expect(try JSONDecoder().decode(AnchorUserPlan.self, from: JSONEncoder().encode(plan)) == plan)
    }

    @Test func editingKeepsEachStepsIdentityAndCheckmark() throws {
        let plan = try #require(AnchorUserPlan(steps: ["Sketch", "Build", "Test"]).marking(step: 1, done: true, at: .now))
        let build = plan.items[1]
        var edited = plan.items
        edited.insert(edited.remove(at: 1), at: 0)          // Build first
        edited[1].text = "Sketch the layout"                // rename Sketch
        edited.remove(at: 2)                                 // drop Test
        edited.append(AnchorUserPlan.Step(text: "Ship"))
        edited.append(AnchorUserPlan.Step(text: "   "))      // a blank line disappears
        let result = try #require(plan.replacingSteps(with: edited))
        #expect(result.steps == ["Build", "Sketch the layout", "Ship"])
        #expect(result.items[0].id == build.id)
        #expect(result.isDone(0))
        #expect(result.nextStepIndex == 1)
        #expect(plan.replacingSteps(with: [AnchorUserPlan.Step(text: " ")]) == nil)
    }

    @Test func editedStepsSurviveRestart() async throws {
        let url = URL.temporaryDirectory.appending(path: "plan-edit-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let plan = AnchorUserPlan(steps: ["Sketch", "Build"])
        let session = AnchorSession(goal: AnchorGoal(title: "Homepage", completionCriteria: "", userPlan: plan), processes: [])
        try await repository.send(.hostSession(session))
        try await repository.send(.forSession(session.id, .setPlanStep(id: plan.items[0].id, done: true)))
        var edited = try #require(await repository.currentProjection().session?.goal.userPlan?.items)
        edited.insert(AnchorUserPlan.Step(text: "Research"), at: 0)
        try await repository.send(.forSession(session.id, .updatePlanSteps(edited)))

        let restored = try #require(await LocalSessionRepository(storageURL: url, sourceID: UUID())
            .currentProjection().session?.goal.userPlan)
        #expect(restored.steps == ["Research", "Sketch", "Build"])
        #expect(restored.completedSteps == [1])
        #expect(restored.items[1].id == plan.items[0].id)
    }
}
