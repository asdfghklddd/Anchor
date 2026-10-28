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

/// The first-run tour. The real home, setup sheet and desk run on a pretend
/// Mac, so someone without their computer can try the whole loop: two tasks
/// already anchored, one they drop themselves, and agents that report while
/// the phone lies sideways. Nothing here touches the person's own tasks: the
/// store lives in a temporary file that goes when the tour ends.
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
        /// The landscape desk, with agents reporting.
        case desk
        /// Back upright: the sample tasks leave.
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

    /// A tap on the lit home moves to the next part.
    func next() {
        switch stage {
        case .tasks: stage = .anchoring
        case .anchoring: stage = .anchorButton
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
        for beat in mac.beats(ownTask: ownTask) {
            later(beat.after) { [model] in _ = await model.send(beat.command(.now)) }
        }
    }

    /// Upright again after the desk: the sample tasks leave, then the
    /// person's own workspace takes over.
    func leave() {
        guard stage == .desk else { return }
        stage = .leaving
        cancelWork()
        work.append(Task { [model] in
            // The anchor is weighed first.
            try? await Task.sleep(for: .seconds(1.4))
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
}

// MARK: The pretend Mac

/// What a Mac with Codex and Claude Code open would report: two tasks with
/// their conversations, and the news that arrives while the desk is up.
private struct TourMac {
    struct Beat {
        let after: TimeInterval
        let command: (Date) -> SessionCommand
    }

    private let homepage = UUID()
    private let deploy = UUID()
    private let survey = UUID()
    private let charts = UUID()
    private let seo = UUID()
    private let palette = UUID()
    private let portfolioID = UUID()
    private let homeworkID = UUID()

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
                conversation(survey, in: homeworkID, agent: .codex, title: TourCopy.survey,
                             request: TourCopy.surveyRequest, reply: TourCopy.surveyReply,
                             status: .needsDecision, worked: 380, at: now - 420),
                conversation(charts, in: homeworkID, agent: .claude, title: TourCopy.charts,
                             request: TourCopy.chartsRequest, reply: TourCopy.chartsReply,
                             status: .completed, worked: 720, at: now - 2_400),
            ],
            taskColorIndex: 1)
        return [portfolio, homework]
    }

    /// The person's own task gets its first conversation.
    func firstConversation(of taskID: UUID, now: Date) -> AnchorProcess {
        conversation(palette, in: taskID, agent: .claude, title: TourCopy.palette,
                     request: TourCopy.paletteRequest, status: .running, worked: 0, at: now)
    }

    /// News for the desk: a reply lands, the person's own agent finishes, and
    /// another conversation starts. The question on the homework stays, red.
    /// Each beat is written when it arrives, so it is newer than what it updates.
    func beats(ownTask: UUID?) -> [Beat] {
        var beats = [
            Beat(after: 4) { now in
                .forSession(portfolioID, .updateProcess(conversation(
                    homepage, in: portfolioID, agent: .claude, title: TourCopy.homepage,
                    request: TourCopy.homepageRequest, reply: TourCopy.homepageReply,
                    status: .completed, worked: 1_470, at: now)))
            },
            Beat(after: 10) { now in
                .forSession(portfolioID, .addProcess(conversation(
                    seo, in: portfolioID, agent: .codex, title: TourCopy.seo,
                    request: TourCopy.seoRequest, status: .running, worked: 0, at: now)))
            },
            Beat(after: 26) { now in
                .forSession(portfolioID, .updateProcess(conversation(
                    seo, in: portfolioID, agent: .codex, title: TourCopy.seo,
                    request: TourCopy.seoRequest, reply: TourCopy.seoReply,
                    status: .completed, worked: 310, at: now)))
            },
        ]
        if let ownTask {
            beats.append(Beat(after: 16) { now in
                .forSession(ownTask, .updateProcess(conversation(
                    palette, in: ownTask, agent: .claude, title: TourCopy.palette,
                    request: TourCopy.paletteRequest, reply: TourCopy.paletteReply,
                    status: .completed, worked: 640, at: now)))
            })
        }
        return beats
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
}
#endif
