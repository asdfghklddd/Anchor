#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@Suite("Mac demo")
@MainActor
struct MacDemoTests {
    private let paired = DevicePairingStatus(phase: .connected, route: .bluetooth)

    /// A store of its own; without a path the repository would use the Mac's real one.
    private static func repository() -> LocalSessionRepository {
        LocalSessionRepository(storageURL: FileManager.default.temporaryDirectory
            .appending(path: "AnchorMacDemoTests-\(UUID().uuidString).json"))
    }

    private func content(_ projection: SessionProjection) -> NotchIslandContent {
        NotchIslandContent(
            status: AnchorStatusMenu(projection: projection, radio: .unknown, pairing: paired,
                                     codexReady: true, claudeReady: true),
            projection: projection)
    }

    @Test("Each press plays one scene: a new task, a finished agent, a waiting one, then the first step")
    func scenesTellTheStory() async {
        let repository = Self.repository()
        var finished = false
        let director = MacDemoDirector(repository: repository) { finished = true }
        var detector = NotchPeekDetector()
        func news() async -> [NotchPeek] {
            let projection = await repository.currentProjection()
            return detector.peeks(in: projection, link: content(projection).link, now: .now)
        }
        _ = await news()

        director.start()
        await director.settle()
        var island = content(await repository.currentProjection())
        #expect(island.tasks.count == 2)
        #expect(island.link == .connected(viaBluetooth: true))
        #expect(island.progress == NotchIslandContent.Progress(done: 1, total: 3))
        #expect(island.tasks.contains { $0.signal == .running })
        // Conversations caught before the film starts are no news.
        #expect(await news().isEmpty)

        director.advance()
        await director.settle()
        island = content(await repository.currentProjection())
        #expect(island.tasks.count == 3)
        #expect(island.current?.colorIndex == 2)
        #expect(island.current?.signal == .running)
        #expect(island.progress?.done == 0)
        #expect(island.prompt != nil)
        #expect(await news().isEmpty)

        director.advance()
        await director.settle()
        #expect(await news().map(\.kind) == [.finished])

        director.advance()
        await director.settle()
        let waiting = await news()
        #expect(waiting.map(\.kind) == [.waiting])
        #expect(waiting.first?.colorIndex == 1)

        director.advance()
        await director.settle()
        let closing = await news()
        #expect(closing.map(\.kind) == [.finished])
        #expect(closing.first?.colorIndex == 2)
        island = content(await repository.currentProjection())
        #expect(island.progress?.done == 1)

        #expect(!finished)
        director.advance()
        await director.settle()
        #expect(finished)
    }

    @Test("Starting over takes the demo's tasks off and plays the opening again")
    func restartPlaysTheOpening() async {
        let repository = Self.repository()
        let director = MacDemoDirector(repository: repository)
        director.start()
        director.advance()
        director.advance()
        var cleared = false
        director.restart { cleared = true }
        await director.settle()
        #expect(cleared)
        #expect(director.scene == .opening)
        let island = content(await repository.currentProjection())
        #expect(island.tasks.count == 2)
        #expect(island.tasks.allSatisfy { $0.colorIndex < 2 })
    }

    @Test("A replay asked for in Settings plays on the next launch only")
    func replayIsForOneLaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "MacDemoTests-\(UUID().uuidString)"))
        defaults.set(true, forKey: MacDemoLaunch.pendingKey)
        #expect(MacDemoLaunch.takePending(defaults: defaults))
        #expect(!MacDemoLaunch.takePending(defaults: defaults))
    }

    @Test("The replay opens with its key for a moment")
    func keyHintIsBrief() {
        #expect(NotchPeek.demoKey.kind == .demoKey)
        #expect(NotchPeek.demoKey.duration == .seconds(2.5))
    }

    @Test("The pretend phone is paired over Bluetooth")
    func phoneIsPaired() async {
        var updates = MacDemoLink().pairingStatusUpdates().makeAsyncIterator()
        let status = await updates.next()
        #expect(status?.phase == .connected)
        #expect(status?.route == .bluetooth)
    }
}
#endif
