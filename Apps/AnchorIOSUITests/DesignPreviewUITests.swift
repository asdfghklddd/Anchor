import XCTest

/// Captures the home glance with the isolated DesignPreviewFixtureTests repository.
/// A preview runner imports that repository first and removes it afterwards.
final class DesignPreviewUITests: XCTestCase {
    private let storageID = "DE51A000-7215-40E0-8B0B-000000000099"

    @MainActor
    func testHomeGlanceAcrossLayouts() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = storageID
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        let glance = app.descendants(matching: .any)["home.glance"]
        guard glance.waitForExistence(timeout: 8),
              app.descendants(matching: .any)["home.glance.latest"].waitForExistence(timeout: 4) else {
            throw XCTSkip("Import the isolated DesignPreviewFixtureTests repository first.")
        }
        capture("glance-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["ambient.glance"].waitForExistence(timeout: 4))
        capture("glance-landscape")

        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(glance.waitForExistence(timeout: 8))
        capture("glance-accessibility")
    }

    @MainActor private func capture(_ name: String) {
        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { settled.fulfill() }
        wait(for: [settled], timeout: 2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
