#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation

/// The Mac's replay of the tour: the real island, fed by a pretend iPhone and
/// pretend agents instead of the person's own. It tells the same story as the
/// iPhone tour, with the same tasks and conversations, a scene per press of
/// ⌃⌥→; the pointer and clicks stay the person's own.
public struct MacDemoScript: Sendable {
    public enum Scene: Int, CaseIterable, Sendable {
        /// Two tasks the agents already work on, their conversations caught.
        case opening
        /// The phone drops an anchor: a third task and its first conversation.
        case dropped
        /// The home layout is done.
        case finished
        /// The survey waits for the person.
        case waiting
        /// The color variables are done and the phone ticks off the first step.
        case closing

        public var next: Scene? { Scene(rawValue: rawValue + 1) }
    }

    private let pro = UUID()
    private let thesis = UUID()
    private let own = UUID()
    private let pricing = UUID()
    private let webhook = UUID()
    private let survey = UUID()
    private let refs = UUID()
    private let crash = UUID()
    private let firstStep = UUID()

    public init() {}

    /// Every task the demo puts on the island, to take them off again.
    public var taskIDs: Set<UUID> { [pro, thesis, own] }

    public func commands(for scene: Scene, now: Date) -> [SessionCommand] {
        switch scene {
        case .opening:
            [
                .updateSignals(connection: .connected, proximity: .near, at: now),
                .hostSession(AnchorSession(
                    id: thesis,
                    goal: AnchorGoal(title: Copy.thesis, completionCriteria: "",
                                     userPlan: AnchorUserPlan(steps: Copy.thesisSteps, reviewedAt: now - 3_000)),
                    startedAt: now - 6_000,
                    processes: [
                        conversation(survey, in: thesis, agent: .codex, title: Copy.survey,
                                     request: Copy.surveyRequest, status: .running, at: now - 240),
                        conversation(refs, in: thesis, agent: .claude, title: Copy.refs,
                                     request: Copy.refsRequest, status: .completed, at: now - 1_500),
                    ],
                    taskColorIndex: 1)),
                .hostSession(AnchorSession(
                    id: pro,
                    goal: AnchorGoal(title: Copy.pro, completionCriteria: "",
                                     userPlan: AnchorUserPlan(steps: Copy.proSteps, completedSteps: [0],
                                                              reviewedAt: now - 1_200)),
                    startedAt: now - 9_000,
                    processes: [
                        conversation(pricing, in: pro, agent: .claude, title: Copy.pricing,
                                     request: Copy.pricingRequest, status: .running, at: now - 200),
                        conversation(webhook, in: pro, agent: .codex, title: Copy.webhook,
                                     request: Copy.webhookRequest, status: .completed, at: now - 1_800),
                    ],
                    taskColorIndex: 0)),
                .selectSession(pro),
            ]
        case .dropped:
            [
                .hostSession(AnchorSession(
                    id: own,
                    goal: AnchorGoal(title: Copy.ownTitle, completionCriteria: "",
                                     userPlan: AnchorUserPlan(items: ownSteps, reviewedAt: now)),
                    startedAt: now,
                    processes: [
                        conversation(crash, in: own, agent: .claude, title: Copy.crash,
                                     request: Copy.crashRequest, status: .running, at: now),
                    ],
                    taskColorIndex: 2)),
                .selectSession(own),
            ]
        case .finished:
            [
                .forSession(pro, .updateProcess(conversation(
                    pricing, in: pro, agent: .claude, title: Copy.pricing,
                    request: Copy.pricingRequest, status: .completed, at: now))),
            ]
        case .waiting:
            [
                .forSession(thesis, .updateProcess(conversation(
                    survey, in: thesis, agent: .codex, title: Copy.survey,
                    request: Copy.surveyRequest, status: .needsDecision, at: now))),
            ]
        case .closing:
            [
                .forSession(own, .updateProcess(conversation(
                    crash, in: own, agent: .claude, title: Copy.crash,
                    request: Copy.crashRequest, status: .completed, at: now))),
                .forSession(own, .setPlanStep(id: firstStep, done: true)),
            ]
        }
    }

    /// The plan read aloud in the iPhone tour, split the way the phone splits it.
    private var ownSteps: [AnchorUserPlan.Step] {
        let texts = PlanStepSplitter.steps(from: Copy.ownPlan)
        let steps = texts.isEmpty ? [Copy.ownPlan] : texts
        return steps.enumerated().map { index, text in
            AnchorUserPlan.Step(id: index == 0 ? firstStep : UUID(), text: text)
        }
    }

    private enum Agent {
        case codex, claude
        var name: String { self == .codex ? "Codex" : "Claude Code" }
    }

    private func conversation(_ id: UUID, in taskID: UUID, agent: Agent, title: String, request: String,
                              status: ProcessStatus, at date: Date) -> AnchorProcess {
        var process = AnchorProcess(id: id, sessionID: taskID, sourceID: id, sourceName: agent.name, sourceSymbol: "C",
                                    sourceTone: "cyan", title: title, status: status, updatedAt: date)
        process.request = request
        return process
    }

