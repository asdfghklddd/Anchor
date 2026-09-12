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
