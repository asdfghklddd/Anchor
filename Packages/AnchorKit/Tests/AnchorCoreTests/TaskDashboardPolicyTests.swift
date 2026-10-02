import Foundation
import Testing
@testable import AnchorCore

@Suite("Production task dashboard scope")
struct TaskDashboardPolicyTests {
    @Test("Legacy app activity and decisions do not enter the current dashboard")
    func filtersLegacyRecordsWithoutChangingStoredData() throws {
        let ai = process("Codex", source: BuiltInProcessSourceID.codex)
        let cli = process("xcodebuild", source: BuiltInProcessSourceID.file)
        let app = process("Finder", source: BuiltInProcessSourceID.macWorkspace)
        let web = process("Safari", source: BuiltInProcessSourceID.web)
        let plan = process("My plan", source: nil)
        let choice = Decision(processID: ai.id, title: "Old question", prompt: "Choose", options: [])
        var session = AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done"),
                                    processes: [ai, cli, app, web, plan], decisions: [choice])
        session.timeline = [ProcessEvent(processID: app.id, kind: .created, title: "Finder launched"),
                            ProcessEvent(processID: ai.id, kind: .created, title: "Task started"),
                            ProcessEvent(processID: ai.id, kind: .decisionRequired, title: "Old question")]
        session.returnSummary = ReturnSummary(awaySince: .now, changes: session.timeline.map {
            ReturnChange(id: $0.id, title: $0.title, detail: "", kind: $0.kind)
        }, recommendedProcessID: app.id, newDecisionCount: 1)
        let stored = SessionProjection(session: session, archivedSessions: [session], additionalSessions: [session])
        let encoded = try JSONEncoder().encode(stored)
        let dashboard = TaskDashboardPolicy.presentation(of: stored)
        #expect(dashboard.session?.processes.map(\.id) == [ai.id, cli.id, plan.id])
        #expect(dashboard.additionalSessions.first?.processes.count == 3)
        #expect(dashboard.openDecisions.isEmpty)
        #expect(dashboard.session?.timeline.map(\.title) == ["Task started"])
        #expect(dashboard.session?.returnSummary?.changes.map(\.title) == ["Task started"])
        #expect(dashboard.session?.returnSummary?.recommendedProcessID == nil)
        #expect(dashboard.session?.returnSummary?.newDecisionCount == 0)
        #expect(dashboard.archivedSessions == stored.archivedSessions)
        #expect(try JSONDecoder().decode(SessionProjection.self, from: encoded) == stored)
        #expect(stored.session?.processes.count == 5)
        #expect(stored.session?.decisions.count == 1)
    }

    @Test("Return event counts follow filtered records and distinguish interruptions")
    func returnCountersUseVisibleFacts() {
        let ai = process("Codex", source: BuiltInProcessSourceID.codex)
        let app = process("Finder", source: BuiltInProcessSourceID.macWorkspace)
        var session = AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done"), processes: [ai, app])
        session.timeline = [
            ProcessEvent(processID: app.id, kind: .completed, title: "Legacy app record"),
            ProcessEvent(processID: ai.id, kind: .failed, title: "Codex turn_aborted"),
            ProcessEvent(processID: ai.id, kind: .failed, title: "Build failed")
        ]
        session.returnSummary = ReturnSummary(awaySince: .now, changes: session.timeline.map {
            ReturnChange(id: $0.id, title: $0.title, detail: "", kind: $0.kind)
        }, completedCount: 1, failedCount: 2)
        let summary = TaskDashboardPolicy.presentation(of: SessionProjection(session: session)).session?.returnSummary
        #expect(summary?.changes.count == 2)
        #expect(summary?.completedCount == 0)
        #expect(summary?.failedCount == 1)
    }

    @Test("Dashboard commands cannot resolve a decision, including scoped commands")
    @MainActor
    func rejectsDecisionActions() async throws {
        let ai = process("Codex", source: BuiltInProcessSourceID.codex)
        let option = DecisionOption(title: "Continue")
        let decision = Decision(processID: ai.id, title: "Old question", prompt: "Choose", options: [option])
        let session = AnchorSession(goal: AnchorGoal(title: "Work", completionCriteria: "Done"),
                                    processes: [ai], decisions: [decision])
        let stored = SessionProjection(session: session)
        let repository = InMemorySessionRepository(initialProjection: stored)
        let model = AnchorSessionModel(repository: repository, initialProjection: stored, usesTaskDashboard: true)
        #expect(model.projection.openDecisions.isEmpty)
        #expect(await model.send(.resolveDecision(decisionID: decision.id, optionID: option.id)) == false)
        #expect(await model.send(.forSession(session.id, .resolveDecision(decisionID: decision.id, optionID: option.id))) == false)
        #expect(await repository.currentProjection().session?.decisions.first?.status == .open)
        #expect(await model.selectHostedTask(session.id))
        #expect(model.projection.openDecisions.isEmpty)
        #expect(await model.addNote("Observation still works"))
        #expect(await repository.currentProjection().session?.notes.first?.text == "Observation still works")
    }

    private func process(_ name: String, source: UUID?) -> AnchorProcess {
        AnchorProcess(sourceID: source, sourceName: name, sourceSymbol: "S", sourceTone: "cyan",
                      title: name, status: .running)
    }
}
