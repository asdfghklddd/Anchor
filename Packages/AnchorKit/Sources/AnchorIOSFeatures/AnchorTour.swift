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
        /// The sample cards float up under a ring, and a line says what the library holds; the ring moves on by itself.
        case hello
        /// The anchor button is lit and waits for its tap.
        case anchorButton
        /// The setup sheet is up; the person reads the task aloud.
        case setup
        /// The anchor is down, and the real drop plays out on the home.
        case anchored
        /// An anchor brings no work by itself: on a small Mac the person opens
        /// an agent, and the Mac matches it to the new card.
        case agent
        /// The phone is asked to turn.
        case turn
        /// The landscape desk: the ring walks the folders and rests on the person's own.
        case desk
        /// The pet's nook is the clear part, waiting for a tap on the pet.
        case pet
        /// The question waiting on the thesis is lit as it comes to the front.
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
    @ObservationIgnored private var mac: TourMac
    /// Answers the store like a paired Mac, so nothing on screen waits to be sent.
    @ObservationIgnored private var listener: Task<Void, Never>?
    /// The task the person dropped during the tour.
    private(set) var ownTask: UUID?
    /// The Mac has matched the opened agent to the person's task.
    private(set) var agentFiled = false
    /// The agent opened on the Mac, by the person's tap or on its own.
    private(set) var pickedAgent: TourMac.Agent?
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
    var waitingTaskID: UUID { mac.thesisID }

    /// How long the dial runs, and the minutes on it that matter.
    static let dialMinutes = 30
    static let linkBreaksAt = 1
    static let awayAt = 5
    /// The first drop's moment on the home, before the phone is asked to turn.
    static let dropLength: TimeInterval = 3.0
    /// From picking an agent to the Mac matching it to the card, and to the turn.
    static let agentFiles: TimeInterval = 1.9
    /// How long the Mac waits for a tap before the first agent opens by itself.
    static let agentWait: TimeInterval = 1.5
    static let agentLength: TimeInterval = 3.4

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
    /// the tour shows where the work comes from: an agent opened on the Mac.
    func dropped(_ taskID: UUID) {
        guard stage < .anchored else { return }
        stage = .anchored
        ownTask = taskID
        later(Self.dropLength) { [weak self] in
            guard let self, self.stage == .anchored else { return }
            self.stage = .agent
            self.later(Self.agentWait) { [weak self] in self?.pickAgent(.claude) }
        }
    }

    /// An agent was opened on the Mac. It works a moment, the Mac matches it
    /// to the person's task, and then the phone is asked to turn.
    func pickAgent(_ agent: TourMac.Agent) {
        guard stage == .agent, pickedAgent == nil else { return }
        pickedAgent = agent
        mac.ownAgent = agent
        later(Self.agentFiles) { [weak self] in await self?.fileAgent() }
        later(Self.agentLength) { [weak self] in
            if self?.stage == .agent { self?.stage = .turn }
        }
    }

    /// The person's task gets its first conversation, once.
    private func fileAgent() async {
        guard !agentFiled, let ownTask else { return }
        agentFiled = true
        _ = await model.send(.forSession(ownTask, .addProcess(mac.firstConversation(of: ownTask, now: .now))))
    }

    /// The desk is up, on a turned phone or drawn sideways under the lock.
    /// The ring walks the folders and rests on the person's own, then moves
    /// to the pet; once it has been greeted, a question arrives on its own.
    func reachedDesk() {
        guard stage == .turn || stage == .agent || stage == .anchored else { return }
        stage = .desk
        // Turned before the Mac had matched anything: the folder still has its agent.
        later(0) { [weak self] in await self?.fileAgent() }
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

    /// The ring settles on the thesis first, then its question arrives under it.
    private func ask() {
        guard stage == .desk || stage == .pet else { return }
        stage = .waiting
        later(0.7) { [weak self] in await self?.sendQuestion() }
    }

    private func sendQuestion() async {
        guard !asked else { return }
        asked = true
        AnchorSound.shared.play(.question)
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
        AnchorSound.shared.stop()
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

    private let pricing = UUID()
    private let webhook = UUID()
    private let survey = UUID()
    private let refs = UUID()
    private let e2e = UUID()
    /// The agent the person opened for their own task.
    var ownAgent = Agent.claude
    private let crash = UUID()
    private let fix = UUID()
    private let proID = UUID()
    let thesisID = UUID()

    func seed(now: Date) -> [AnchorSession] {
        let pro = AnchorSession(
            id: proID,
            goal: AnchorGoal(title: TourCopy.pro, completionCriteria: "",
                             userPlan: AnchorUserPlan(steps: TourCopy.proSteps, completedSteps: [0], reviewedAt: now - 1_200)),
            startedAt: now - 9_000,
            processes: [
                conversation(pricing, in: proID, agent: .claude, title: TourCopy.pricing,
                             request: TourCopy.pricingRequest, status: .running, worked: 1_260, at: now - 200),
                conversation(webhook, in: proID, agent: .codex, title: TourCopy.webhook,
                             request: TourCopy.webhookRequest, reply: TourCopy.webhookReply,
                             status: .completed, worked: 540, at: now - 1_500),
            ],
            taskColorIndex: 0)
        let thesis = AnchorSession(
            id: thesisID,
            goal: AnchorGoal(title: TourCopy.thesis, completionCriteria: "",
                             userPlan: AnchorUserPlan(steps: TourCopy.thesisSteps, reviewedAt: now - 3_000)),
            startedAt: now - 6_000,
            processes: [
                // The survey is still cleaning; its question arrives on the desk.
                conversation(survey, in: thesisID, agent: .codex, title: TourCopy.survey,
                             request: TourCopy.surveyRequest, status: .running, worked: 380, at: now - 2_400),
                conversation(refs, in: thesisID, agent: .claude, title: TourCopy.refs,
                             request: TourCopy.refsRequest, reply: TourCopy.refsReply,
                             status: .completed, worked: 720, at: now - 420),
            ],
            taskColorIndex: 1)
        return [pro, thesis]
    }

    /// The person's own task gets its first conversation.
    func firstConversation(of taskID: UUID, now: Date) -> AnchorProcess {
        conversation(crash, in: taskID, agent: ownAgent, title: TourCopy.crash,
                     request: TourCopy.crashRequest, status: .running, worked: 0, at: now)
    }

    /// News while the desk is up: the pricing page's reply lands, and the
    /// billing tests start.
    func deskNews() -> [Beat] {
        [
            Beat(after: 4) { now in
                .forSession(proID, .updateProcess(conversation(
                    pricing, in: proID, agent: .claude, title: TourCopy.pricing,
                    request: TourCopy.pricingRequest, reply: TourCopy.pricingReply,
                    status: .completed, worked: 1_470, at: now)))
            },
            Beat(after: 8) { now in
                .forSession(proID, .addProcess(conversation(
                    e2e, in: proID, agent: .codex, title: TourCopy.e2e,
                    request: TourCopy.e2eRequest, status: .running, worked: 0, at: now)))
            },
        ]
    }

    /// The survey stops to ask the person something: on the desk it takes
    /// its task's color and an anchor, and comes to the front.
    /// Its card, opened, reads what the Mac took from the conversation.
    func question(now: Date) -> SessionCommand {
        var process = conversation(
            survey, in: thesisID, agent: .codex, title: TourCopy.survey,
            request: TourCopy.surveyRequest, reply: TourCopy.surveyReply,
            status: .needsDecision, worked: 410, at: now)
        process.digest = ConversationDigest(
            path: TourCopy.surveyPath,
            waiting: .init(kind: .answer, text: TourCopy.surveyReply),
            latestRequest: TourCopy.surveyRequest)
        return .forSession(thesisID, .updateProcess(process))
    }

    /// News while the person is away, by the minute on the dial: their own
    /// crash is found and the fix starts, and the billing tests finish.
    /// The survey's question stays unanswered.
    func awayNews(ownTask: UUID?) -> [Beat] {
        var beats: [Beat] = []
        if let ownTask {
            beats.append(Beat(after: 8, note: Note(title: TourCopy.crash, done: true)) { now in
                .forSession(ownTask, .updateProcess(conversation(
                    crash, in: ownTask, agent: ownAgent, title: TourCopy.crash,
                    request: TourCopy.crashRequest, reply: TourCopy.crashReply,
                    status: .completed, worked: 640, at: now)))
            })
            beats.append(Beat(after: 12, note: Note(title: TourCopy.fix, done: false)) { now in
                .forSession(ownTask, .addProcess(conversation(
                    fix, in: ownTask, agent: ownAgent, title: TourCopy.fix,
                    request: TourCopy.fixRequest, status: .running, worked: 0, at: now)))
            })
        }
        beats.append(Beat(after: 19, note: Note(title: TourCopy.e2e, done: true)) { now in
            .forSession(proID, .updateProcess(conversation(
                e2e, in: proID, agent: .codex, title: TourCopy.e2e,
                request: TourCopy.e2eRequest, reply: TourCopy.e2eReply,
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
            (proID, recap([(e2e, TourCopy.e2e, TourCopy.e2eRecap),
                                 (pricing, TourCopy.pricing, TourCopy.pricingRecap),
                                 (webhook, TourCopy.webhook, TourCopy.webhookRecap)])),
            (thesisID, recap([(survey, TourCopy.survey, TourCopy.surveyRecap),
                                (refs, TourCopy.refs, TourCopy.refsRecap)])),
        ]
        if let ownTask {
            recaps.insert((ownTask, recap([(fix, TourCopy.fix, TourCopy.fixRecap),
                                           (crash, TourCopy.crash, TourCopy.crashRecap)])), at: 0)
        }
        return recaps
    }

    enum Agent {
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
    static let agentOpen = AnchorStrings.value("tour.agent", default: "Now open your agent tool on your Mac.")
    static let agentFiled = AnchorStrings.value("tour.agent.filed", default: "Your Mac files it under this task.")
    static let turn = AnchorStrings.value("tour.turn", default: "Turn sideways into the workbench.")
    static let lockQuestion = AnchorStrings.value("tour.lock", default: "Portrait Orientation Lock on?")
    static let openHere = AnchorStrings.value("tour.lock.open", default: "Open the desk here")
    static let backUpright = AnchorStrings.value("tour.lock.back", default: "Back to the home")
    static let replay = AnchorStrings.value("tour.replay", default: "Replay the tour")
    static let folders = AnchorStrings.value("tour.folders", default: "Each folder is a task.")
    static let clock = AnchorStrings.value("tour.clock", default: "Your work time and tokens are recorded here.")
    static let library = AnchorStrings.value("tour.library", default: "Your anchored tasks live here.")
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
    static let spokenTitle = AnchorStrings.value("tour.script.title", default: "Fix the login screen crash")
    static let spokenPlan = AnchorStrings.value("tour.script.plan", default: "First read the crash logs to find the cause, then fix it and add a unit test, then run the regression tests, and finally ship the fix")

    // The two tasks already anchored, and their conversations.
    static let pro = AnchorStrings.value("tour.pro", default: "Ship Pro subscriptions")
    static let proSteps = [
        AnchorStrings.value("tour.pro.step1", default: "Hook up Stripe billing"),
        AnchorStrings.value("tour.pro.step2", default: "Build the pricing page"),
        AnchorStrings.value("tour.pro.step3", default: "Ship to production"),
    ]
    static let pricing = AnchorStrings.value("tour.pricing", default: "Pricing page")
    static let pricingRequest = AnchorStrings.value("tour.pricing.request", default: "Build the pricing page: Free and Pro tiers, Pro at $9 a month, with a yearly toggle")
    static let pricingReply = AnchorStrings.value("tour.pricing.reply", default: "The pricing page is in, with a monthly/yearly toggle. On narrow screens it stacks. Preview at localhost:5173.")
    static let webhook = AnchorStrings.value("tour.webhook", default: "Stripe webhook")
    static let webhookRequest = AnchorStrings.value("tour.webhook.request", default: "Handle Stripe’s payment webhook: turn on Pro when a payment succeeds")
    static let webhookReply = AnchorStrings.value("tour.webhook.reply", default: "Added /api/webhooks/stripe with signature checks and idempotency. Set STRIPE_WEBHOOK_SECRET before going live.")
    static let e2e = AnchorStrings.value("tour.e2e", default: "Billing tests")
    static let e2eRequest = AnchorStrings.value("tour.e2e.request", default: "Write end-to-end tests for the subscription flow with Playwright")
    static let e2eReply = AnchorStrings.value("tour.e2e.reply", default: "Wrote 6 tests covering upgrade, renewal, cancellation and failed payments. All pass.")
    static let thesis = AnchorStrings.value("tour.thesis", default: "Thesis data analysis")
    static let thesisSteps = [
        AnchorStrings.value("tour.thesis.step1", default: "Clean the survey data"),
        AnchorStrings.value("tour.thesis.step2", default: "Run the regression"),
        AnchorStrings.value("tour.thesis.step3", default: "Write chapter 4"),
    ]
    static let survey = AnchorStrings.value("tour.survey", default: "Clean survey")
    static let surveyRequest = AnchorStrings.value("tour.survey.request", default: "Handle the empty values and duplicate rows in survey.csv")
    static let surveyReply = AnchorStrings.value("tour.survey.reply", default: "37 rows have no age. Should I drop them, or fill in the median?")
    static let surveyPath = [
        AnchorStrings.value("tour.survey.path1", default: "Read survey.csv: 412 rows"),
        AnchorStrings.value("tour.survey.path2", default: "Removed 9 duplicate rows"),
    ]
    static let refs = AnchorStrings.value("tour.refs", default: "References")
    static let refsRequest = AnchorStrings.value("tour.refs.request", default: "Format the 32 entries in refs.bib in APA 7th style")
    static let refsReply = AnchorStrings.value("tour.refs.reply", default: "All 32 are formatted in references.docx. 2 are missing page numbers and are marked.")
    static let crash = AnchorStrings.value("tour.crash", default: "Find the crash")
    static let crashRequest = AnchorStrings.value("tour.crash.request", default: "Read crash.log and find out why the login screen crashes")
    static let crashReply = AnchorStrings.value("tour.crash.reply", default: "Found it: when the login expires, the refresh callback force-unwraps nil at AuthSession.swift line 142.")
    static let fix = AnchorStrings.value("tour.fix", default: "Fix the crash")
    static let fixRequest = AnchorStrings.value("tour.fix.request", default: "Remove the force-unwrap and add a unit test for an expired login")

    // What the Mac writes for the return page.
    static let crashRecap = AnchorStrings.value("tour.crash.recap", default: "Done: crash.log points to the cause. When the login expires, the refresh callback force-unwraps nil at AuthSession.swift line 142.")
    static let fixRecap = AnchorStrings.value("tour.fix.recap", default: "In progress: AuthSession.swift is fixed and 3 new unit tests pass. The full regression suite should finish within 10 minutes.")
    static let e2eRecap = AnchorStrings.value("tour.e2e.recap", default: "Finished while you were away: 6 end-to-end tests cover upgrade, renewal, cancellation and failed payments. All pass.")
    static let pricingRecap = AnchorStrings.value("tour.pricing.recap", default: "The pricing page is in: Free and Pro tiers, Pro at $9 a month with a yearly toggle. Narrow screens stack them; preview at localhost:5173.")
    static let webhookRecap = AnchorStrings.value("tour.webhook.recap", default: "The webhook is ready: a successful payment turns on Pro. One step is left for you: set STRIPE_WEBHOOK_SECRET in production.")
    static let surveyRecap = AnchorStrings.value("tour.survey.recap", default: "Still waiting for you: 37 rows, about 8% of the survey, have no age. Drop them, or fill in the median of 24?")
    static let refsRecap = AnchorStrings.value("tour.refs.recap", default: "The references are done: all 32 are in references.docx in APA 7th style. 2 are missing page numbers, so those need you.")
}
#endif
