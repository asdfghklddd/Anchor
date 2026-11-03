#if os(iOS)
import AnchorCore
import AnchorDesign
import Foundation
import Observation
import SwiftUI

/// Whether the first run still owes the person the tour. Someone who has
/// already answered the Bluetooth prompt has used Anchor before and never
/// sees it on their own; Settings can replay it at any time.
public enum AnchorTourGate {
    static let doneKey = "anchor.tour.done"

    public static func isPending(bluetoothAsked: Bool, defaults: UserDefaults = .standard) -> Bool {
        if defaults.bool(forKey: doneKey) { return false }
        if bluetoothAsked {
            defaults.set(true, forKey: doneKey)
            return false
        }
        return true
    }

    static func markDone(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: doneKey)
    }
}

/// The first-run tour. The real home, setup sheet, desk and return page run
/// on a pretend Mac, so someone without their computer can try the whole
/// loop: two tasks already anchored, one they read aloud and drop themselves,
/// agents that report while the phone lies sideways and keep working while
/// the person is away, and the recaps waiting when they come back. Every step
/// moves on by something the person does; a short line says what to do. Nothing
/// here touches the person's own tasks: the store lives in a temporary file
/// that goes when the tour ends.
@MainActor
@Observable
final class AnchorTour {
    enum Stage: Int, Comparable {
        /// The whole home, clear, for a moment before the frost comes in.
        case glance
        /// Today's anchoring is the clear part: its clock counts up and its bars rise.
        case clock
        /// The sample cards float up under a ring; the ring moves on by itself.
        case hello
        /// The anchor button is lit and waits for its tap.
        case anchorButton
        /// The setup sheet is up; the person reads the task aloud.
        case setup
        /// The anchor is down, and the real drop plays out on the home.
        case anchored
        /// The phone is asked to turn.
        case turn
        /// The landscape desk: the ring walks the folders and rests on the person's own.
        case desk
        /// The pet's nook is the clear part, waiting for a tap on the pet.
        case pet
        /// The question waiting on the homework is lit as it comes to the front.
        case waiting
        /// The question's recall card is open, asking for the swipe in `asks`.
        case reading
        /// The card is back in its folder; the tour asks to open it once more
        /// for the other swipe.
        case again
        /// Swiped up: the conversation flies to the Mac and opens there.
        case sending
        /// A friend asks the person down for coffee; the desk waits for the phone to come up.
        case called
        /// The phone is up and the link to the Mac breaks; the person turns
        /// the dial through the time away while the agents keep working.
        case away
        /// The dial went round: the phone is back in range and the link joins.
        case back
        /// The real return page, with the Mac's recaps.
        case returned
        /// Back to Home: the sample tasks weigh anchor and leave.
        case leaving
        /// The empty sea, one line on what Anchor is for, and Start.
        case ending
        /// The real workspace takes over.
        case finished

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var stage = Stage.glance {
        didSet { if stage != oldValue { RotationTrace.note("tour stage \(oldValue) → \(stage)") } }
    }
    /// Minutes the dial has turned through while away.
    private(set) var awayMinutes = 0
    /// What the agents did on the dial so far.
    private(set) var landed: [TourMac.Note] = []
    let model: AnchorSessionModel
    let log: AnchoringLog

    @ObservationIgnored private let repository: LocalSessionRepository
    @ObservationIgnored private let storageURL: URL
    @ObservationIgnored private var work: [Task<Void, Never>] = []
    @ObservationIgnored private let mac: TourMac
    /// Answers the store like a paired Mac, so nothing on screen waits to be sent.
    @ObservationIgnored private var listener: Task<Void, Never>?
    /// The task the person dropped during the tour.
    private(set) var ownTask: UUID?
    /// Desk news not yet sent; leaving early sends the rest at once.
    @ObservationIgnored private var deskNews: [TourMac.Beat] = []
    /// News while away, by the minute it lands on the dial.
    @ObservationIgnored private var awayNews: [TourMac.Beat] = []
    @ObservationIgnored private var asked = false

    /// The two ways an open recall card goes: down closes it, up sends it to the Mac.
    enum Swipe {
        case down, up
    }

    /// The swipe the open card asks for: down first, then the other one.
    private(set) var asks = Swipe.down
    @ObservationIgnored private var swiped: Set<Swipe> = []
    /// Whether a pet lives on the desk to be met; with none the step is skipped.
    @ObservationIgnored private let hasPet: Bool
    @ObservationIgnored private var petted = false

