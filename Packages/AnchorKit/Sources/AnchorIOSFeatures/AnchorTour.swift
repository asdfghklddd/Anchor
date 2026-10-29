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

/// The first-run tour. The real home, setup sheet, desk, away screen and
/// return page run on a pretend Mac, so someone without their computer can
/// try the whole loop: two tasks already anchored, one they drop themselves,
/// agents that report while the phone lies sideways and keep working while
/// the person is away, and the recaps waiting when they come back. Nothing
/// here touches the person's own tasks: the store lives in a temporary file
/// that goes when the tour ends.
@MainActor
@Observable
final class AnchorTour {
    enum Stage: Int, Comparable {
        /// The home's task library is lit.
        case tasks
        /// Today's anchoring clock and the agents' token bars are lit.
        case anchoring
        /// The anchor button is lit and waits for its tap.
        case anchorButton
        /// The setup sheet is up and dictates the third task.
        case setup
        /// The anchor is down; the phone is asked to turn.
        case turn
        /// The landscape desk, its folders lit one by one.
        case desk
        /// The question waiting on the homework is lit as it comes to the front.
        case waiting
        /// A friend asks the person down for coffee; the desk waits for the phone to come up.
        case called
        /// The phone is up: the link to the Mac stretches and breaks, and five minutes pass.
        case walkingAway
        /// The real away screen, with the agents still working.
        case away
        /// The phone comes back in range and the link joins again.
        case comingBack
        /// The real return page, with the Mac's recaps.
        case returned
        /// Back to Home: the sample tasks leave.
        case leaving
        /// The real workspace takes over.
        case finished

        static func < (lhs: Stage, rhs: Stage) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private(set) var stage = Stage.tasks
    let model: AnchorSessionModel
    let log: AnchoringLog

    @ObservationIgnored private let repository: LocalSessionRepository
    @ObservationIgnored private let storageURL: URL
    @ObservationIgnored private var work: [Task<Void, Never>] = []
    @ObservationIgnored private let mac: TourMac
    /// Answers the store like a paired Mac, so nothing on screen waits to be sent.
    @ObservationIgnored private var listener: Task<Void, Never>?
    /// The task the person dropped during the tour.
    @ObservationIgnored private var ownTask: UUID?
    /// Desk news not yet sent; leaving early sends the rest at once.
    @ObservationIgnored private var deskNews: [TourMac.Beat] = []

    /// The task whose question the desk lights.
    var waitingTaskID: UUID { mac.homeworkID }

