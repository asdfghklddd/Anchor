import XCTest

final class AnchorIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWorkspaceFollowsLandscapeRotation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer {
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
        app.launch()

        XCTAssertTrue(element("workspace.screen", in: app).waitForExistence(timeout: 8))

        // The ambient workspace is the primary landscape experience.
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(element("ambient.screen", in: app).waitForExistence(timeout: 8))

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(element("workspace.screen", in: app).waitForExistence(timeout: 8))
    }

    @MainActor
    func testLandscapeSuspendsSetupAndRestoresDraft() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer {
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()
        let title = element("setup.goal.field", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        type("Keep my landscape draft", into: title)

        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(element("ambient.screen", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("ambient.time", in: app).exists)
        XCTAssertTrue(element("ambient.task.library", in: app).exists)

        XCUIDevice.shared.orientation = .portrait
        let restored = element("setup.goal.field", in: app)
        XCTAssertTrue(restored.waitForExistence(timeout: 8))
        XCTAssertEqual(restored.value as? String, "Keep my landscape draft")
    }

    @MainActor
    func testCreatesAndRestoresAFormalTask() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer {
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
        app.launch()

        XCTAssertTrue(element("workspace.screen", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(element("workspace.empty.processes", in: app).exists)

        let anchorButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchorButton.waitForExistence(timeout: 3))
        anchorButton.tap()

        XCTAssertTrue(element("setup.screen", in: app).waitForExistence(timeout: 3))
        capture("Anchor input", app: app)
        type("Production UI test task", into: element("setup.goal.field", in: app))
        advanceSetup(in: app)
        type("The task remains after relaunch", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        type("Build the formal experience", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)

        capture("Anchor review", app: app)
        let startButton = app.buttons["setup.start.button"]
        XCTAssertTrue(startButton.isEnabled)
        startButton.tap()

        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Production UI test task"].exists)
        XCTAssertFalse(element("workspace.empty.processes", in: app).exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 1)
        XCTAssertFalse(element("processes.observed.section", in: app).exists)
        XCTAssertFalse(element("processes.environment.summary", in: app).exists)

        app.terminate()
        app.launch()

        let restoredGoal = app.buttons["Production UI test task"]
        XCTAssertTrue(restoredGoal.waitForExistence(timeout: 8))
        XCTAssertEqual(restoredGoal.label, "Production UI test task")
        XCTAssertTrue(app.buttons["Production UI test task"].exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 1)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(element("ambient.screen", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Production UI test task"].exists)
        XCTAssertTrue(app.buttons["ambient.tasks.manage"].exists)
        app.buttons["ambient.tasks.manage"].tap()
        XCTAssertTrue(app.buttons["hosted.tasks.create"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testConnectionCardRepeatedPresentationAndSwipeDismissal() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()
        let trigger = app.buttons["workspace.connection.action"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 8))
        for cycle in 0..<3 {
            trigger.tap()
            let card = element("connections.screen", in: app)
            XCTAssertTrue(card.waitForExistence(timeout: 3))
            if cycle == 1 {
                // Native sheet gestures must remain interruptible after adding content motion.
                card.swipeDown()
            } else {
                app.buttons["connections.close"].tap()
            }
            XCTAssertTrue(card.waitForNonExistence(timeout: 3))
            XCTAssertTrue(trigger.isHittable)
        }
    }

    @MainActor
    func testConnectionCardKeepsHomeAndCanRetry() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer {
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
        app.launch()
        XCTAssertTrue(app.buttons["workspace.connection.action"].waitForExistence(timeout: 8))
        app.buttons["workspace.connection.action"].tap()
        let card = element("connections.screen", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertLessThan(card.frame.height, app.frame.height * 0.65)
        XCTAssertGreaterThan(card.frame.minY, app.frame.height * 0.3)
        XCTAssertTrue(app.buttons["connections.primary"].exists)
        app.buttons["connections.primary"].tap()
        XCTAssertTrue(app.buttons["connections.close"].exists)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        XCTAssertLessThan(card.frame.height, app.frame.height * 0.9)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["connections.close"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["workspace.connection.action"].isHittable)
    }

    @MainActor
    func testSetupRequiresThreeUserSegmentsWithoutMacProcesses() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        XCTAssertTrue(app.buttons["workspace.connection.action"].waitForExistence(timeout: 8))
        app.buttons["workspace.connection.action"].tap()
        XCTAssertTrue(element("connections.screen", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(element("connections.pairing.automatic", in: app).exists)
        XCTAssertFalse(element("connections.pairing.code", in: app).exists)
        app.buttons["connections.close"].tap()
        XCTAssertTrue(element("connections.screen", in: app).waitForNonExistence(timeout: 3))

        let anchorButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchorButton.waitForExistence(timeout: 8))
        anchorButton.tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForExistence(timeout: 3))

        capture("Visual 01 goal empty", app: app)
        let card = element("setup.input.card", in: app)
        XCTAssertEqual(card.frame.width, app.frame.width - 40, accuracy: 1)
        XCTAssertEqual(card.frame.height, 346, accuracy: 2)
        XCTAssertEqual(card.frame.minY, 241, accuracy: 3)
        app.buttons["setup.photos.button"].tap()
        let cancelPhotos = app.buttons["取消"].waitForExistence(timeout: 3) ? app.buttons["取消"] : app.buttons["Cancel"]
        XCTAssertTrue(cancelPhotos.waitForExistence(timeout: 5))
        capture("Visual 08 system photo picker", app: app)
        cancelPhotos.tap()
        let nextButton = app.buttons["setup.next.button"]
        XCTAssertFalse(nextButton.isEnabled)
        XCTAssertFalse(element("setup.process.field.0", in: app).exists)
        app.buttons["setup.keyboard.button"].tap()
        type("完成 Anchor 首页重新设计", into: element("setup.goal.field", in: app))
        capture("Visual 07 keyboard", app: app)
        app.buttons["setup.keyboard.done"].tap()
        capture("Visual 02 goal filled", app: app)
        advanceSetup(in: app)
        capture("Visual 03 criteria empty", app: app)
        XCTAssertFalse(nextButton.isEnabled)
        type("信息层级明确\n完成可演示的首页原型\n这周内完成", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        capture("Visual 04 steps empty", app: app)
        XCTAssertFalse(nextButton.isEnabled)
        type("梳理现有信息架构\n确定首页内容层级\n完成视觉设计\n制作交互原型", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)
        XCTAssertTrue(app.buttons["setup.start.button"].isEnabled)
        app.buttons["setup.edit.0"].tap()
        XCTAssertEqual(element("setup.goal.field", in: app).value as? String, "完成 Anchor 首页重新设计")
        advanceSetup(in: app)
        XCTAssertTrue(app.buttons["setup.start.button"].isEnabled)
        capture("Visual 05 review", app: app)
        app.swipeUp()
        capture("Visual 09 review bottom", app: app)
        app.buttons["setup.start.button"].tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        let task = app.buttons["完成 Anchor 首页重新设计"]
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.tap()
        XCTAssertTrue(element("task.saved.plan", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["制作交互原型"].exists)
        app.terminate()
        app.launchEnvironment["ANCHOR_SETUP_VISUAL_RECORDING"] = "1"
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()
        type("今天计划完成竞品分析初步调研，上午还有一个小组工作会议。", into: element("setup.goal.field", in: app))
        app.buttons["setup.keyboard.done"].tap()
        capture("Visual 06 recording appearance only", app: app)
        XCTAssertTrue(app.buttons["setup.voice.input.button"].exists)



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
        advanceSetup(in: app)
        type("The full task remains available in history", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        type("Validate the final boundary", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)
        app.buttons["setup.start.button"].tap()

        let taskCard = app.buttons["Archived production task"]
        XCTAssertTrue(taskCard.waitForExistence(timeout: 5))
        taskCard.tap()
        let finishShortcut = app.buttons["profile.session.finish.button"]
        XCTAssertTrue(finishShortcut.waitForExistence(timeout: 5))
        if !finishShortcut.isHittable { app.swipeUp() }
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
    func testOldWorkspaceCanContinueOrStartNewWorkWithoutClaimingCompletion() throws {
        XCUIDevice.shared.orientation = .portrait
        let storageID = UUID()
        let app = isolatedApplication(
            storageID: storageID,
            recoveryReviewInterval: 0
        )
        defer { app.terminate() }
        app.launch()

        let anchorButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchorButton.waitForExistence(timeout: 8))
        anchorButton.tap()
        type("Long-running task", into: element("setup.goal.field", in: app))
        advanceSetup(in: app)
        type("Review before continuing", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        type("Preserve unfinished work", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)
        app.buttons["setup.start.button"].tap()

        XCTAssertTrue(element("recovery.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["recovery.continue.button"].exists)
        XCTAssertTrue(app.buttons["recovery.new.button"].exists)
        XCTAssertTrue(app.buttons["recovery.complete.button"].exists)
        app.buttons["recovery.continue.button"].tap()

        XCTAssertTrue(element("recovery.screen", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Long-running task"].exists)

        app.terminate()
        app.launch()
        XCTAssertTrue(element("recovery.screen", in: app).waitForExistence(timeout: 8))
        app.buttons["recovery.new.button"].tap()

        XCTAssertTrue(element("setup.screen", in: app).waitForExistence(timeout: 5))
        app.buttons["setup.close.button"].tap()
        XCTAssertTrue(element("workspace.empty.processes", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Long-running task"].exists)

        app.buttons["topbar.profile.button"].tap()
        let historyButton = app.buttons["profile.history.button"]
        if !historyButton.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(historyButton.waitForExistence(timeout: 3))
        historyButton.tap()
        XCTAssertTrue(app.staticTexts["Long-running task"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testHostsTwoTasksAndRestoresEditedNickname() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()
        for title in ["HKUST essay", "Portfolio"] {
            let anchor = app.buttons["anchor.note.button"]
            XCTAssertTrue(anchor.waitForExistence(timeout: 8))
            anchor.tap()
            type(title, into: element("setup.goal.field", in: app))
            advanceSetup(in: app)
            type("Reviewed", into: element("setup.criteria.field", in: app))
            advanceSetup(in: app)
            type("Main conversation", into: element("setup.steps.field", in: app))
            advanceSetup(in: app)
            app.buttons["setup.start.button"].tap()
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 2)
        app.buttons["topbar.profile.button"].tap()
        app.buttons["profile.account.button"].tap()
        let name = app.textFields["profile.name.field"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "ANDY TEST")
        app.buttons["profile.save.button"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["workspace.connection.action"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["workspace.connection.action"].label.contains("ANDY TEST"))
        XCTAssertTrue(app.buttons["HKUST essay"].exists)
        XCTAssertTrue(app.buttons["Portfolio"].exists)
    }

    @MainActor
    private func isolatedApplication(
        storageID: UUID = UUID(),
        recoveryReviewInterval: TimeInterval? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = storageID.uuidString
        if let recoveryReviewInterval {
            app.launchEnvironment["ANCHOR_UI_TEST_RECOVERY_INTERVAL"] = String(
                recoveryReviewInterval
            )
        }
        return app
    }

    @MainActor
    private func advanceSetup(in app: XCUIApplication) {
        let keyboardNext = app.buttons["setup.keyboard.next"]
        if keyboardNext.exists { keyboardNext.tap() }
        else { app.buttons["setup.next.button"].tap() }
    }

    @MainActor
    private func capture(_ name: String, app: XCUIApplication) {
        // Let the keyboard dismissal finish before recording visual evidence.
        Thread.sleep(forTimeInterval: 0.5)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
