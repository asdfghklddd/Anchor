import Foundation
import Testing
@testable import AnchorCore

@Test("Session completion archives history and a later task becomes current")
func sessionLifecycleMaintainsTaskBoundary() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = TaskRunStore(url: directory.appendingPathComponent("task-runs.json"))
    let repository = InMemorySessionRepository()
    let bridge = TaskSessionLifecycleBridge(
        repository: repository,
        taskRunStore: store
    )

    try await repository.send(
        .createSession(
            goal: AnchorGoal(title: "First", completionCriteria: "Done"),
            processes: []
        )
    )
    let firstProjection = await repository.currentProjection()
    let firstID = try #require(firstProjection.session?.id)
    try await bridge.synchronize(firstProjection)
    #expect(await store.currentTaskRecord()?.task.id == firstID)

    try await repository.send(.completeSession)
    try await bridge.synchronize(await repository.currentProjection())
    #expect(await store.currentTaskRecord() == nil)
    #expect(await store.taskHistory().map(\.task.id) == [firstID])

    try await repository.send(
        .createSession(
            goal: AnchorGoal(title: "Second", completionCriteria: "Done again"),
            processes: []
        )
    )
    let secondProjection = await repository.currentProjection()
    let secondID = try #require(secondProjection.session?.id)
    try await bridge.synchronize(secondProjection)

    #expect(secondID != firstID)
    #expect(await store.currentTaskRecord()?.task.id == secondID)
    #expect(await store.taskHistory().map(\.task.id) == [firstID])
}

@Test("A later session repairs an interrupted task-boundary write")
func laterSessionRepairsInterruptedTaskBoundary() async throws {
    let directory = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = TaskRunStore(url: directory.appendingPathComponent("task-runs.json"))
    let interruptedTask = AnchorTask(
        title: "Interrupted task",
        completionCriteria: "Old result",
        createdAt: Date(timeIntervalSince1970: 10)
    )
    try await store.activate(task: interruptedTask)

    let repository = InMemorySessionRepository()
    try await repository.send(
        .createSession(
            goal: AnchorGoal(title: "Recovered task", completionCriteria: "New result"),
            processes: []
        )
    )
    let projection = await repository.currentProjection()
    let recoveredID = try #require(projection.session?.id)
    let bridge = TaskSessionLifecycleBridge(
        repository: repository,
        taskRunStore: store
    )

    try await bridge.synchronize(projection)

    #expect(await store.currentTaskRecord()?.task.id == recoveredID)
    let history = await store.taskHistory()
    #expect(history.map(\.task.id) == [interruptedTask.id])
    #expect(history.first?.task.endedAt == projection.session?.startedAt)
}
