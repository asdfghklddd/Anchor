#if os(macOS)
import AnchorCore
import CoreGraphics
import Foundation
import Testing
@testable import AnchorMacFeatures

@Suite("Notch island")
struct NotchIslandTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let geometry = NotchIslandGeometry(
        notch: CGSize(width: 200, height: 32), notchMidX: 756, screenMaxY: 982, hasNotch: true)

    private func conversation(_ status: ProcessStatus, request: String? = nil, minutesAgo: Double = 1) -> AnchorProcess {
        AnchorProcess(sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                      title: "chat", status: status, updatedAt: now.addingTimeInterval(-minutesAgo * 60),
                      request: request)
    }

    private func task(_ title: String, color: Int, plan: AnchorUserPlan? = nil,
                      _ processes: [AnchorProcess] = []) -> AnchorSession {
        var task = AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "", userPlan: plan),
                                 processes: processes, taskColorIndex: color)
        task.captureJoiningOrder()
        return task
    }

    private func content(_ projection: SessionProjection, codex: Bool = true) -> NotchIslandContent {
        NotchIslandContent(
            status: AnchorStatusMenu(projection: projection, radio: .on, pairing: .automatic,
                                     codexReady: codex, claudeReady: false),
            projection: projection)
    }

    @Test("Pausing on the island opens it; passing by only swells it")
    func dwellOpens() {
        var hover = NotchHoverMachine()
        #expect(hover.pointerEntered() == .dwell)
        #expect(hover.phase == .primed)
        #expect(hover.pointerExited() == nil)
        #expect(hover.phase == .compact)
        hover.dwellElapsed()
        #expect(hover.phase == .compact)

        #expect(hover.pointerEntered() == .dwell)
        hover.dwellElapsed()
        #expect(hover.phase == .expanded)
    }

    @Test("Slipping out briefly keeps it open; staying out closes it")
    func graceKeepsItOpen() {
        var hover = NotchHoverMachine()
        _ = hover.pointerEntered()
        hover.dwellElapsed()
        #expect(hover.pointerExited() == .grace)
        _ = hover.pointerEntered()
        hover.graceElapsed()
        #expect(hover.phase == .expanded)

        #expect(hover.pointerExited() == .grace)
        hover.graceElapsed()
        #expect(hover.phase == .compact)
    }

    @Test("Opened from the keyboard it stays until dismissed, and hovering waits for a fresh visit")
    func keyboardPins() {
        var hover = NotchHoverMachine()
        hover.open(pinned: true)
        _ = hover.pointerEntered()
        #expect(hover.pointerExited() == nil)
        hover.graceElapsed()
        #expect(hover.phase == .expanded)

        _ = hover.pointerEntered()
        hover.dismiss()
        #expect(hover.phase == .compact)
        #expect(hover.pointerEntered() == nil)
        #expect(hover.phase == .compact)
        _ = hover.pointerExited()
        #expect(hover.pointerEntered() == .dwell)
    }

    @Test("The closed island wraps the housing with an ear per side that fits a dot per task")
    func compactWrapsTheHousing() {
        #expect(geometry.compactSize(dots: 1) == CGSize(width: 272, height: 32))
        // Three 8 pt dots, 9 pt apart, with 11 pt either side, on each ear.
        #expect(geometry.compactSize(dots: 3).width == 328)
        #expect(geometry.primedSize(dots: 1).height == 35)
        let frame = geometry.islandFrame(size: geometry.compactSize(dots: 1))
        #expect(frame.midX == 756)
        #expect(frame.maxY == 982)
        #expect(geometry.panelFrame.midX == 756)
        #expect(geometry.panelFrame.maxY == 982)
        #expect(geometry.panelFrame.width >= geometry.expandedWidth)
    }

    @MainActor
    @Test("The pointer zone follows the island's shape as it opens")
    func pointerZoneFollowsPhase() {
        let state = NotchIslandState(content: content(SessionProjection()), geometry: geometry)
        let closed = state.pointerZone
        #expect(closed.contains(CGPoint(x: 756, y: 975)))
        #expect(!closed.contains(CGPoint(x: 756, y: 900)))
        state.contentHeight = 160
        state.phase = .expanded
        #expect(state.islandSize == CGSize(width: 500, height: 192))
        #expect(state.pointerZone.contains(CGPoint(x: 756, y: 800)))
    }

    @Test("The current task carries its next step; the others follow, newest first, in their iPhone colors")
    func currentAndOthers() {
        let current = task("Notch", color: 0, plan: AnchorUserPlan(steps: ["Shape", "Hover"], completedSteps: [0]),
                           [conversation(.running, request: "make it frosted")])
        let older = task("Paper", color: 2, [conversation(.completed, minutesAgo: 40)])
        let waiting = task("Login", color: 1, [conversation(.needsDecision, request: "why 404", minutesAgo: 5)])
        let island = content(SessionProjection(session: current, additionalSessions: [older, waiting]))

        #expect(island.current?.title == "Notch")
        #expect(island.current?.signal == .running)
        #expect(island.current?.conversation?.request == "make it frosted")
        #expect(island.plan == .step(number: 2, total: 2, text: "Hover"))
        #expect(island.prompt != nil)
        #expect(island.others.map(\.title) == ["Login", "Paper"])
        #expect(island.others.map(\.colorIndex) == [1, 2])
        #expect(island.others.map(\.signal) == [.waiting, .done])
        #expect(island.tasks.count == 3)
    }

    @Test("Without agent folders the link needs the person, even while connected")
    func sourcesNeedThePerson() {
        let island = content(SessionProjection(connection: .connected), codex: false)
        #expect(island.isLinked)
        #expect(island.needsSources)
        #expect(island.linkNeedsAttention)
        #expect(island.current == nil)
        #expect(island.plan == .none)
    }
}
#endif
