import XCTest

final class AnchorMacUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCurrentWorkWindow() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "active"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.current.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["mac.current.goal"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["mac.inspector.no-attention"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testReturningNextStepJumpsToProcessWorkspace() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "returning"
        app.launch()

        XCTAssertTrue(app.buttons["mac.return.next"].waitForExistence(timeout: 5))
        app.buttons["mac.return.next"].click()

        let processCard = app.buttons["mac.current.process"].firstMatch
        XCTAssertTrue(processCard.waitForExistence(timeout: 5))
        XCTAssertTrue(processCard.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["mac.current.inspector"].exists)
    }

    @MainActor
    func testEmptyWorkspaceOffersNextActions() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "empty"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.empty.screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mac.empty.pair.button"].exists)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testEmptyTimelineOffersPairingAction() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "empty"
        app.launch()

        app.buttons["mac.section.timeline"].click()
        XCTAssertTrue(app.buttons["mac.timeline.pair.button"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testStaleWorkspaceExplainsDataAge() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "staleData"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.freshness.banner"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testCompletedWorkspaceOffersResume() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "completed"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.completion.banner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mac.completion.resume"].exists)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testDecisionWorkspaceSurfacesPriorityAction() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "needsDecision"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.priority.card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mac.priority.open"].exists)
        XCTAssertTrue(app.buttons["mac.decision.confirm"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testSourcesKeepHealthStatusWithSourceCard() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "active"
        app.launch()

        XCTAssertTrue(app.buttons["mac.section.sources"].waitForExistence(timeout: 5))
        app.buttons["mac.section.sources"].click()
        XCTAssertTrue(app.descendants(matching: .any)["mac.sources.screen"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptySourcesOffersPairingAction() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "empty"
        app.launch()

        app.buttons["mac.section.sources"].click()
        XCTAssertTrue(app.buttons["mac.sources.pair.button"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testSourceCardOpensProgressAndActivityDetails() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "active"
        app.launch()

        app.buttons["mac.section.sources"].click()
        let sourceCard = app.buttons["mac.sources.card"].firstMatch
        XCTAssertTrue(sourceCard.waitForExistence(timeout: 5))
        sourceCard.click()

        XCTAssertTrue(app.descendants(matching: .any)["mac.source.detail"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Claude"].exists)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testAwayWorkspaceKeepsRemoteWorkVisible() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "away18Minutes"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.presence.memory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mac.presence.continue"].exists)
    }

    @MainActor
    func testReturningWorkspaceSurfacesMemoryAndNextStep() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "returning"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["mac.presence.memory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mac.return.next"].exists)
        app.buttons["mac.return.changes"].click()
    }

    @MainActor
    func testHistorySnapshotOpensRecoverableContext() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_DEMO_SCENARIO"] = "returning"
        app.launch()

        app.buttons["mac.section.history"].click()
        XCTAssertTrue(app.buttons["mac.history.snapshot"].waitForExistence(timeout: 5))
        app.buttons["mac.history.snapshot"].click()
        XCTAssertTrue(app.descendants(matching: .any)["mac.snapshot.detail"].waitForExistence(timeout: 5))
    }
}
