import XCTest

final class AnchorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesWithAnchorTitle() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Anchor"].waitForExistence(timeout: 5))
    }
}