    /// The iPhone tour's words, so both films show the same work.
    private enum Copy {
        static let pro = AnchorStrings.value("tour.pro", default: "Ship Pro subscriptions")
        static let proSteps = [
            AnchorStrings.value("tour.pro.step1", default: "Hook up Stripe billing"),
            AnchorStrings.value("tour.pro.step2", default: "Build the pricing page"),
            AnchorStrings.value("tour.pro.step3", default: "Ship to production"),
        ]
        static let pricing = AnchorStrings.value("tour.pricing", default: "Pricing page")
        static let pricingRequest = AnchorStrings.value("tour.pricing.request", default: "Build the pricing page: Free and Pro tiers, Pro at $9 a month, with a yearly toggle")
        static let webhook = AnchorStrings.value("tour.webhook", default: "Stripe webhook")
        static let webhookRequest = AnchorStrings.value("tour.webhook.request", default: "Handle Stripe’s payment webhook: turn on Pro when a payment succeeds")
        static let thesis = AnchorStrings.value("tour.thesis", default: "Thesis data analysis")
        static let thesisSteps = [
            AnchorStrings.value("tour.thesis.step1", default: "Clean the survey data"),
            AnchorStrings.value("tour.thesis.step2", default: "Run the regression"),
            AnchorStrings.value("tour.thesis.step3", default: "Write chapter 4"),
        ]
        static let survey = AnchorStrings.value("tour.survey", default: "Clean survey")
        static let surveyRequest = AnchorStrings.value("tour.survey.request", default: "Handle the empty values and duplicate rows in survey.csv")
        static let refs = AnchorStrings.value("tour.refs", default: "References")
        static let refsRequest = AnchorStrings.value("tour.refs.request", default: "Format the 32 entries in refs.bib in APA 7th style")
        static let ownTitle = AnchorStrings.value("tour.script.title", default: "Fix the login screen crash")
        static let ownPlan = AnchorStrings.value("tour.script.plan", default: "First read the crash logs to find the cause, then fix it and add a unit test, then run the regression tests, and finally ship the fix")
        static let crash = AnchorStrings.value("tour.crash", default: "Find the crash")
        static let crashRequest = AnchorStrings.value("tour.crash.request", default: "Read crash.log and find out why the login screen crashes")
    }
}

/// Plays the script into the island's repository, one scene at a time, in
/// the order the keys were pressed.
@MainActor
public final class MacDemoDirector {
    public typealias Repository = SessionRepository & DataResetting

    /// A waiting agent's peek is shorter in the film than in use.
    public static let waitingPeek: Duration = .seconds(4)

    private let repository: any Repository
    private let onFinished: @MainActor () -> Void
    private var script = MacDemoScript()
    public private(set) var scene: MacDemoScript.Scene?
    private var work: Task<Void, Never>?

    /// `onFinished` runs on a press after the last scene.
    public init(repository: any Repository, onFinished: @escaping @MainActor () -> Void = {}) {
        self.repository = repository
        self.onFinished = onFinished
    }

    /// Sets the opening scene.
    public func start() {
        enqueue { [self] in await play(.opening) }
    }

    /// The next scene; after the last one, the end.
    public func advance() {
        enqueue { [self] in
            guard let scene else { return }
            guard let next = scene.next else {
                onFinished()
                return
            }
            await play(next)
        }
    }

    /// Takes the demo's tasks off and sets the opening again. `cleared` runs
    /// in between, so the island can forget what it has seen.
    public func restart(cleared: @escaping @MainActor () -> Void) {
        enqueue { [self] in
            try? await repository.forgetTasks(script.taskIDs)
            script = MacDemoScript()
            scene = nil
            cleared()
            await play(.opening)
        }
    }

    /// Waits for the scenes asked for so far.
    public func settle() async {
        await work?.value
    }

    private func enqueue(_ step: @escaping @MainActor () async -> Void) {
        let previous = work
        work = Task { @MainActor in
            await previous?.value
            await step()
        }
    }

    private func play(_ scene: MacDemoScript.Scene) async {
        for command in script.commands(for: scene, now: .now) {
            try? await repository.send(command)
        }
        self.scene = scene
    }
}

/// Replaying the tour restarts Anchor into the demo, and its end restarts
/// Anchor as it was. The request is kept for one launch only, so quitting
/// in the middle comes back to the person's own tasks.
public enum MacDemoLaunch {
    static let pendingKey = "anchor.mac.demo.pending"
    static let defaultsSuite = "com.andywang.anchor.demo"

    @MainActor
    public static func requestAndRelaunch(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: pendingKey)
        MacSingleInstance.relaunch()
    }

    @MainActor
    public static func endAndRelaunch() {
        MacSingleInstance.relaunch()
    }

    /// Whether this launch plays the demo; clears the request.
    public static func takePending(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.bool(forKey: pendingKey) else { return false }
        defaults.removeObject(forKey: pendingKey)
        return true
    }

    /// An empty folder for this run's tasks; the last run's goes.
    public static func freshStorage() -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "AnchorDemo", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: root)
        let folder = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Settings of the demo's own, starting empty, so the person's stay as they are.
    public static func freshDefaults() -> UserDefaults? {
        UserDefaults.standard.removePersistentDomain(forName: defaultsSuite)
        return UserDefaults(suiteName: defaultsSuite)
    }
}

enum MacDemoCopy {
    static let next = AnchorStrings.value("mac.demo.next", default: "Continue")
    /// The iPhone's words for the same thing.
    static let replay = AnchorStrings.value("tour.replay", default: "Replay the tour")
}

/// The phone at the other end of the demo: paired, over Bluetooth.
public struct MacDemoLink: LocalLinkControlling {
    public init() {}

    public func currentPairingCode() async -> String? { nil }

    public func pairingStatusUpdates() -> AsyncStream<DevicePairingStatus> {
        AsyncStream { continuation in
            continuation.yield(DevicePairingStatus(
                phase: .connected, route: .bluetooth,
                peerDeviceInfo: PeerDeviceInfo(name: "iPhone", model: "iPhone", systemName: "iOS", systemVersion: "26.1")))
        }
    }

    public func pair(using code: String) async throws {}

    public func retryConnection() async {}
}
#endif