    /// The task whose question the desk lights.
    var waitingTaskID: UUID { mac.homeworkID }

    /// How long the dial runs, and the minutes on it that matter.
    static let dialMinutes = 30
    static let linkBreaksAt = 1
    static let awayAt = 5
    /// The first drop's moment on the home, before the phone is asked to turn.
    static let dropLength: TimeInterval = 3.0

    init(hasPet: Bool = DeskPetKind(rawValue: ProfilePreferences.store.string(forKey: DeskPetKind.defaultsKey) ?? "") != .off) {
        self.hasPet = hasPet
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "AnchorTour", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "session-repository.json")
        let mac = TourMac()
        let seeded = mac.seed(now: .now)
        let repository = LocalSessionRepository(storageURL: url)
        var start = SessionProjection(connection: .connected, proximity: .near, dataObservedAt: .now)
        start.session = seeded.first
        start.additionalSessions = Array(seeded.dropFirst())
        let model = AnchorSessionModel(repository: repository, initialProjection: start, usesTaskDashboard: true)
        storageURL = url
        self.mac = mac
        self.repository = repository
        self.model = model
        log = AnchoringLog.tour(now: .now)
        listener = Task {
            try? await repository.send(.updateSignals(connection: .connected, proximity: .near, at: .now))
            for session in seeded { try? await repository.send(.hostSession(session)) }
            await Self.acknowledge(repository)
            model.start()
            // The pretend Mac answers every change, so nothing waits to be sent.
            for await _ in await repository.projections() {
                await Self.acknowledge(repository)
            }
        }
    }

    // MARK: Stages

    /// The home has been seen whole: the frost comes in on today's anchoring.
    func glanced() {
        if stage == .glance { stage = .clock }
    }

    /// The day has counted up: the clear part moves on to the cards.
    func sawClock() {
        if stage == .clock { stage = .hello }
    }

    /// How long the home stays clear before the frost, and how long the clock step lasts.
    static let glanceLength: TimeInterval = 1.0
    static let clockLength: TimeInterval = 4.2

    /// The cards have landed: the ring moves to the anchor button.
    func greeted() {
        if stage <= .hello { stage = .anchorButton }
    }

    func setupOpened() {
        if stage <= .anchorButton { stage = .setup }
    }

    /// The sheet closed without a drop; the button is lit again.
    func setupClosed() {
        if stage == .setup { stage = .anchorButton }
    }

    /// The third anchor is down. The drop plays out as it always does, then
    /// the tour asks the phone to turn; its agent starts a moment later, as
    /// if the person had opened Claude Code on the Mac.
    func dropped(_ taskID: UUID) {
        guard stage < .anchored else { return }
        stage = .anchored
        ownTask = taskID
        later(Self.dropLength) { [weak self] in
            if self?.stage == .anchored { self?.stage = .turn }
        }
        later(2.6) { [mac, model] in
            _ = await model.send(.forSession(taskID, .addProcess(mac.firstConversation(of: taskID, now: .now))))
        }
    }

    /// The desk is up, on a turned phone or drawn sideways under the lock.
    /// The ring walks the folders and rests on the person's own, then moves
    /// to the pet; once it has been greeted, a question arrives on its own.
    func reachedDesk() {
        guard stage == .turn || stage == .anchored else { return }
        stage = .desk
        deskNews = mac.deskNews()
        for beat in deskNews {
            later(beat.after) { [weak self] in await self?.send(beat) }
        }
        later(Self.deskLook) { [weak self] in self?.meetPet() }
    }

    private func meetPet() {
        guard stage == .desk else { return }
        if hasPet { stage = .pet } else { ask() }
    }

    /// The pet was tapped: it answers, then the desk moves on to the question.
    func pettedPet() {
        guard stage == .pet, !petted else { return }
        petted = true
        later(Self.petAnswer) { [weak self] in self?.ask() }
    }

    /// Time for the pet's answer to a tap to show before the question comes.
    static let petAnswer: TimeInterval = 1.6

    /// The ring's walk over the folders, and a moment on the person's own.
    static let deskLook: TimeInterval = 6.4

