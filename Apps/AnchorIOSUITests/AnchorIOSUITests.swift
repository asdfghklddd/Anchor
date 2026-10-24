import XCTest

final class AnchorIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testClosingSetupKeepsDraftUntilDiscardOrSuccessfulCreation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()
        let create = app.buttons["anchor.note.button"]
        XCTAssertTrue(create.waitForExistence(timeout: 8))
        create.tap()
        type("Keep this draft", into: element("setup.goal.field", in: app))
        type("Keep my plan too", into: element("setup.steps.field", in: app))
        app.buttons["setup.close.button"].tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        create.tap()
        let plan = element("setup.steps.field", in: app)
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        XCTAssertEqual(plan.value as? String, "Keep my plan too")
        XCTAssertEqual(element("setup.goal.field", in: app).value as? String, "Keep this draft")
        capture("Draft restored after close", app: app)
        app.buttons["setup.draft.discard"].tap()
        let discard = app.buttons.matching(identifier: "setup.draft.discard.confirm").firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 3))
        discard.tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        create.tap()
        assertEmpty(element("setup.goal.field", in: app))
        dropAnchor("Fresh task", plan: "One step", in: app)
        XCTAssertTrue(app.buttons["Fresh task"].waitForExistence(timeout: 5))
        create.tap()
        XCTAssertTrue(element("setup.goal.field", in: app).waitForExistence(timeout: 5))
        assertEmpty(element("setup.goal.field", in: app))
    }

    @MainActor
    func testNoteSaveReturnsToWorkspaceAndShowsPersistedNote() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()
        dropAnchor("Note test task", plan: "Save context", in: app)
        XCTAssertTrue(app.buttons["Note test task"].waitForExistence(timeout: 5))
        app.buttons["Manage hosted tasks"].tap()
        XCTAssertTrue(app.buttons["Drop an anchor"].waitForExistence(timeout: 5))
        app.buttons["Drop an anchor"].tap()
        type("One verified note", into: element("note.text.field", in: app))
        let save = app.buttons["note.save.button"]
        if !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(element("note.text.field", in: app).waitForNonExistence(timeout: 5))
        app.buttons["Manage hosted tasks"].tap()
        XCTAssertTrue(app.buttons["Drop an anchor"].waitForExistence(timeout: 5))
        app.buttons["Drop an anchor"].tap()
        XCTAssertTrue(app.staticTexts["One verified note"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["note.save.button"].isEnabled)
        capture("Saved anchor note", app: app)
    }

    @MainActor
    func testFreshLaunchHasNoHostedTasks() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 0)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 0)
    }

    @MainActor
    func testVoicePermissionFlowKeepsSetupResponsive() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()

        let createButton = app.buttons["anchor.note.button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 8))
        createButton.tap()
        let voiceButton = app.buttons["setup.voice.input.button"]
        XCTAssertTrue(voiceButton.waitForExistence(timeout: 5))
        // A new anchor opens at its title; put the keyboard away to reach the voice button.
        closeKeyboard(in: app)
        voiceButton.tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 5) else { break }
            let allowButton = ["Allow", "允许", "OK", "好"]
                .map { alert.buttons[$0] }
                .first { $0.exists }
            XCTAssertNotNil(allowButton, "Unexpected voice permission alert")
            allowButton?.tap()
        }

        // Permission callbacks and audio setup finish after the alerts close.
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(element("setup.screen", in: app).waitForExistence(timeout: 5))
        let recording = ["Stop listening", "停止聆听"].contains(voiceButton.label)
#if targetEnvironment(simulator)
        // Some simulator runtimes cannot initialize the system recognizer.
        // They must surface an error and leave the setup screen usable.
        if recording {
            voiceButton.tap()
        } else {
            XCTAssertTrue(element("setup.input.error", in: app).exists)
        }
#else
        XCTAssertTrue(
            recording,
            "Voice recording did not start after permission. Button: \(voiceButton.label); error: \(element("setup.input.error", in: app).label)"
        )
        voiceButton.tap()
        XCTAssertTrue(["Use voice input", "用语音输入"].contains(voiceButton.label))
