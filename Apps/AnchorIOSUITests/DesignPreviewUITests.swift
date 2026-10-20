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

    /// The desk board with the live-plan fixture from DesignPreviewFixtureTests:
    /// the current task's step large, the other tasks as chips.
    @MainActor
    func testLivePlanDeskBoard() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = "1A7E0000-7215-40E0-8B0B-000000000001"
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        guard app.descendants(matching: .any)["home.glance"].waitForExistence(timeout: 8) else {
            throw XCTSkip("Import the isolated live-plan-home repository first.")
        }
        capture("live-plan-home-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        let step = app.descendants(matching: .any)["ambient.step"]
        XCTAssertTrue(step.waitForExistence(timeout: 5))
        capture("desk-board")

        // A chip makes its task the one the person is on.
        let website = app.buttons["hosted.task.1A7E0000-7215-40E0-8B0B-000000000002"]
        XCTAssertTrue(website.exists)
        website.tap()
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in step.label.contains("做项目页") }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 5), .completed)
        capture("desk-board-switched")

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ambient.screen"].waitForExistence(timeout: 8))
        capture("desk-board-accessibility")
    }

    /// The desk board while the current task's agent works, and the card that
    /// interrupts when the phone is picked up, with the desk-wait fixture from
    /// DesignPreviewFixtureTests: "Meanwhile" names the task with a result to check.
    @MainActor
    func testDeskWaitAndPickUp() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = "DE5C0000-7215-40E0-8B0B-000000000099"
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        guard app.descendants(matching: .any)["home.glance"].waitForExistence(timeout: 8) else {
            throw XCTSkip("Import the isolated desk-wait repository first.")
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        let meanwhile = app.descendants(matching: .any)["ambient.meanwhile"]
        XCTAssertTrue(meanwhile.waitForExistence(timeout: 5))
        XCTAssertTrue(meanwhile.label.contains("个人网站"), meanwhile.label)
        capture("desk-wait-board")

        // Picking the phone up interrupts; using it anyway is a deliberate choice.
        XCUIDevice.shared.orientation = .portrait
        let card = app.descendants(matching: .any)["desk.pickup"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        capture("desk-pickup")
        app.buttons["desk.pickup.use-anyway"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["home.glance"].exists)

        // Each pick-up interrupts again, and the Meanwhile card switches to that task.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(meanwhile.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        app.descendants(matching: .any)["desk.pickup.meanwhile"].firstMatch.tap()
        let agent = app.descendants(matching: .any)["desk.pickup.agent"]
        let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            agent.exists && agent.label.contains("项目页")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 5), .completed)
        capture("desk-pickup-switched")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
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
