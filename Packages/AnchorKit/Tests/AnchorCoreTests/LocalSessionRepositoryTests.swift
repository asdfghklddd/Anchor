import Foundation
import Testing
@testable import AnchorCore

@Suite("Local session repository")
struct LocalSessionRepositoryTests {
    @Test("User-created empty workspace state survives relaunch")
    func persistsUserSession() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-local-\(UUID().uuidString).json")
        let first = LocalSessionRepository(storageURL: storage)
        let goal = AnchorGoal(
            title: "Ship the first workspace",
            completionCriteria: "The main workspace is ready"
        )
        let process = AnchorProcess(
            sourceName: "Manual task",
            sourceSymbol: "M",
            sourceTone: "cyan",
            title: "Build the iPhone experience",
            status: .queued
        )

        try await first.send(.createSession(goal: goal, processes: [process]))

        let second = LocalSessionRepository(storageURL: storage)
        #expect(await second.currentProjection().session?.goal.title == goal.title)
        #expect(await second.currentProjection().session?.processes.count == 1)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("A fresh production repository starts as an empty workspace")
    func startsEmpty() async {
        let storage = URL.temporaryDirectory.appending(path: "anchor-local-\(UUID().uuidString).json")
        let repository = LocalSessionRepository(storageURL: storage)
        let projection = await repository.currentProjection()

        #expect(projection.session == nil)
        #expect(projection.errorMessage == nil)
        try? FileManager.default.removeItem(at: storage)
    }
}
