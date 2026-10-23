import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@Suite("Floating boat")
struct AnchorEdgeDockTests {
    private let screen = CGRect(x: 0, y: 80, width: 1440, height: 800)

    @Test("A boat let go on either half settles on that side, at the height it was dropped")
    func snapsToNearerSide() {
        let left = AnchorEdgeDock.nearest(to: CGRect(x: 500, y: 500, width: 88, height: 88), in: screen,
                                          columnHeight: 150)
        #expect(left.side == .leading)
        let frame = left.controlFrame(in: screen, controlSide: 88, columnHeight: 150)
        #expect(frame.minX == screen.minX)
        #expect(abs(frame.maxY - 588) < 0.001)

        let right = AnchorEdgeDock.nearest(to: CGRect(x: 900, y: 500, width: 88, height: 88), in: screen,
                                           columnHeight: 150)
        #expect(right.side == .trailing)
        #expect(right.controlFrame(in: screen, controlSide: 88, columnHeight: 150).maxX == screen.maxX)
    }

    @Test("The water column stays above the Dock and the boat below the menu bar")
    func staysOnScreen() {
        let low = AnchorEdgeDock.nearest(to: CGRect(x: 1400, y: -300, width: 88, height: 88), in: screen,
                                         columnHeight: 150)
        #expect(low.controlFrame(in: screen, controlSide: 88, columnHeight: 150).maxY == screen.minY + 150)
        let high = AnchorEdgeDock.nearest(to: CGRect(x: 1400, y: 5000, width: 88, height: 88), in: screen,
                                          columnHeight: 150)
        #expect(high.controlFrame(in: screen, controlSide: 88, columnHeight: 150).maxY == screen.maxY)
    }

    @Test("The berth is remembered, and a fresh Mac starts in the lower-right corner")
    func remembersBerth() throws {
        let defaults = try #require(UserDefaults(suiteName: "anchor.edge.dock.\(UUID())"))
        #expect(AnchorEdgeDock.load(from: defaults) == .standard)
        AnchorEdgeDock(side: .leading, height: 0.4).save(to: defaults)
        #expect(AnchorEdgeDock.load(from: defaults) == AnchorEdgeDock(side: .leading, height: 0.4))
    }

    @Test("The buttons offer the current task's next step, and list the current task first")
    func menuContent() {
        var current = AnchorSession(goal: AnchorGoal(title: "Portfolio", completionCriteria: ""))
        current.goal.userPlan = AnchorUserPlan(steps: ["Sketch", "Build", "Ship"], completedSteps: [0])
        let other = AnchorSession(goal: AnchorGoal(title: "Homework", completionCriteria: ""))
        let projection = SessionProjection(session: current, additionalSessions: [other])

        let menu = AnchorEdgeMenu(projection: projection)

        #expect(menu.nextStep == AnchorEdgeMenu.NextStep(number: 2, total: 3, text: "Build"))
        #expect(menu.prompt?.contains("Build") == true)
        #expect(menu.rows.map(\.task.goal.title) == ["Portfolio", "Homework"])
        #expect(!menu.isPhoneConnected)
    }
}
