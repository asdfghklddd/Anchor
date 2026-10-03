import XCTest

/// A validation runner imports the Core test's repository into this disposable store and removes it afterwards.
final class DashboardReadabilityUITests: XCTestCase {
    @MainActor
    func testProgressReadabilityAcrossLayouts() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = "CA720001-7215-40E0-8B0B-000000000100"
        // The runner selects the simulator's real system appearance before this test.
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let unknown = card(1, in: app)
        guard unknown.waitForExistence(timeout: 8) else {
            throw XCTSkip("Import the isolated DashboardReadabilityJourneyTests repository first.")
        }
        assertProgress(in: app)
        capture("progress-portrait")
        XCUIDevice.shared.orientation = .landscapeRight
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        assertProgress(in: app)
        capture("progress-landscape")
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(unknown.waitForExistence(timeout: 8))
        app.swipeUp()
        capture("progress-accessibility")
        // The first card has scrolled under the fixed header; open a fully visible card.
        let measured = card(3, in: app)
        XCTAssertTrue(measured.isHittable)
        measured.tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.detail.session"].waitForExistence(timeout: 5))
    }

    @MainActor private func assertProgress(in app: XCUIApplication) {
        for (index, expected) in ["未知", "0%", "63%", "100%"].enumerated() {
            let task = card(index + 1, in: app)
            XCTAssertTrue(task.exists)
            XCTAssertTrue((task.value as? String ?? "").contains(expected), "\(index): \(task.debugDescription)")
        }
    }

    @MainActor private func card(_ index: Int, in app: XCUIApplication) -> XCUIElement {
        let id = String(format: "CA720001-7215-40E0-8B0B-%012d", index)
        return app.buttons["hosted.task.\(id)"]
    }

    @MainActor private func capture(_ name: String) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
