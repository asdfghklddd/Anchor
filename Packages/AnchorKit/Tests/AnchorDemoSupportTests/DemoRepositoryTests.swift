import AnchorCore
import AnchorDemoSupport
import Foundation
import Testing

@Suite("Demo repository")
struct DemoRepositoryTests {
    @Test("Scenario switching and reset use the same repository projection")
    func switchAndReset() async {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let repository = DemoSessionRepository(storageURL: storage, restoresSavedState: false)

        await repository.switchScenario(to: .returning)
        #expect(await repository.currentProjection().session?.presence == .returning)

        await repository.reset()
        #expect(await repository.activeScenario() == .active)
        #expect(await repository.currentProjection().session?.presence == .atDesk)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Persisted user actions survive repository recreation")
    func persistence() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-demo-\(UUID().uuidString).json")
        let first = DemoSessionRepository(storageURL: storage, restoresSavedState: false)
        try await first.send(.addNote("Remember this"))

        let second = DemoSessionRepository(storageURL: storage)
        #expect(await second.currentProjection().session?.notes.first?.text == "Remember this")
        try? FileManager.default.removeItem(at: storage)
    }
}