    /// The ring settles on the homework first, then its question arrives under it.
    private func ask() {
        guard stage == .desk || stage == .pet else { return }
        stage = .waiting
        later(0.7) { [weak self] in await self?.sendQuestion() }
    }

    private func sendQuestion() async {
        guard !asked else { return }
        asked = true
        TourSound.shared.play(.question)
        _ = await model.send(mac.question(now: .now))
    }

    /// The person opened a task on the desk; the question's task moves the tour on.
    func opened(_ taskID: UUID) {
        if stage == .waiting || stage == .again, taskID == waitingTaskID { stage = .reading }
    }

    /// The open card went one way. Once both ways are done, a friend calls
    /// the person away; sent up last, the Mac is seen opening it first.
    func closedTask(sentToMac: Bool = false) {
        guard stage == .reading else { return }
        let swipe = sentToMac ? Swipe.up : .down
        swiped.insert(swipe)
        guard swiped.count == 2 else {
            asks = swipe == .down ? .up : .down
            stage = .again
            return
        }
        guard sentToMac else {
            stage = .called
            return
        }
        stage = .sending
        later(Self.sendLength) { [weak self] in
            if self?.stage == .sending { self?.stage = .called }
        }
    }

    /// The card's flight to the Mac and the window opening there.
    static let sendLength: TimeInterval = 2.8

    /// The phone came up off the desk. Bluetooth to the Mac drops once the
    /// dial passes its first minute, and the agents' news lands as it turns.
    func leftDesk() {
        guard stage >= .desk, stage <= .called else { return }
        stage = .away
        awayMinutes = 0
        landed = []
        cancelWork()
        awayNews = mac.awayNews(ownTask: ownTask)
        work.append(Task {
            for beat in self.deskNews { await self.send(beat) }
            await self.sendQuestion()
        })
    }

    /// The dial reached `minutes`. Each minute is passed once, in order;
    /// at the end of the dial the person is back.
    func turnedDial(to minutes: Int) {
        guard stage == .away, minutes > awayMinutes else { return }
        let passed = awayMinutes
        awayMinutes = min(minutes, Self.dialMinutes)
        if passed < Self.linkBreaksAt, awayMinutes >= Self.linkBreaksAt {
            work.append(Task { [model] in
                _ = await model.send(.updateSignals(connection: .disconnected, proximity: .unknown, at: .now))
            })
        }
        let landed = awayNews.filter { $0.after <= Double(awayMinutes) }
        awayNews.removeAll { $0.after <= Double(awayMinutes) }
        self.landed += landed.compactMap(\.note)
        if !landed.isEmpty {
            work.append(Task { [model] in
                for beat in landed { _ = await model.send(beat.command(.now)) }
            })
        }
        if awayMinutes >= Self.dialMinutes { comeBack() }
    }

    /// The link joins on the dial, then the real return page opens over
    /// everything the agents did while the person was gone.
    private func comeBack() {
        stage = .back
        work.append(Task { [mac, model, ownTask] in
            guard await Self.pause(Self.joinLength) else { return }
            let back = Date.now
            _ = await model.send(.updateSignals(connection: .connected, proximity: .near, at: back))
            _ = await model.send(.updatePresence(.away, at: back,
                                                 awaySince: back - TimeInterval(Self.dialMinutes * 60)))
            _ = await model.send(.updatePresence(.returning, at: back))
            self.stage = .returned

            // The Mac takes a moment to write the recaps.
            guard await Self.pause(1.8) else { return }
            for (task, recap) in mac.recaps(returnedAt: back, ownTask: ownTask) {
                _ = await model.send(.forSession(task, .recordReturnRecap(recap)))
            }
        })
    }

    /// How long the dial shows the link joining before the return page.
    static let joinLength: TimeInterval = 1.6

    /// Back to Home on the return page: the sample tasks leave, then the
    /// person's own workspace takes over.
    func leave() {
        guard stage == .returned else { return }
        stage = .leaving
        cancelWork()
        work.append(Task { [model] in
            try? await Task.sleep(for: .seconds(0.6))
            for task in model.projection.hostedSessions.reversed() {
                guard !Task.isCancelled else { return }
                _ = await model.send(.forSession(task.id, .archiveSession))
                try? await Task.sleep(for: .milliseconds(340))
            }
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            self.stage = .ending
        })
    }

    /// Start on the ending: the person's own Anchor takes over.
    func start() {
        if stage == .ending { stage = .finished }
    }

