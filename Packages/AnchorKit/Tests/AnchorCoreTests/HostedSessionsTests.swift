import Foundation
import Testing
@testable import AnchorCore

@Suite("Concurrent hosted tasks")
struct HostedSessionsTests {
    @Test func preservesTasksAfterRestartAndRoutesBackgroundEvents() async throws {
        let url = URL.temporaryDirectory.appending(path: "hosted-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let a = AnchorSession(goal: AnchorGoal(title: "HKUST", completionCriteria: "Essay"))
        let b = AnchorSession(goal: AnchorGoal(title: "Portfolio", completionCriteria: "Publish"))
        try await repository.send(.hostSession(a))
        try await repository.send(.hostSession(b))
        let note = AnchorNote(sessionID: a.id, text: "Background update")
        let operation = SessionOperation.addNote(note)
        let envelope = EventEnvelope(sessionID: a.id, sourceID: UUID(), sequence: 1,
            type: EventEnvelope.operationType, payload: try JSONEncoder.anchor.encode(operation))
        try await repository.applyRemote(envelope)
        let restarted = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let projection = await restarted.currentProjection()
        #expect(projection.hostedSessions.count == 2)
        #expect(projection.session?.id == b.id)
        #expect(projection.additionalSessions.first?.notes.first?.text == "Background update")
        #expect(projection.session?.notes.isEmpty == true)
        try await restarted.send(.selectSession(a.id))
        try await restarted.send(.completeSession)
        #expect(await restarted.currentProjection().hostedSessions.map(\.id) == [b.id])
        #expect(await restarted.currentProjection().archivedSessions.map(\.id) == [a.id])
    }

    @Test func duplicateHostingAndJoiningOrderAreStable() throws {
        let first = AnchorProcess(sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan", title: "Main", status: .running)
        let second = AnchorProcess(sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan", title: "Research", status: .running)
        let session = AnchorSession(goal: AnchorGoal(title: "HKUST", completionCriteria: "Essay"), processes: [first, second])
        var p = try SessionReducer.reduce(.empty, operation: .hostSession(session))
        p = try SessionReducer.reduce(p, operation: .hostSession(session))
        p = try SessionReducer.reduce(p, operation: .reorderProcesses([second.id, first.id]))
        #expect(p.hostedSessions.count == 1)
        #expect(p.session?.conversationsInJoiningOrder.first?.id == first.id)
    }

    @Test func lifecycleBridgeDoesNotArchiveConcurrentTasks() async throws {
        let url = URL.temporaryDirectory.appending(path: "ledger-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = TaskRunStore(url: url)
        let repository = InMemorySessionRepository()
        let bridge = TaskSessionLifecycleBridge(repository: repository, taskRunStore: store)
        let a = AnchorSession(goal: AnchorGoal(title: "Essay", completionCriteria: "Done"))
        let b = AnchorSession(goal: AnchorGoal(title: "Portfolio", completionCriteria: "Done"))
        try await repository.send(.hostSession(a))
        try await bridge.synchronize(repository.currentProjection())
        try await repository.send(.hostSession(b))
        try await bridge.synchronize(repository.currentProjection())
        #expect(await store.taskRecord(id: a.id)?.task.lifecycle == .active)
        #expect(await store.taskRecord(id: b.id)?.task.lifecycle == .active)
        try await repository.send(.completeSession)
        try await bridge.synchronize(repository.currentProjection())
        #expect(await store.taskRecord(id: a.id)?.task.lifecycle == .active)
        #expect(await store.taskRecord(id: b.id)?.task.lifecycle == .archived)
    }

    @Test func observesBackgroundProgressWithoutChangingSelection() async throws {
        let url = URL.temporaryDirectory.appending(path: "progress-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let id = UUID()
        var process = AnchorProcess(sessionID: id, sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan", title: "Main", status: .running, progress: 0.2)
        let a = AnchorSession(id: id, goal: AnchorGoal(title: "Essay", completionCriteria: "Done"), processes: [process])
        let b = AnchorSession(goal: AnchorGoal(title: "Portfolio", completionCriteria: "Done"))
        try await repository.send(.hostSession(a))
        try await repository.send(.hostSession(b))
        process.progress = 0.8
        process.updatedAt = .now
        try await repository.send(.observeProcess(ProcessObservation(process: process)))
        #expect(await repository.currentProjection().additionalSessions.first?.processes.first?.progress == 0.8)
        #expect(await repository.currentProjection().session?.id == b.id)
        try await repository.send(.completeSession)
        process.progress = 0.9
        process.updatedAt = .now
        try await repository.send(.observeProcess(ProcessObservation(process: process)))
        #expect(await repository.currentProjection().session == nil)
        #expect(await repository.currentProjection().additionalSessions.first?.processes.first?.progress == 0.9)
    }

    @Test func scopedEditsAndCompletionNeverAffectTheSelectedOtherTask() async throws {
        let url = URL.temporaryDirectory.appending(path: "scope-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = LocalSessionRepository(storageURL: url, sourceID: UUID())
        let a = AnchorSession(goal: AnchorGoal(title: "Essay", completionCriteria: "Done"))
        let b = AnchorSession(goal: AnchorGoal(title: "Portfolio", completionCriteria: "Done"))
        try await repository.send(.hostSession(a))
        try await repository.send(.hostSession(b))
        try await repository.send(.forSession(a.id, .updateGoal(title: "Edited essay", completionCriteria: "Reviewed", note: "A only")))
        #expect(await repository.currentProjection().session?.goal.title == "Portfolio")
        #expect(await repository.currentProjection().additionalSessions.first?.goal.title == "Edited essay")
        try await repository.send(.forSession(a.id, .completeSession))
        #expect(await repository.currentProjection().session?.id == b.id)
        #expect(await repository.currentProjection().archivedSessions.first?.id == a.id)
    }

    @Test func legacyProjectionDecodesWithoutHostedTasks() throws {
        let data = try JSONEncoder.anchor.encode(SessionProjection.empty)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "additionalSessions")
        let decoded = try JSONDecoder.anchor.decode(SessionProjection.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.additionalSessions.isEmpty)
    }

    @Test func peersReplayIndependentTasks() async throws {
        let urls = (0..<2).map { _ in URL.temporaryDirectory.appending(path: "peer-\(UUID()).json") }
        defer { urls.forEach { try? FileManager.default.removeItem(at: $0) } }
        let a = LocalSessionRepository(storageURL: urls[0], sourceID: UUID())
        let b = LocalSessionRepository(storageURL: urls[1], sourceID: UUID())
        for title in ["Essay", "Portfolio"] {
            try await a.send(.hostSession(AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "Done"))))
        }
        for event in await a.pendingEvents().reversed() { try await b.applyRemote(event) }
        #expect(await b.currentProjection().hostedSessions.count == 2)
        #expect(await b.currentProjection().hostedSessions.map(\.id) == a.currentProjection().hostedSessions.map(\.id))
    }
}
