import XCTest

/// Captures the home with the isolated DesignPreviewFixtureTests repository.
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
        let glance = app.descendants(matching: .any)["home.anchoring.clock"]
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'hosted.task.'")).firstMatch
        guard glance.waitForExistence(timeout: 8), card.waitForExistence(timeout: 4) else {
            throw XCTSkip("Import the isolated DesignPreviewFixtureTests repository first.")
        }
        capture("glance-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["ambient.task.library"].waitForExistence(timeout: 4))
        capture("glance-landscape")

        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(glance.waitForExistence(timeout: 8))
        capture("glance-accessibility")
    }

    /// The desk board with the live-plan fixture from DesignPreviewFixtureTests:
    /// each task a column in the task library, its conversation in front.
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
        guard app.descendants(matching: .any)["home.anchoring.clock"].waitForExistence(timeout: 8) else {
            throw XCTSkip("Import the isolated live-plan-home repository first.")
        }
        capture("live-plan-home-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.descendants(matching: .any)["ambient.task.library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["hosted.task.1A7E0000-7215-40E0-8B0B-000000000002"].exists)
        capture("desk-board")

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
        guard app.descendants(matching: .any)["home.anchoring.clock"].waitForExistence(timeout: 8) else {
            throw XCTSkip("Import the isolated desk-wait repository first.")
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        let library = app.descendants(matching: .any)["ambient.task.library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        capture("desk-wait-board")

        // Picking the phone up interrupts; using it anyway is a deliberate choice.
        XCUIDevice.shared.orientation = .portrait
        let card = app.descendants(matching: .any)["desk.pickup"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        capture("desk-pickup")
        app.buttons["desk.pickup.use-anyway"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["home.anchoring.clock"].exists)

        // Each pick-up interrupts again, and the Meanwhile card switches to that task.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(library.waitForExistence(timeout: 5))
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

    /// The task library with the fixture from DesignPreviewFixtureTests: three
    /// tasks, each with its newest conversations stacked; a card behind comes
    /// to the front when tapped.
    @MainActor
    func testTaskLibrary() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = "1B7A0000-7215-40E0-8B0B-000000000099"
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        defer { app.terminate(); XCUIDevice.shared.orientation = .portrait }
        guard app.descendants(matching: .any)["home.anchoring.clock"].waitForExistence(timeout: 8) else {
            throw XCTSkip("Import the isolated task-library repository first.")
        }

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.descendants(matching: .any)["ambient.task.library"].waitForExistence(timeout: 5))
        let front = app.buttons["ambient.conversation.1B7A0000-7215-40E0-8B0B-000000000033"]
        let behind = app.buttons["ambient.conversation.1B7A0000-7215-40E0-8B0B-000000000031"]
        XCTAssertTrue(front.waitForExistence(timeout: 3))
        XCTAssertTrue(front.isSelected)
        XCTAssertFalse(behind.isSelected)
        capture("task-library")

        // Only the top strip of a card behind shows; the card in front covers the rest.
        behind.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).tap()
        let picked = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in behind.isSelected && !front.isSelected },
                                               object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [picked], timeout: 3), .completed)
        capture("task-library-picked")

        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["ambient.screen"].waitForExistence(timeout: 8))
        capture("task-library-accessibility")
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