    /// Skip: straight to the person's own Anchor, from any step.
    func skip() {
        guard stage < .leaving else { return }
        cancelWork()
        stage = .finished
    }

    /// Stops the pretend Mac and removes its files.
    func end() {
        cancelWork()
        listener?.cancel()
        TourSound.shared.stop()
        try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent())
        AnchoringLog.clearTour()
    }

    private func later(_ seconds: TimeInterval, _ action: @escaping @MainActor () async -> Void) {
        work.append(Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await action()
        })
    }

    private func send(_ beat: TourMac.Beat) async {
        guard let index = deskNews.firstIndex(where: { $0.id == beat.id }) else { return }
        deskNews.remove(at: index)
        _ = await model.send(beat.command(.now))
    }

    /// False once the tour was stopped part way.
    private static func pause(_ seconds: TimeInterval) async -> Bool {
        try? await Task.sleep(for: .seconds(max(0, seconds)))
        return !Task.isCancelled
    }

    private func cancelWork() {
        work.forEach { $0.cancel() }
        work.removeAll()
    }

    private static func acknowledge(_ repository: LocalSessionRepository) async {
        for event in await repository.pendingEvents() {
            try? await repository.markDelivered(event.id)
        }
    }
}

extension EnvironmentValues {
    /// The tour running these screens, if any.
    @Entry var anchorTour: AnchorTour? = nil
    /// Plays the tour again from Settings.
    @Entry var replayTour: () -> Void = {}
}

// MARK: The pretend Mac

/// What a Mac with Codex and Claude Code open would report: two tasks with
/// their conversations, the news that arrives while the desk is up and while
/// the person is away, and the recaps it writes when they come back.
struct TourMac {
    struct Beat {
        let id = UUID()
        /// Seconds on the desk; minutes on the dial while away.
        let after: TimeInterval
        /// What the dial shows when it lands while away.
        var note: Note?
        let command: (Date) -> SessionCommand
    }

    /// A conversation that finished or started while the person was away.
    struct Note: Hashable {
        let title: String
        let done: Bool
    }

    private let homepage = UUID()
    private let deploy = UUID()
    private let survey = UUID()
    private let charts = UUID()
    private let seo = UUID()
    private let palette = UUID()
    private let replace = UUID()
    private let portfolioID = UUID()
    let homeworkID = UUID()

    func seed(now: Date) -> [AnchorSession] {
        let portfolio = AnchorSession(
            id: portfolioID,
            goal: AnchorGoal(title: TourCopy.portfolio, completionCriteria: "",
                             userPlan: AnchorUserPlan(steps: TourCopy.portfolioSteps, completedSteps: [0], reviewedAt: now - 1_200)),
            startedAt: now - 9_000,
            processes: [
                conversation(homepage, in: portfolioID, agent: .claude, title: TourCopy.homepage,
                             request: TourCopy.homepageRequest, status: .running, worked: 1_260, at: now - 200),
                conversation(deploy, in: portfolioID, agent: .codex, title: TourCopy.deploy,
                             request: TourCopy.deployRequest, reply: TourCopy.deployReply,
                             status: .completed, worked: 540, at: now - 1_500),
            ],
            taskColorIndex: 0)
        let homework = AnchorSession(
            id: homeworkID,
            goal: AnchorGoal(title: TourCopy.homework, completionCriteria: "",
                             userPlan: AnchorUserPlan(steps: TourCopy.homeworkSteps, reviewedAt: now - 3_000)),
            startedAt: now - 6_000,
            processes: [
                // The survey is still cleaning; its question arrives on the desk.
                conversation(survey, in: homeworkID, agent: .codex, title: TourCopy.survey,
                             request: TourCopy.surveyRequest, status: .running, worked: 380, at: now - 2_400),
                conversation(charts, in: homeworkID, agent: .claude, title: TourCopy.charts,
                             request: TourCopy.chartsRequest, reply: TourCopy.chartsReply,
                             status: .completed, worked: 720, at: now - 420),
            ],
            taskColorIndex: 1)
        return [portfolio, homework]
    }

    /// The person's own task gets its first conversation.
    func firstConversation(of taskID: UUID, now: Date) -> AnchorProcess {
        conversation(palette, in: taskID, agent: .claude, title: TourCopy.palette,
                     request: TourCopy.paletteRequest, status: .running, worked: 0, at: now)
    }

