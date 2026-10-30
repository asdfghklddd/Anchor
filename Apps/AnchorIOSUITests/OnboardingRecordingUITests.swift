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
        let close: String
        let languages: [String]

        static func of(_ code: String) -> Words {
            code == "en"
                ? Words(survey: "Clean survey", close: "Close", languages: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
                : Words(survey: "清洗问卷", close: "关闭", languages: ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"])
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

        // The sample cards float in; the ring moves to the anchor by itself.
        let anchor = app.buttons["anchor.note.button"]
        XCTAssertTrue(anchor.waitForExistence(timeout: 15))
        pause(5.5)
        tap(anchor)

        // The person can't talk now, so the tour reads the task in for them.
        let readForMe = app.buttons["tour.read.skip"]
        XCTAssertTrue(readForMe.waitForExistence(timeout: 5))
        pause(2.5)
        tap(readForMe)
        pause(11)

        // The slide that drops the anchor.
        let slider = app.descendants(matching: .any)["setup.start.button"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        pause(1.5)
        let track = slider.frame
        drag(from: CGPoint(x: track.minX + track.height / 2, y: track.midY),
             to: CGPoint(x: track.maxX - 4, y: track.midY), velocity: 260)
        // The water takes it, the first drop, then the turn prompt.
        pause(6)

        // The desk: the ring walks the folders, then the question arrives.
        XCUIDevice.shared.orientation = .landscapeLeft
        let question = app.staticTexts[words.survey].firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 12))
        // The card is there from the start; its question arrives once the ring has walked the folders.
        pause(10)
        tap(question)
        pause(4)
        let close = app.buttons[words.close].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        tap(close)
        // A friend calls the person away.
        pause(3.5)

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
