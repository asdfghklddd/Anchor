import XCTest

/// The validation runner imports a generated event repository into these two
/// disposable storage IDs, then removes it. Production app code has no fixture path.
final class PopulatedReturnUITests: XCTestCase {
    @MainActor
    func testPopulatedReturnReview() throws {
        try review(largeText: false)
    }

    @MainActor
    func testPopulatedReturnReviewAtAccessibilitySize() throws {
        try review(largeText: true)
    }

    @MainActor
    private func review(largeText: Bool) throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = largeText
            ? "8EAB749A-9806-4D96-9577-10AA97049D4D" : "8EAB749A-9806-4D96-9577-10AA97049D4C"
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        defer { app.terminate() }
        let screen = app.descendants(matching: .any)["return.screen"]
        guard screen.waitForExistence(timeout: 8) else {
            throw XCTSkip("Run with the isolated repository exported by ReturnDataJourneyTests.")
        }
        snapshot("return-first-page", app)
        let back = app.buttons["return.back.button"]
        // Pages turn sideways; Back to Home answers only on the last one.
        for page in 0..<3 where !back.isHittable {
            app.swipeLeft()
            snapshot("return-page-\(page + 2)", app)
        }
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: back)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        back.tap()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 5))
        // Without a connected Mac there is no landscape invitation (WorkInvitationTests).
        XCTAssertFalse(app.descendants(matching: .any)["work.invitation"].exists)
    }

    @MainActor
    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