    /// News while the desk is up: the home layout's reply lands, and the
    /// page titles start.
    func deskNews() -> [Beat] {
        [
            Beat(after: 4) { now in
                .forSession(portfolioID, .updateProcess(conversation(
                    homepage, in: portfolioID, agent: .claude, title: TourCopy.homepage,
                    request: TourCopy.homepageRequest, reply: TourCopy.homepageReply,
                    status: .completed, worked: 1_470, at: now)))
            },
            Beat(after: 8) { now in
                .forSession(portfolioID, .addProcess(conversation(
                    seo, in: portfolioID, agent: .codex, title: TourCopy.seo,
                    request: TourCopy.seoRequest, status: .running, worked: 0, at: now)))
            },
        ]
    }

    /// The survey stops to ask the person something: on the desk it takes
    /// its task's color and an anchor, and comes to the front.
    /// Its card, opened, reads what the Mac took from the conversation.
    func question(now: Date) -> SessionCommand {
        var process = conversation(
            survey, in: homeworkID, agent: .codex, title: TourCopy.survey,
            request: TourCopy.surveyRequest, reply: TourCopy.surveyReply,
            status: .needsDecision, worked: 410, at: now)
        process.digest = ConversationDigest(
            path: TourCopy.surveyPath,
            waiting: .init(kind: .answer, text: TourCopy.surveyReply),
            latestRequest: TourCopy.surveyRequest)
        return .forSession(homeworkID, .updateProcess(process))
    }

    /// News while the person is away, by the minute on the dial: their own
    /// colors are done and the next step starts, and the page titles finish.
    /// The survey's question stays unanswered.
    func awayNews(ownTask: UUID?) -> [Beat] {
        var beats: [Beat] = []
        if let ownTask {
            beats.append(Beat(after: 8, note: Note(title: TourCopy.palette, done: true)) { now in
                .forSession(ownTask, .updateProcess(conversation(
                    palette, in: ownTask, agent: .claude, title: TourCopy.palette,
                    request: TourCopy.paletteRequest, reply: TourCopy.paletteReply,
                    status: .completed, worked: 640, at: now)))
            })
            beats.append(Beat(after: 12, note: Note(title: TourCopy.replace, done: false)) { now in
                .forSession(ownTask, .addProcess(conversation(
                    replace, in: ownTask, agent: .claude, title: TourCopy.replace,
                    request: TourCopy.replaceRequest, status: .running, worked: 0, at: now)))
            })
        }
        beats.append(Beat(after: 19, note: Note(title: TourCopy.seo, done: true)) { now in
            .forSession(portfolioID, .updateProcess(conversation(
                seo, in: portfolioID, agent: .codex, title: TourCopy.seo,
                request: TourCopy.seoRequest, reply: TourCopy.seoReply,
                status: .completed, worked: 310, at: now)))
        })
        return beats
    }

    /// What the Mac writes for each task when the person is back, newest
    /// conversation first.
    func recaps(returnedAt: Date, ownTask: UUID?) -> [(UUID, ReturnRecap)] {
        func recap(_ conversations: [(UUID, String, String)]) -> ReturnRecap {
            ReturnRecap(returnedAt: returnedAt, conversations: conversations.map {
                ConversationRecap(id: $0.0, name: $0.1, text: $0.2)
            })
        }
        var recaps = [
            (portfolioID, recap([(seo, TourCopy.seo, TourCopy.seoRecap),
                                 (homepage, TourCopy.homepage, TourCopy.homepageRecap),
                                 (deploy, TourCopy.deploy, TourCopy.deployRecap)])),
            (homeworkID, recap([(survey, TourCopy.survey, TourCopy.surveyRecap),
                                (charts, TourCopy.charts, TourCopy.chartsRecap)])),
        ]
        if let ownTask {
            recaps.insert((ownTask, recap([(replace, TourCopy.replace, TourCopy.replaceRecap),
                                           (palette, TourCopy.palette, TourCopy.paletteRecap)])), at: 0)
        }
        return recaps
    }

    private enum Agent {
        case codex, claude
        var name: String { self == .codex ? "Codex" : "Claude Code" }
    }

