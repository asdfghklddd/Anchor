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
        try app.performAccessibilityAudit()
    }
}