#endif
        // Cancel a new recognition setup by switching to typing, then start again.
        // A late callback from the first request must not disable the controls.
        for _ in 0..<2 {
            if voiceButton.isEnabled { voiceButton.tap() }
            element("setup.steps.field", in: app).tap()
            XCTAssertTrue(app.buttons["setup.keyboard.done"].waitForExistence(timeout: 3))
            app.buttons["setup.keyboard.done"].tap()
            XCTAssertTrue(voiceButton.waitForExistence(timeout: 3))
            XCTAssertTrue(voiceButton.isEnabled)
        }
    }

    @MainActor
    func testWorkspaceFollowsLandscapeRotation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        defer {
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }
        app.launch()

        XCTAssertTrue(element("workspace.screen", in: app).waitForExistence(timeout: 8))

        // The ambient workspace is the primary landscape experience.
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(element("ambient.screen", in: app).waitForExistence(timeout: 8))
        let emptyLibrary = element("ambient.task.library", in: app)
        XCTAssertTrue(emptyLibrary.waitForExistence(timeout: 3))
        XCTAssertEqual(emptyLibrary.label, "Drop an anchor to host your first task")
        XCTAssertFalse(app.staticTexts["Task library"].exists)
        capture("Landscape empty desk", app: app)

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
        type("Build the formal experience", into: element("setup.steps.field", in: app))
        capture("Anchor filled", app: app)
        slideToDrop(in: app)

        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Production UI test task"].exists)
        XCTAssertFalse(element("workspace.empty.processes", in: app).exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 1)
        XCTAssertFalse(element("processes.observed.section", in: app).exists)
        XCTAssertFalse(element("processes.environment.summary", in: app).exists)

        app.terminate()
        app.launch()

        // The task is both a library card and a lane in the glance; check the card.
        let restoredGoal = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'hosted.task.' AND label == %@", "Production UI test task"
        )).firstMatch
        XCTAssertTrue(restoredGoal.waitForExistence(timeout: 8))
        XCTAssertEqual(restoredGoal.label, "Production UI test task")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 1)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(element("ambient.screen", in: app).waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Production UI test task")).firstMatch.exists)
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
        XCTAssertTrue(card.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertLessThan(card.frame.height, app.frame.height * 0.65)
        XCTAssertGreaterThan(card.frame.minY, app.frame.height * 0.3)
        XCTAssertTrue(app.buttons["connections.primary"].exists)
        let manualCodeButton = app.buttons["connections.pairing.show.code"]
        XCTAssertTrue(manualCodeButton.exists)
        manualCodeButton.tap()
        XCTAssertTrue(element("connections.pairing.code", in: app).exists)
        XCTAssertTrue(app.buttons["connections.pairing.submit"].exists)
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
    func testSetupNeedsOnlyATitleWithoutMacProcesses() throws {
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
        capture("Visual 07 keyboard on the title", app: app)
        closeKeyboard(in: app)

        capture("Visual 01 empty", app: app)
        let card = element("setup.input.card", in: app)
        XCTAssertEqual(card.frame.width, app.frame.width - 40, accuracy: 1)
        let drop = app.buttons["setup.start.button"]
        XCTAssertFalse(drop.isEnabled)
        // No hint lines and no image button: the card and the slider are the whole page.
        XCTAssertFalse(element("setup.plan.principle", in: app).exists)
        XCTAssertFalse(element("setup.mac.status", in: app).exists)
        XCTAssertFalse(app.buttons["setup.photos.button"].exists)

        // A title alone is enough.
        type("完成 Anchor 首页重新设计", into: element("setup.goal.field", in: app))
        closeKeyboard(in: app)
        XCTAssertTrue(drop.isEnabled)
        capture("Visual 02 title only", app: app)

        type("梳理现有信息架构\n确定首页内容层级\n完成视觉设计\n制作交互原型", into: element("setup.steps.field", in: app))
        closeKeyboard(in: app)
        XCTAssertTrue(drop.label.contains("4"), drop.label)
        app.buttons["setup.steps.preview"].tap()
        XCTAssertTrue(app.staticTexts["制作交互原型"].waitForExistence(timeout: 3))
        capture("Visual 03 plan split into steps", app: app)
        slideToDrop(in: app)
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        app.terminate()
        app.launch()
        // The task is both a library card and a lane in the glance; open the card.
        let task = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'hosted.task.' AND label == %@", "完成 Anchor 首页重新设计"
        )).firstMatch
        XCTAssertTrue(task.waitForExistence(timeout: 8))
        task.tap()
        XCTAssertTrue(element("task.saved.plan", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["制作交互原型"].exists)
        app.terminate()
        app.launch()

        // A title too long for the boards moves its extra words to the plan.
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()
        type("今天计划完成竞品分析初步调研，上午还有一个小组工作会议。", into: element("setup.goal.field", in: app))
        XCTAssertTrue(element("setup.title.over", in: app).waitForExistence(timeout: 3))
        capture("Visual 04 title too long", app: app)
        closeKeyboard(in: app)
        XCTAssertTrue(element("setup.title.moved", in: app).waitForExistence(timeout: 3))
        XCTAssertEqual(element("setup.goal.field", in: app).value as? String, "今天计划完成竞品分析初步调研")
        XCTAssertEqual(element("setup.steps.field", in: app).value as? String, "上午还有一个小组工作会议。")
        capture("Visual 06 extra words moved to the plan", app: app)
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
        dropAnchor("Archived production task",
                   plan: "Validate the final boundary\nThe full task remains available in history", in: app)

        // The task is both a library card and a lane in the glance; open the card.
        let taskCard = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'hosted.task.' AND label == %@", "Archived production task"
        )).firstMatch
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
        dropAnchor("Long-running task", plan: "Preserve unfinished work", in: app)

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
            // A title alone is enough to drop an anchor.
            dropAnchor(title, plan: title == "Portfolio" ? nil : "Main conversation", in: app)
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 5))
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "hosted.task.")).count, 2)
        app.buttons["topbar.settings.button"].tap()
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
    func testSetupKeyboardControlsSurviveRepeatedEditing() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()

        let title = element("setup.goal.field", in: app)
        let plan = element("setup.steps.field", in: app)
        // Return in the title moves on to the plan, as in Reminders.
        type("Editable title\n", into: title)
        app.typeText("First step\nSecond step")
        XCTAssertEqual(title.value as? String, "Editable title")
        XCTAssertTrue((plan.value as? String)?.contains("Second step") == true)
        XCTAssertTrue(app.buttons["setup.start.button"].label.contains("2"), app.buttons["setup.start.button"].label)

        let done = app.buttons["setup.keyboard.done"]
        for field in [title, plan] {
            field.tap()
            XCTAssertTrue(done.waitForExistence(timeout: 3))
            XCTAssertTrue(done.isHittable)
            // A downward gesture while correcting text must not close the sheet.
            field.swipeDown()
            XCTAssertTrue(element("setup.screen", in: app).exists)
            if done.exists { done.tap() }
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
            XCTAssertTrue(element("setup.screen", in: app).exists)
        }
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

    /// Drops an anchor from the one-page setup: a title, and a plan when given.
    @MainActor
    private func dropAnchor(_ title: String, plan: String? = nil, in app: XCUIApplication) {
        type(title, into: element("setup.goal.field", in: app))
        if let plan { type(plan, into: element("setup.steps.field", in: app)) }
        slideToDrop(in: app)
    }

    /// The drop is a slide: the anchor is dragged to the far end of its channel.
    @MainActor
    private func slideToDrop(in app: XCUIApplication) {
        closeKeyboard(in: app)
        let slider = app.buttons["setup.start.button"]
        XCTAssertTrue(slider.waitForExistence(timeout: 3))
        XCTAssertTrue(slider.isEnabled)
        let anchor = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.5))
        let end = slider.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5))
        anchor.press(forDuration: 0.1, thenDragTo: end)
    }

    /// An empty text field may report its placeholder as its value.
    @MainActor
    private func assertEmpty(_ field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        let value = field.value as? String
        XCTAssertTrue(value == "" || value == field.placeholderValue, value ?? "nil", file: file, line: line)
    }

    @MainActor
    private func closeKeyboard(in app: XCUIApplication) {
        let done = app.buttons["setup.keyboard.done"]
        if done.waitForExistence(timeout: 2) { done.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
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
