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
        advanceSetup(in: app)
        type("Keep my criteria too", into: element("setup.criteria.field", in: app))
        app.buttons["setup.close.button"].tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        create.tap()
        let criteria = element("setup.criteria.field", in: app)
        XCTAssertTrue(criteria.waitForExistence(timeout: 5))
        XCTAssertEqual(criteria.value as? String, "Keep my criteria too")
        app.buttons["setup.segment.0"].tap()
        XCTAssertEqual(element("setup.goal.field", in: app).value as? String, "Keep this draft")
        // Switching segments scrolls to the heading. Bring the bottom of the
        // scrollable form back into view before comparing visible controls.
        app.scrollViews.firstMatch.swipeUp()
        capture("Draft restored after close", app: app)
        XCTAssertLessThanOrEqual(app.buttons["setup.segment.0"].frame.maxY, app.buttons["setup.next.button"].frame.minY)
        app.buttons["setup.draft.discard"].tap()
        let discard = app.buttons.matching(identifier: "setup.draft.discard.confirm").firstMatch
        XCTAssertTrue(discard.waitForExistence(timeout: 3))
        discard.tap()
        XCTAssertTrue(element("setup.screen", in: app).waitForNonExistence(timeout: 5))
        create.tap()
        XCTAssertEqual(element("setup.goal.field", in: app).value as? String, "")
        type("Fresh task", into: element("setup.goal.field", in: app))
        advanceSetup(in: app)
        type("Confirmed", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        type("One step", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)
        app.buttons["setup.start.button"].tap()
        XCTAssertTrue(app.buttons["Fresh task"].waitForExistence(timeout: 5))
        create.tap()
        XCTAssertTrue(element("setup.goal.field", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(element("setup.goal.field", in: app).value as? String, "")
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
        type("Note test task", into: element("setup.goal.field", in: app))
        advanceSetup(in: app)
        type("Note is retained", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        type("Save context", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)
        app.buttons["setup.start.button"].tap()
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
            app.buttons["setup.keyboard.button"].tap()
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
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()
        type("今天计划完成竞品分析初步调研，上午还有一个小组工作会议。", into: element("setup.goal.field", in: app))
        app.buttons["setup.keyboard.done"].tap()
        capture("Visual 06 voice input idle", app: app)
        XCTAssertTrue(app.buttons["setup.voice.input.button"].exists)



    }

    @MainActor
    func testLeaveAndReturnReviewsSummaryBeforeResuming() throws {
        try exerciseLeaveAndReturn(reduceMotion: false)
    }

    @MainActor
    func testReturnReviewWithReducedMotion() throws {
        try exerciseLeaveAndReturn(reduceMotion: true)
    }

    @MainActor
    private func exerciseLeaveAndReturn(reduceMotion: Bool) throws {
        XCUIDevice.shared.orientation = .portrait
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-anchor.accessibility.reduceMotion", reduceMotion ? "YES" : "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()
        type("Anchor 工作看板", into: element("setup.goal.field", in: app))
        advanceSetup(in: app)
        type("回来后继续完善任务同步", into: element("setup.criteria.field", in: app))
        advanceSetup(in: app)
        type("检查 iOS 与 Mac 的任务状态", into: element("setup.steps.field", in: app))
        advanceSetup(in: app)
        app.buttons["setup.start.button"].tap()
        let card = app.buttons["Anchor 工作看板"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let leave = app.buttons["profile.session.leave.button"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        if !leave.isHittable { app.swipeUp() }
        capture("01-manual-leave-button", app: app)
        leave.tap()
        XCTAssertTrue(element("away.screen", in: app).waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertTrue(element("away.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("return.screen", in: app).exists)
        XCUIDevice.shared.orientation = .portrait
        let comeBack = app.buttons["away.return.button"]
        if !comeBack.isHittable { app.swipeUp() }
        comeBack.tap()
        XCTAssertTrue(element("return.screen", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("return.task.card", in: app).exists)
        XCTAssertFalse(element("return.landscape.hint", in: app).exists)
        capture("02-return-in-portrait", app: app)
        let back = app.buttons["return.back.button"]
        if !back.isHittable { app.swipeUp() }
        back.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertFalse(element("return.screen", in: app).exists)
        XCTAssertTrue(element("return.landscape.hint", in: app).waitForExistence(timeout: 5))
        capture("03-landscape-hint-after-review", app: app)
        XCUIDevice.shared.orientation = .landscapeRight
        XCTAssertFalse(element("return.landscape.hint", in: app).exists)
        XCUIDevice.shared.orientation = .portrait
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
    func testSetupKeyboardControlsSurviveRepeatedEditingAndReview() throws {
        let app = isolatedApplication()
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.buttons["anchor.note.button"].waitForExistence(timeout: 8))
        app.buttons["anchor.note.button"].tap()

        func assertControls() {
            for id in ["setup.keyboard.newline", "setup.keyboard.done", "setup.keyboard.next"] {
                XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 3), id)
                XCTAssertTrue(app.buttons[id].isHittable, id)
            }
        }

        for field in ["setup.goal.field", "setup.criteria.field", "setup.steps.field"] {
            // Direct text taps and the explicit keyboard button must behave alike.
            type("Editable text", into: element(field, in: app))
            assertControls()
            app.buttons["setup.keyboard.newline"].tap()
            XCTAssertTrue((element(field, in: app).value as? String)?.contains("\n") == true)
            element(field, in: app).typeText("Second line")
            app.buttons["setup.keyboard.done"].tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
            XCTAssertTrue(element("setup.screen", in: app).exists)
            app.buttons["setup.keyboard.button"].tap()
            assertControls()
            // A downward gesture while correcting text must not close the sheet.
            element(field, in: app).swipeDown()
            XCTAssertTrue(element("setup.screen", in: app).exists)
            assertControls()
            app.buttons["setup.keyboard.next"].tap()
        }
        XCTAssertTrue(app.buttons["setup.edit.0"].waitForExistence(timeout: 3))
        app.buttons["setup.edit.0"].tap()
        element("setup.goal.field", in: app).tap()
        assertControls()
        app.buttons["setup.keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(element("setup.screen", in: app).exists)
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
