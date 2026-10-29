import Foundation
import Testing
import AnchorCore
@testable import AnchorIOSFeatures

@Suite("First-run tour")
@MainActor
struct AnchorTourTests {
    @Test func aNewPhoneOwesTheTourOnce() throws {
        let defaults = try #require(UserDefaults(suiteName: "anchor.tour.tests.\(UUID().uuidString)"))
        #expect(AnchorTourGate.isPending(bluetoothAsked: false, defaults: defaults))
        AnchorTourGate.markDone(defaults: defaults)
        #expect(!AnchorTourGate.isPending(bluetoothAsked: false, defaults: defaults))
    }

    @Test func someoneWhoAnsweredBluetoothAlreadyNeverSeesItUnasked() throws {
        let defaults = try #require(UserDefaults(suiteName: "anchor.tour.tests.\(UUID().uuidString)"))
        #expect(!AnchorTourGate.isPending(bluetoothAsked: true, defaults: defaults))
        #expect(!AnchorTourGate.isPending(bluetoothAsked: false, defaults: defaults))
    }

    @Test func theHomeOpensOnTwoTasksFromAConnectedMac() {
        let tour = AnchorTour()
        defer { tour.end() }
        let projection = tour.model.projection
        #expect(projection.connection == .connected)
        #expect(projection.hostedSessions.count == 2)
        #expect(projection.hostedSessions.allSatisfy { !TaskConversationStack.conversations(of: $0).isEmpty })
        // The question arrives later, on the desk, so the person sees the card turn red.
        #expect(!projection.hostedSessions.contains { $0.taskProcesses.contains(where: \.needsRescue) })
        #expect(projection.hostedSessions.contains { $0.id == tour.waitingTaskID })
    }

    @Test func everyStepMovesOnByWhatThePersonDoes() {
        let tour = AnchorTour()
        defer { tour.end() }
        #expect(tour.stage == .hello)
        tour.greeted()
        #expect(tour.stage == .anchorButton)
        tour.setupOpened()
        tour.setupClosed()
        #expect(tour.stage == .anchorButton)
        tour.setupOpened()
        tour.leave()
        #expect(tour.stage == .setup)
        tour.dropped(UUID())
        #expect(tour.stage == .anchored)
        tour.reachedDesk()
        #expect(tour.stage == .desk)
        // Only the question's own task moves the desk on, once it is lit.
        tour.opened(tour.waitingTaskID)
        #expect(tour.stage == .desk)
    }

    @Test func theRedCardOpensThenAFriendCalls() async throws {
        let tour = AnchorTour()
        defer { tour.end() }
        tour.greeted()
        tour.setupOpened()
        tour.dropped(UUID())
        tour.reachedDesk()
        try await waitFor(.waiting, in: tour, seconds: 8)
        tour.opened(UUID())
        #expect(tour.stage == .waiting)
        tour.opened(tour.waitingTaskID)
        #expect(tour.stage == .reading)
        tour.closedTask()
        #expect(tour.stage == .called)
        // Back to Home only ends the tour from the return page.
        tour.leave()
        #expect(tour.stage == .called)
        tour.leftDesk()
        #expect(tour.stage == .away)
    }

    @Test func theDialTurnsTheTimeAwayThenBringsThePersonBack() async throws {
        let tour = AnchorTour()
        defer { tour.end() }
        tour.greeted()
        tour.setupOpened()
        tour.dropped(UUID())
        tour.reachedDesk()
        tour.leftDesk()
        #expect(tour.stage == .away)
        tour.turnedDial(to: 3)
        #expect(tour.awayMinutes == 3)
        // Time away never runs back.
        tour.turnedDial(to: 2)
        #expect(tour.awayMinutes == 3)
        tour.turnedDial(to: 20)
        #expect(tour.landed.map(\.title) == [TourCopy.palette, TourCopy.replace, TourCopy.seo])
        tour.turnedDial(to: AnchorTour.dialMinutes)
        #expect(tour.stage == .back)
        try await waitFor(.returned, in: tour, seconds: 4)
        #expect(tour.model.projection.connection == .connected)
        #expect(tour.model.projection.session?.presence == .returning)
    }

    @Test func pickingThePhoneUpEarlyStillLeavesTheDesk() {
        let tour = AnchorTour()
        defer { tour.end() }
        tour.greeted()
        tour.setupOpened()
        // Before the desk, turning upright is nothing to the tour.
        tour.leftDesk()
        #expect(tour.stage == .setup)
        tour.dropped(UUID())
        tour.reachedDesk()
        tour.leftDesk()
        #expect(tour.stage == .away)
    }

    @Test func theMacRecapsEveryTaskYoursFirst() {
        let mac = TourMac()
        let tasks = mac.seed(now: .now)
        let own = UUID()
        let back = Date.now
        let recaps = mac.recaps(returnedAt: back, ownTask: own)
        #expect(recaps.map(\.0) == [own] + tasks.map(\.id))
        #expect(recaps.allSatisfy { $0.1.returnedAt == back && !$0.1.conversations.isEmpty })
        // Every recap names a conversation the task really has, or gets while the person is away.
        let news = mac.awayNews(ownTask: own)
        #expect(news.count == 3)
    }

    @Test func readingAloudLightsTheLineAsFarAsItWasHeard() {
        let line = "给 App 加深色模式"
        #expect(TourReadAlong(heard: "", line: line).lit == 0)
        let half = TourReadAlong(heard: "给app加", line: line)
        #expect(half.lit == 7)
        #expect(!half.isRead)
        // A misheard character still counts.
        let misheard = TourReadAlong(heard: "给 app 加申色模式", line: line)
        #expect(misheard.isRead)
        #expect(misheard.lit == line.count)
        let english = TourReadAlong(heard: "add dark", line: "Add dark mode to the app")
        #expect(english.lit == 8)
        #expect(!TourReadAlong(heard: "hello there", line: "Add dark mode to the app").isEnough)
    }

    @Test func thePetSpeaksInTheShapeOfTheWords() {
        let chinese = TourBabble.syllables(of: "妈麻马骂")
        #expect(chinese.map(\.contour) == [.high, .rise, .dip, .drop])
        #expect(chinese.allSatisfy { $0.vowel == "a" })
        let question = TourBabble.syllables(of: "Ready?")
        #expect(question.count == 2)
        #expect(question.last?.contour == .lift)
        #expect(TourBabble.length(of: TourBabble.syllables(of: "嗨！")) > 0.2)
        let samples = TourBabble.render(chinese, pitch: TourBabble.pitch(of: .crab))
        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { abs($0) <= 0.51 })
        for effect in TourSound.Effect.allCases { #expect(!TourSynth.render(effect).isEmpty) }
    }

    private func waitFor(_ stage: AnchorTour.Stage, in tour: AnchorTour, seconds: Double) async throws {
        let deadline = Date.now + seconds
        while tour.stage != stage, Date.now < deadline { try await Task.sleep(for: .milliseconds(100)) }
        #expect(tour.stage == stage)
    }

    @Test func dictationArrivesAWordAtATime() {
        #expect(SpeechInputController.spokenChunks(of: "First list the colors, then check")
            == ["First ", "list ", "the ", "colors, ", "then ", "check"])
        let chinese = SpeechInputController.spokenChunks(of: "先梳理颜色变量，然后替换")
        #expect(chinese.joined() == "先梳理颜色变量，然后替换")
        #expect(chinese.allSatisfy { $0.count <= 4 })
        #expect(chinese.contains { $0.hasSuffix("，") })
    }
}
