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
        let screen = app.staticTexts["return.screen"]
        guard screen.waitForExistence(timeout: 8) else {
            throw XCTSkip("Run with the isolated repository exported by ReturnDataJourneyTests.")
        }
        snapshot("populated-top", app)
        XCTAssertTrue(app.staticTexts["return.goal.title"].exists)
        let context = app.buttons["return.context.button"]
        reveal(context, in: app)
        context.tap()
        XCTAssertTrue(app.descendants(matching: .any)["return.context.detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["先检查终端构建失败的原因；修复后重新运行回归测试，再确认返航摘要的内容。"].exists)
        snapshot("anchor-context", app)
        app.buttons["return.context.done"].tap()
        let allChanges = app.buttons["return.changes.all.button"]
        reveal(allChanges, in: app)
        allChanges.tap()
        XCTAssertTrue(app.descendants(matching: .any)["return.changes.list"].waitForExistence(timeout: 3))
        snapshot("all-return-changes", app)
        app.buttons["return.changes.done"].tap()
        let failed = app.descendants(matching: .any)["return.work.failed"]
        reveal(failed, in: app)
        XCTAssertTrue(failed.label.contains("1"), failed.label)
        let completed = app.descendants(matching: .any)["return.work.completed"]
        XCTAssertTrue(completed.label.contains("2"), completed.label)
        let attention = app.descendants(matching: .any)["return.work.attention"]
        XCTAssertTrue(attention.label.contains("2"), attention.label)
        let next = app.buttons["return.next.step"]
        reveal(next, in: app)
        snapshot("populated-bottom", app)
        next.tap()
        XCTAssertTrue(app.descendants(matching: .any)["return.process.detail"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Release 构建：检查签名配置与资源打包"].exists)
        snapshot("failed-task-detail", app)
        app.buttons["return.process.done"].tap()
        XCTAssertTrue(screen.exists)
        if !largeText {
            XCUIDevice.shared.orientation = .landscapeRight
            let landscapeReady = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    app.frame.width > app.frame.height && app.buttons["return.back.button"].isHittable
                }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [landscapeReady], timeout: 5), .completed)
            // UIKit's rotation updates geometry before its visual transition
            // finishes. Capture the settled layout, not an in-flight frame.
            let settled = expectation(description: "Landscape transition settled")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
            wait(for: [settled], timeout: 2)
            snapshot("populated-landscape", app)
            XCUIDevice.shared.orientation = .portrait
        }
        let back = app.buttons["return.back.button"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: back)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
        back.tap()
        XCTAssertTrue(screen.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["return.landscape.hint"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        // At accessibility sizes an element can be partly visible while its
        // tap center is behind the fixed Back control. Reveal the tap point.
        let lowerEdge = app.buttons["return.back.button"].frame.minY - 20
        for _ in 0..<16 {
            if element.isHittable, element.frame.midY > 100, element.frame.midY < lowerEdge { return }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.70))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            if element.exists && element.frame.midY < 100 {
                end.press(forDuration: 0.05, thenDragTo: start)
            } else {
                start.press(forDuration: 0.05, thenDragTo: end)
            }
        }
        XCTFail("Could not reveal \(element.identifier)")
    }

    @MainActor
    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
