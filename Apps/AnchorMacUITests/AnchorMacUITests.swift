import XCTest

final class AnchorMacUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPointingAtTheIslandReachesSettings() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        openSettings(in: app)
        let showCode = app.buttons["mac.pairing.show.code"]
        XCTAssertTrue(showCode.waitForExistence(timeout: 5), app.debugDescription)
        showCode.click()
        XCTAssertTrue(app.buttons["mac.pairing.copy"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(element("mac.sources.setup.agents.authorize", in: app).exists)
        XCTAssertTrue(app.buttons["settings.quit"].exists)
    }

    @MainActor
    @available(macOS 14.0, *)
    func testSettingsPassAccessibilityAudit() throws {
        try auditSettings(appearance: "Light")
    }

    @MainActor
    @available(macOS 14.0, *)
    func testDarkSettingsPassAccessibilityAudit() throws {
        try auditSettings(appearance: "Dark")
    }

    @MainActor
    @available(macOS 14.0, *)
    private func auditSettings(appearance: String) throws {
        let app = isolatedApplication(seedSession: true)
        // Override only the test app's appearance, never the system preference.
        app.launchEnvironment["ANCHOR_UI_TEST_APPEARANCE"] = appearance
        defer { app.terminate() }
        app.launch()

        openSettings(in: app)
        try app.performAccessibilityAudit()
    }

    /// Rests the pointer on the island so it opens, then takes its gear.
    @MainActor
    private func openSettings(in app: XCUIApplication) {
        // The phone icon only appears once the pointer reaches the island,
        // so rest on the task pills beside the housing.
        let tasks = element("notch.tasks", in: app)
        XCTAssertTrue(tasks.waitForExistence(timeout: 8), app.debugDescription)
        tasks.hover()
        let gear = app.buttons["notch.settings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5), app.debugDescription)
        gear.click()
        XCTAssertTrue(element("mac.settings.screen", in: app).waitForExistence(timeout: 5))
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
