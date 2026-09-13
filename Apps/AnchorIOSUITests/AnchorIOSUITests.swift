import XCTest

final class AnchorIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreatesAndRestoresAFormalTask() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(element("workspace.screen", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("workspace.empty.processes", in: app).exists)

        let anchorButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchorButton.waitForExistence(timeout: 3))
        anchorButton.tap()

        XCTAssertTrue(element("setup.screen", in: app).waitForExistence(timeout: 3))
        type("Production UI test task", into: element("setup.goal.field", in: app))
        type("The task remains after relaunch", into: element("setup.criteria.field", in: app))
        type("Build the formal experience", into: element("setup.process.field.0", in: app))

        let startButton = app.buttons["setup.start.button"]
        XCTAssertTrue(startButton.isEnabled)
        startButton.tap()

        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        XCTAssertEqual(element("goal.title", in: app).label, "Production UI test task")
        XCTAssertFalse(element("workspace.empty.processes", in: app).exists)

        app.terminate()
        app.launch()

        let restoredGoal = element("goal.title", in: app)
        XCTAssertTrue(restoredGoal.waitForExistence(timeout: 8))
        XCTAssertEqual(restoredGoal.label, "Production UI test task")
        XCTAssertTrue(app.staticTexts["Build the formal experience"].exists)
    }

    @MainActor
    func testSetupRequiresGoalCriteriaAndProcess() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(element("workspace.connection.status", in: app).waitForExistence(timeout: 8))
        app.buttons["workspace.connection.action"].tap()
        XCTAssertTrue(element("connections.screen", in: app).waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()

        let anchorButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchorButton.waitForExistence(timeout: 8))
        anchorButton.tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForExistence(timeout: 3))

        let startButton = app.buttons["setup.start.button"]
        XCTAssertFalse(startButton.isEnabled)

        type("Validated task", into: element("setup.goal.field", in: app))
        XCTAssertFalse(startButton.isEnabled)

        type("All required fields are present", into: element("setup.criteria.field", in: app))
        XCTAssertFalse(startButton.isEnabled)

        type("Run validation", into: element("setup.process.field.0", in: app))
        XCTAssertTrue(startButton.isEnabled)
    }

    @MainActor
    func testFinalConfirmationClearsCurrentWorkAndRestoresDetailedHistory() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        let anchorButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchorButton.waitForExistence(timeout: 8))
        anchorButton.tap()
        type("Archived production task", into: element("setup.goal.field", in: app))
        type("The full task remains available in history", into: element("setup.criteria.field", in: app))
        type("Validate the final boundary", into: element("setup.process.field.0", in: app))
        app.buttons["setup.start.button"].tap()

        let finishShortcut = app.buttons["mission.finish.button"]
        XCTAssertTrue(finishShortcut.waitForExistence(timeout: 5))
        finishShortcut.tap()
        let finishButton = app.buttons["session.finish.button"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
        finishButton.tap()
        let confirmation = app.buttons
            .matching(identifier: "session.finish.confirm")
            .firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()

        XCTAssertTrue(element("workspace.empty.processes", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Archived production task"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(element("workspace.empty.processes", in: app).waitForExistence(timeout: 8))

        app.buttons["topbar.profile.button"].tap()
        let historyButton = app.buttons["profile.history.button"]
        if !historyButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(historyButton.waitForExistence(timeout: 3))
        historyButton.tap()

        XCTAssertTrue(element("history.screen", in: app).waitForExistence(timeout: 3))
        let archivedTitle = app.staticTexts["Archived production task"]
        XCTAssertTrue(archivedTitle.waitForExistence(timeout: 3))
        archivedTitle.tap()
        XCTAssertTrue(element("history.detail.screen", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["The full task remains available in history"].exists)
        XCTAssertTrue(app.staticTexts["Validate the final boundary"].exists)
    }

    @MainActor
    private func isolatedApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = UUID().uuidString
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    @MainActor
    private func type(_ text: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 3))
        element.tap()
        element.typeText(text)
    }
}
