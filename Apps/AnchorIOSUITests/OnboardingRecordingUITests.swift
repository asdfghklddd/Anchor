import XCTest

/// Walks the whole first-run tour the way a person would, at a pace meant to
/// be watched, so `scripts/record-onboarding.sh` can film it. It only runs
/// when that script asks for it (ANCHOR_RECORD_LANG); an ordinary test run
/// skips it. The tour never stops moving, so touches go through the system
/// rather than the app, which would otherwise wait for it to settle first.
final class OnboardingRecordingUITests: XCTestCase {
    /// The words the walk looks for, in the language being filmed.
    private struct Words {
        let survey: String
        let languages: [String]

        static func of(_ code: String) -> Words {
            code == "en"
                ? Words(survey: "Clean survey", languages: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
                : Words(survey: "清洗问卷", languages: ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"])
        }
    }

    @MainActor
    func testWalkTheTourForTheCamera() throws {
        guard let language = ProcessInfo.processInfo.environment["ANCHOR_RECORD_LANG"] else {
            throw XCTSkip("Run by scripts/record-onboarding.sh, which films it.")
        }
        continueAfterFailure = false
        let words = Words.of(language)
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_TOUR"] = "1"
        app.launchArguments += words.languages
        app.launch()

        // The home whole, then today's anchoring counts up, then the cards;
        // the clear part moves to the anchor by itself.
        let anchor = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchor.waitForExistence(timeout: 15))
        pause(10)
        tap(anchor)

        // A tap on the microphone says the task, another says the plan.
        let mic = app.descendants(matching: .any)["setup.voice.input.button"]
        XCTAssertTrue(mic.waitForExistence(timeout: 5))
        pause(2.5)
        tap(mic)
        pause(4)
        tap(mic)
        pause(9)

        // The slide that drops the anchor.
        let slider = app.descendants(matching: .any)["setup.start.button"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        pause(1.5)
        let track = slider.frame
        drag(from: CGPoint(x: track.minX + track.height / 2, y: track.midY),
             to: CGPoint(x: track.maxX - 4, y: track.midY), velocity: 260)
        // The water takes it, then the first drop.
        let agent = app.buttons["tour.agent.claude"]
        XCTAssertTrue(agent.waitForExistence(timeout: 12))
        // An agent opens on the small Mac by itself, is matched to the card, then the turn prompt.
        pause(7.5)

        // The desk: the ring walks the folders, then the question arrives.
        XCUIDevice.shared.orientation = .landscapeLeft
        let question = app.staticTexts[words.survey].firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 12))
        // The ring walks the folders, then waits on the pet for a hello.
        let pet = app.descendants(matching: .any)["desk.pet"]
        XCTAssertTrue(pet.waitForExistence(timeout: 12))
        // It exists before its step does; the ring's walk takes 6.4 s.
        pause(9)
        tap(pet)
        // The question arrives, its anchor dropping onto the card.
        pause(4.5)
        tap(question)
        // Its recall card opens over the desk; a swipe down puts it back.
        let recall = app.descendants(matching: .any)["desk.recall"]
        XCTAssertTrue(recall.waitForExistence(timeout: 5))
        pause(4)
        var card = recall.frame
        drag(from: CGPoint(x: card.midX, y: card.minY + 40), to: CGPoint(x: card.midX, y: card.minY + 220), velocity: 700)
        // Opened again, and swiped up: the Mac beside it catches it.
        pause(3)
        tap(question)
        XCTAssertTrue(recall.waitForExistence(timeout: 5))
        pause(3.5)
        card = recall.frame
        drag(from: CGPoint(x: card.midX, y: card.maxY - 40), to: CGPoint(x: card.midX, y: card.maxY - 240), velocity: 700)
        // The window opens on the Mac, then a friend calls the person away.
        pause(6)

        // Picked up: the reminder question, if the system has never asked.
        XCUIDevice.shared.orientation = .portrait
        allowNotificationsIfAsked()
        pause(1.5)
        turnTheDial(in: app)
        // The link joins again and the recaps arrive.
        pause(4.5)

        // The return page, a page per task, then Back to Home.
        // Back to Home reads the same in both languages; it shows on the last page.
        let back = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Back to Home")).firstMatch
        XCTAssertTrue(app.descendants(matching: .any)["return.screen"].waitForExistence(timeout: 8))
        pause(3)
        let page = app.frame
        // Three tasks, three pages: the samples and the person's own.
        for _ in 0..<2 {
            drag(from: CGPoint(x: page.maxX - 40, y: page.midY), to: CGPoint(x: page.minX + 40, y: page.midY), velocity: 1200)
            pause(3)
        }
        tap(back)

        // The samples weigh anchor, then the ending and Start.
        let start = app.buttons["tour.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        pause(4)
        tap(start)
        XCTAssertTrue(app.descendants(matching: .any)["connections.screen"].waitForExistence(timeout: 6))
        pause(3.5)
    }

    /// Skip on the tour's home leaves for the person's own Anchor, even while
    /// the home only answers its anchor button.
    @MainActor
    func testSkipLeavesTheTourFromTheHome() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchEnvironment["ANCHOR_UI_TESTING"] = "1"
        app.launchEnvironment["ANCHOR_UI_TEST_STORAGE_ID"] = UUID().uuidString
        app.launchEnvironment["ANCHOR_TOUR"] = "1"
        app.launchArguments += Words.of("zh").languages
        defer { app.terminate() }
        app.launch()

        let skip = app.buttons["tour.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        // Once the ring is on the anchor button, the rest of the home is held.
        pause(5.5)
        tap(skip)
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: skip)
        wait(for: [gone], timeout: 6)
    }

    // MARK: Steps

    /// The dial turns clockwise a quarter at a time, each a straight stroke
    /// that keeps to the outside of the middle, so it only ever moves forward.
    @MainActor
    private func turnTheDial(in app: XCUIApplication) {
        let dial = app.descendants(matching: .any)["tour.dial"]
        XCTAssertTrue(dial.waitForExistence(timeout: 6))
        let middle = CGPoint(x: dial.frame.midX, y: dial.frame.midY)
        let radius = 105.0
        let quarters = [(0.0, -radius), (radius, 0.0), (0.0, radius), (-radius, 0.0), (0.0, -radius)]
        for (from, to) in zip(quarters, quarters.dropFirst()) {
            drag(from: CGPoint(x: middle.x + from.0, y: middle.y + from.1),
                 to: CGPoint(x: middle.x + to.0, y: middle.y + to.1), velocity: 110)
            pause(1.2)
        }
    }

    /// Answers the system's notification question the first time it comes up.
    @MainActor
    private func allowNotificationsIfAsked() {
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "允许"])).firstMatch
        guard allow.waitForExistence(timeout: 5) else { return }
        pause(1.5)
        allow.tap()
    }

    @MainActor
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    /// A point on the screen, in the same space as the elements' frames.
    @MainActor
    private func screen(_ point: CGPoint) -> XCUICoordinate {
        springboard.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point.x, dy: point.y))
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        screen(CGPoint(x: element.frame.midX, y: element.frame.midY)).tap()
    }

    @MainActor
    private func drag(from start: CGPoint, to end: CGPoint, velocity: CGFloat) {
        screen(start).press(forDuration: 0.15, thenDragTo: screen(end),
                            withVelocity: XCUIGestureVelocity(velocity), thenHoldForDuration: 0.1)
    }

    /// Time for the viewer, not for the app.
    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
