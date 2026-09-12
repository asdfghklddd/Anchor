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

        let currentSection = app.buttons["mac.section.current"]
        XCTAssertTrue(currentSection.waitForExistence(timeout: 8))
        currentSection.click()
        XCTAssertTrue(element("mac.empty.screen", in: app).waitForExistence(timeout: 5))

        app.buttons["mac.section.sources"].click()
        XCTAssertTrue(element("mac.sources.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("mac.sources.summary", in: app).exists)
    }

    @MainActor
    func testCompletionWaitsForConfirmationThenLeavesCurrentWork() throws {
        let app = isolatedApplication(seedSession: true)
        defer { app.terminate() }
        app.launch()

        let currentSection = app.buttons["mac.section.current"]
        XCTAssertTrue(currentSection.waitForExistence(timeout: 8))
        currentSection.click()
        XCTAssertTrue(element("mac.current.screen", in: app).waitForExistence(timeout: 8))

        let finishButton = app.buttons["mac.session.finish.button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.click()

        XCTAssertTrue(element("mac.session.summary", in: app).waitForExistence(timeout: 5))
        app.buttons["mac.session.summary.action"].click()
        XCTAssertFalse(element("mac.empty.screen", in: app).exists)

        let confirmButton = app.buttons["mac.session.summary.confirm"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.click()
        XCTAssertTrue(element("mac.empty.screen", in: app).waitForExistence(timeout: 8))

        app.buttons["mac.section.history"].click()
        XCTAssertTrue(element("mac.history.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mac local validation"].exists)
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