    private func conversation(_ id: UUID, in taskID: UUID, agent: Agent, title: String, request: String,
                              reply: String = "", status: ProcessStatus, worked: TimeInterval, at date: Date) -> AnchorProcess {
        var process = AnchorProcess(id: id, sessionID: taskID, sourceID: id, sourceName: agent.name, sourceSymbol: "C",
                                    sourceTone: "cyan", title: title, status: status, detail: reply, updatedAt: date)
        process.request = request
        process.workedSeconds = worked
        return process
    }
}

// MARK: Copy

enum TourCopy {
    static let anchorButton = AnchorStrings.value("tour.anchor", default: "Tap the anchor to drop one of your own.")
    static let readTitle = AnchorStrings.value("tour.voice.title", default: "Tap the mic and say the task.")
    static let readPlan = AnchorStrings.value("tour.voice.plan", default: "Once more for the plan.")
    static let slide = AnchorStrings.value("tour.slide", default: "Slide the anchor all the way.")
    static let turn = AnchorStrings.value("tour.turn", default: "Turn sideways into the workbench.")
    static let lockQuestion = AnchorStrings.value("tour.lock", default: "Portrait Orientation Lock on?")
    static let openHere = AnchorStrings.value("tour.lock.open", default: "Open the desk here")
    static let backUpright = AnchorStrings.value("tour.lock.back", default: "Back to the home")
    static let replay = AnchorStrings.value("tour.replay", default: "Replay the tour")
    static let folders = AnchorStrings.value("tour.folders", default: "Each folder is a task.")
    static let clock = AnchorStrings.value("tour.clock", default: "Your time linked to the Mac adds up here.")
    static let pet = AnchorStrings.value("tour.pet", default: "It lives on your desk. Say hi.")
    static let waiting = AnchorStrings.value("tour.anchor.waiting", default: "The anchor means an AI is waiting on you. Tap it.")
    static let ownTask = AnchorStrings.value("tour.own", default: "Your task: an AI is already on it.")
    static let recall = AnchorStrings.value("tour.recall", default: "Swipe down to put it back.")
    static let recallUp = AnchorStrings.value("tour.recall.up", default: "Swipe up to carry on at your Mac.")
    static let againUp = AnchorStrings.value("tour.again.up", default: "Open it again. Swipe up this time.")
    static let againDown = AnchorStrings.value("tour.again.down", default: "Open it again. Swipe down this time.")
    static let sent = AnchorStrings.value("tour.sent", default: "It's open on your Mac.")
    static let called = AnchorStrings.value("tour.called", default: "A friend asks you out for coffee. Take your phone and go.")
    static let dial = AnchorStrings.value("tour.dial", default: "Turn the dial.")
    static let apart = AnchorStrings.value("tour.apart", default: "5 minutes away. Your AI keeps working.")
    static let together = AnchorStrings.value("tour.together", default: "You're back.")
    static let connect = AnchorStrings.value("tour.connect", default: "Connect your Mac to start.")
    static let firstAnchor = AnchorStrings.value("tour.first", default: "Your first anchor is down.")
    static let reminder = AnchorStrings.value("tour.reminder", default: "Away too long, and Anchor will remind you to come back.")
    static let ending = AnchorStrings.value("tour.ending", default: "Anchor one thing. The AI moves it along on your computer; step away and miss nothing.")
    static let start = AnchorStrings.value("tour.start", default: "Start using Anchor")
    static let skip = AnchorStrings.value("tour.skip", default: "Skip")

    // The task the person reads aloud.
    static let spokenTitle = AnchorStrings.value("tour.script.title", default: "Add dark mode to the app")
    static let spokenPlan = AnchorStrings.value("tour.script.plan", default: "First list the color variables, then replace the hard-coded colors, then add a dark value for each color, and finally check contrast on a real phone")

