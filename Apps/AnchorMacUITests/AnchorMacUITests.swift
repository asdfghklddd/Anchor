import XCTest

final class AnchorMacUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testEmptyWorkspaceKeepsSourceSetupReachable() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        openWorkspace(from: app)
        XCTAssertTrue(element("mac.empty.screen", in: app).waitForExistence(timeout: 5))

        openNavigation(in: app)
        app.buttons["mac.section.settings"].click()
        XCTAssertTrue(element("mac.settings.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("mac.sources.summary", in: app).exists)
        XCTAssertTrue(element("mac.sources.setup", in: app).exists)
    }

    @MainActor
    func testSidebarStartsCollapsedAndShowsOnlyThreeSections() throws {
        let app = isolatedApplication(seedSession: true)
        defer { app.terminate() }
        app.launch()

        openWorkspace(from: app)
        let toggle = app.buttons["mac.sidebar.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["mac.section.current"].exists)

        toggle.click()
        XCTAssertTrue(app.buttons["mac.section.current"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mac.section.history"].exists)
        XCTAssertTrue(app.buttons["mac.section.settings"].exists)
        XCTAssertFalse(app.buttons["mac.section.timeline"].exists)
        XCTAssertFalse(app.buttons["mac.section.sources"].exists)

        app.buttons["mac.section.current"].click()
        XCTAssertFalse(app.buttons["mac.section.current"].exists)

        toggle.click()
        XCTAssertTrue(app.buttons["mac.section.current"].waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(app.buttons["mac.section.current"].exists)
    }

    @MainActor
    func testExpandedSidebarDoesNotInterceptContentActions() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        openWorkspace(from: app)
        openNavigation(in: app)
        let pairButton = app.buttons["mac.empty.pair.button"]
        XCTAssertTrue(pairButton.waitForExistence(timeout: 5))
        // One click must navigate, even while the sidebar remains expanded.
        pairButton.click()
        XCTAssertTrue(element("mac.settings.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["mac.section.settings"].exists)
    }

    @MainActor
    func testRestingEdgeEntryStillOpensWorkspace() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        let edgeEntry = app.buttons["mac.edge.entry"]
        XCTAssertTrue(edgeEntry.waitForExistence(timeout: 8))

        let restDelay = expectation(description: "The edge entry reaches its resting state")
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.5) {
            restDelay.fulfill()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [restDelay], timeout: 6), .completed)

        edgeEntry.click()
        XCTAssertTrue(element("mac.current.screen", in: app).waitForExistence(timeout: 8))
    }

    @MainActor
    @available(macOS 14.0, *)
    func testWorkspacePassesAccessibilityAudit() throws {
        try auditWorkspace(appearance: "Light")
    }

    @MainActor
    @available(macOS 14.0, *)
    func testDarkWorkspacePassesAccessibilityAudit() throws {
        try auditWorkspace(appearance: "Dark")
    }

    @MainActor
    @available(macOS 14.0, *)
    private func auditWorkspace(appearance: String) throws {
        let app = isolatedApplication(seedSession: true)
        // Override only the test app's appearance, never the system preference.
        app.launchEnvironment["ANCHOR_UI_TEST_APPEARANCE"] = appearance
        defer { app.terminate() }
        app.launch()

        openWorkspace(from: app)
        XCTAssertTrue(element("mac.current.screen", in: app).waitForExistence(timeout: 8))
        try app.performAccessibilityAudit()
        openNavigation(in: app)
        try app.performAccessibilityAudit()
    }

    @MainActor
    private func openWorkspace(from app: XCUIApplication) {
        let edgeEntry = app.buttons["mac.edge.entry"]
        XCTAssertTrue(edgeEntry.waitForExistence(timeout: 8))
        edgeEntry.click()
    }

    @MainActor
    private func openNavigation(in app: XCUIApplication) {
        let toggle = app.buttons["mac.sidebar.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        toggle.click()
        XCTAssertTrue(app.buttons["mac.section.current"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func isolatedApplication(seedSession: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = UUID().uuidString
        if seedSession {
            app.launchEnvironment["ANCHOR_LOCAL_VALIDATION_SEED_SESSION"] = "1"
        }
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