    init() {
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

    /// A tap on the lit home or desk moves to the next part.
    func next() {
        switch stage {
        case .tasks: stage = .anchoring
        case .anchoring: stage = .anchorButton
        case .desk:
            stage = .waiting
            // The light settles on the folder first, then the question arrives under it.
            later(0.7) { [mac, model] in _ = await model.send(mac.question(now: .now)) }
        case .waiting: stage = .called
        default: break
        }
    }

    func setupOpened() {
        if stage <= .anchorButton { stage = .setup }
    }

    /// The sheet closed without a drop; the button is lit again.
    func setupClosed() {
        if stage == .setup { stage = .anchorButton }
    }

    /// The third anchor is down. Its agent starts a moment later, as if the
    /// person had opened Claude Code on the Mac.
    func dropped(_ taskID: UUID) {
        guard stage < .turn else { return }
        stage = .turn
        ownTask = taskID
        later(2.6) { [mac, model] in
            _ = await model.send(.forSession(taskID, .addProcess(mac.firstConversation(of: taskID, now: .now))))
        }
    }

    /// The desk is up, on a turned phone or drawn sideways under the lock.
    func reachedDesk() {
        guard stage == .turn else { return }
        stage = .desk
        deskNews = mac.deskNews()
        for beat in deskNews {
            later(beat.after) { [weak self] in await self?.send(beat) }
        }
    }

    /// The phone came up off the desk. Bluetooth to the Mac drops, five
    /// minutes pass, and the real away screen shows the agents still at it;
    /// then the phone is back in range and the real return page opens.
    func leftDesk() {
        guard stage >= .desk, stage <= .called else { return }
        stage = .walkingAway
        cancelWork()
        work.append(Task { [mac, model, ownTask] in
            for beat in self.deskNews { await self.send(beat) }
            // The anchor is weighed, then the link stretches and breaks.
            guard await Self.pause(TourLinkScene.breaksAt) else { return }
            _ = await model.send(.updateSignals(connection: .disconnected, proximity: .unknown, at: .now))
            guard await Self.pause(TourLinkScene.apartLength - TourLinkScene.breaksAt) else { return }
            let now = Date.now
            _ = await model.send(.updatePresence(.away, at: now, awaySince: now - 300))
            self.stage = .away

            var waited: TimeInterval = 0
            for beat in mac.awayNews(ownTask: ownTask) {
                guard await Self.pause(beat.after - waited) else { return }
                waited = beat.after
                _ = await model.send(beat.command(.now))
            }
            guard await Self.pause(Self.awayLength - waited) else { return }
            self.stage = .comingBack
            guard await Self.pause(TourLinkScene.togetherLength) else { return }
            let back = Date.now
            _ = await model.send(.updateSignals(connection: .connected, proximity: .near, at: back))
            _ = await model.send(.updatePresence(.returning, at: back))
            self.stage = .returned

            // The Mac takes a moment to write the recaps; the pet types meanwhile.
            guard await Self.pause(1.8) else { return }
            for (task, recap) in mac.recaps(returnedAt: back, ownTask: ownTask) {
                _ = await model.send(.forSession(task, .recordReturnRecap(recap)))
            }
        })
    }

    /// How long the away screen stays before the person comes back.
    private static let awayLength: TimeInterval = 6.5

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
                try? await Task.sleep(for: .milliseconds(180))
            }
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            self.stage = .finished
        })
    }

    /// Stops the pretend Mac and removes its files.
    func end() {
        cancelWork()
        listener?.cancel()
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
        let after: TimeInterval
        let command: (Date) -> SessionCommand
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
    func question(now: Date) -> SessionCommand {
        .forSession(homeworkID, .updateProcess(conversation(
            survey, in: homeworkID, agent: .codex, title: TourCopy.survey,
            request: TourCopy.surveyRequest, reply: TourCopy.surveyReply,
            status: .needsDecision, worked: 410, at: now)))
    }

    /// News while the person is away, timed from the away screen: their own
    /// colors are done and the next step starts, and the page titles finish.
    /// The survey's question stays unanswered.
    func awayNews(ownTask: UUID?) -> [Beat] {
        var beats: [Beat] = []
        if let ownTask {
            beats.append(Beat(after: 1.4) { now in
                .forSession(ownTask, .updateProcess(conversation(
                    palette, in: ownTask, agent: .claude, title: TourCopy.palette,
                    request: TourCopy.paletteRequest, reply: TourCopy.paletteReply,
                    status: .completed, worked: 640, at: now)))
            })
            beats.append(Beat(after: 2.6) { now in
                .forSession(ownTask, .addProcess(conversation(
                    replace, in: ownTask, agent: .claude, title: TourCopy.replace,
                    request: TourCopy.replaceRequest, status: .running, worked: 0, at: now)))
            })
        }
        beats.append(Beat(after: 4) { now in
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
    static let tasks = AnchorStrings.value("tour.tasks", default: "Today's goals and the conversations working on them.")
    static let anchoring = AnchorStrings.value("tour.anchoring", default: "Time anchored at your desk today, and how hard the AI worked.")
    static let anchorButton = AnchorStrings.value("tour.anchor", default: "Tap to drop anchor and start today's work.")
    static let tapToContinue = AnchorStrings.value("tour.continue", default: "Tap to continue")
    static let turn = AnchorStrings.value("tour.turn", default: "Turn your phone sideways to open the desk, with every task and the AI conversations behind it.")
    static let lockQuestion = AnchorStrings.value("tour.lock", default: "Portrait Orientation Lock on?")
    static let openHere = AnchorStrings.value("tour.lock.open", default: "Open the desk here")
    static let backUpright = AnchorStrings.value("tour.lock.back", default: "Back to the home")
    static let replay = AnchorStrings.value("tour.replay", default: "Replay the tour")
    static let folders = AnchorStrings.value("tour.folders", default: "Each folder is one of today's tasks, with the AI conversations working on it.")
    static let waiting = AnchorStrings.value("tour.waiting", default: "Red means a conversation is waiting for you.")
    static let called = AnchorStrings.value("tour.called", default: "A friend asks you down for coffee. Pick up your phone and go.")
    static let apart = AnchorStrings.value("tour.apart", default: "Away from your Mac for 5 minutes. Your agents keep working.")
    static let together = AnchorStrings.value("tour.together", default: "Back at your desk.")

    // The task the person dictates.
    static let spokenTitle = AnchorStrings.value("tour.script.title", default: "Add dark mode to the app")
    static let spokenPlan = AnchorStrings.value("tour.script.plan", default: "First list the color variables, then replace the hard-coded colors, finally check contrast on a real phone")

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
    static let charts = AnchorStrings.value("tour.charts", default: "Chart script")
    static let chartsRequest = AnchorStrings.value("tour.charts.request", default: "Plot the satisfaction scores with matplotlib")
    static let chartsReply = AnchorStrings.value("tour.charts.reply", default: "Saved figures/satisfaction.png: scores 1–5 across, people up the side.")
    static let palette = AnchorStrings.value("tour.palette", default: "Color variables")
    static let paletteRequest = AnchorStrings.value("tour.palette.request", default: "List every hard-coded color in the project as a table of color variables")
    static let paletteReply = AnchorStrings.value("tour.palette.reply", default: "Found 42 hard-coded colors and folded them into 18 variables in Colors.swift.")
    static let replace = AnchorStrings.value("tour.replace", default: "Replace colors")
    static let replaceRequest = AnchorStrings.value("tour.replace.request", default: "Replace every hard-coded color with the new variables")

    // What the Mac writes for the return page.
    static let paletteRecap = AnchorStrings.value("tour.palette.recap", default: "Done: 42 hard-coded colors are now 18 color variables.")
    static let replaceRecap = AnchorStrings.value("tour.replace.recap", default: "Swapping hard-coded colors for the new variables; 9 of 18 files so far.")
    static let seoRecap = AnchorStrings.value("tour.seo.recap", default: "Finished while you were away: five pages now have titles and descriptions.")
    static let homepageRecap = AnchorStrings.value("tour.homepage.recap", default: "The two-column home layout is in and stacks on narrow screens.")
    static let deployRecap = AnchorStrings.value("tour.deploy.recap", default: "The deploy workflow is added; it needs VERCEL_TOKEN in the repository settings.")
    static let surveyRecap = AnchorStrings.value("tour.survey.recap", default: "Still waiting for you: drop the 37 rows with no age, or fill in the median?")
    static let chartsRecap = AnchorStrings.value("tour.charts.recap", default: "The satisfaction chart is saved to figures/satisfaction.png.")
}
#endif