    // The two tasks already anchored, and their conversations.
    static let portfolio = AnchorStrings.value("tour.portfolio", default: "Launch the portfolio site")
    static let portfolioSteps = [
        AnchorStrings.value("tour.portfolio.step1", default: "Gather project screenshots"),
        AnchorStrings.value("tour.portfolio.step2", default: "Write the home page copy"),
        AnchorStrings.value("tour.portfolio.step3", default: "Deploy to Vercel"),
    ]
    static let homepage = AnchorStrings.value("tour.homepage", default: "Home layout")
    static let homepageRequest = AnchorStrings.value("tour.homepage.request", default: "Make the home page two columns: an intro on the left, three featured project cards on the right")
    static let homepageReply = AnchorStrings.value("tour.homepage.reply", default: "The two-column layout is in. On narrow screens it stacks. Preview at localhost:5173.")
    static let deploy = AnchorStrings.value("tour.deploy", default: "Deploy script")
    static let deployRequest = AnchorStrings.value("tour.deploy.request", default: "Write a GitHub Action that deploys to Vercel")
    static let deployReply = AnchorStrings.value("tour.deploy.reply", default: "Added .github/workflows/deploy.yml. Pushing to main deploys. Add VERCEL_TOKEN in the repository settings.")
    static let seo = AnchorStrings.value("tour.seo", default: "Page titles")
    static let seoRequest = AnchorStrings.value("tour.seo.request", default: "Give every page a title and a description")
    static let seoReply = AnchorStrings.value("tour.seo.reply", default: "Five pages now have titles and descriptions; the project pages use each project's summary.")
    static let homework = AnchorStrings.value("tour.homework", default: "Data analysis homework")
    static let homeworkSteps = [
        AnchorStrings.value("tour.homework.step1", default: "Clean the survey data"),
        AnchorStrings.value("tour.homework.step2", default: "Draw three charts"),
        AnchorStrings.value("tour.homework.step3", default: "Write the conclusion"),
    ]
    static let survey = AnchorStrings.value("tour.survey", default: "Clean survey")
    static let surveyRequest = AnchorStrings.value("tour.survey.request", default: "Handle the empty values and duplicate rows in survey.csv")
    static let surveyReply = AnchorStrings.value("tour.survey.reply", default: "37 rows have no age. Should I drop them, or fill in the median?")
    static let surveyPath = [
        AnchorStrings.value("tour.survey.path1", default: "Read survey.csv: 412 rows"),
        AnchorStrings.value("tour.survey.path2", default: "Removed 9 duplicate rows"),
    ]
    static let charts = AnchorStrings.value("tour.charts", default: "Chart script")
    static let chartsRequest = AnchorStrings.value("tour.charts.request", default: "Plot the satisfaction scores with matplotlib")
    static let chartsReply = AnchorStrings.value("tour.charts.reply", default: "Saved figures/satisfaction.png: scores 1–5 across, people up the side.")
    static let palette = AnchorStrings.value("tour.palette", default: "Color variables")
    static let paletteRequest = AnchorStrings.value("tour.palette.request", default: "List every hard-coded color in the project as a table of color variables")
    static let paletteReply = AnchorStrings.value("tour.palette.reply", default: "Found 42 hard-coded colors and folded them into 18 variables in Colors.swift.")
    static let replace = AnchorStrings.value("tour.replace", default: "Replace colors")
    static let replaceRequest = AnchorStrings.value("tour.replace.request", default: "Replace every hard-coded color with the new variables")

    // What the Mac writes for the return page.
    static let paletteRecap = AnchorStrings.value("tour.palette.recap", default: "Done: scanned 26 files and folded 42 hard-coded colors into 18 color variables in Colors.swift, each named for what it's for.")
    static let replaceRecap = AnchorStrings.value("tour.replace.recap", default: "In progress: swapping hard-coded colors for the new variables. 9 of 18 files are done, mostly home and settings; the lists should follow within 10 minutes.")
    static let seoRecap = AnchorStrings.value("tour.seo.recap", default: "Finished while you were away: all five pages now have titles and descriptions. Project pages use each project's summary; the home title keeps your name and focus.")
    static let homepageRecap = AnchorStrings.value("tour.homepage.recap", default: "The two-column home layout is in: an intro on the left, three featured project cards on the right. Narrow screens stack them; preview at localhost:5173.")
    static let deployRecap = AnchorStrings.value("tour.deploy.recap", default: "The deploy workflow is ready: pushing to main deploys to Vercel. One step is left for you: add VERCEL_TOKEN in the repository settings.")
    static let surveyRecap = AnchorStrings.value("tour.survey.recap", default: "Still waiting for you: 37 rows, about 8% of the survey, have no age. Drop them, or fill in the median of 24?")
    static let chartsRecap = AnchorStrings.value("tour.charts.recap", default: "The satisfaction chart is saved to figures/satisfaction.png: scores 1–5 across, people up the side. 4 is the most common, about 40%, so it leans satisfied.")
}
#endif
