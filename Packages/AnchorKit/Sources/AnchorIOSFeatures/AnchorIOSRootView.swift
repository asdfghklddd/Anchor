#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The app's root: the person's own workspace, or the first-run tour in its
/// place until the tour ends. Settings can play the tour again at any time,
/// so the phone can be handed to someone without a Mac to try Anchor.
public struct AnchorIOSRootView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let currentProcessProvider: (any CurrentProcessProviding)?
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?
    private let recoveryReviewInterval: TimeInterval
    /// Starts Bluetooth and sync, which the first run holds back until the
    /// tour ends so the system prompt arrives where the connection is shown.
    private let startLink: () -> Void
    @State private var tour: AnchorTour?
    /// The first run starts with the tour; it is made once the scene appears,
    /// since this view's initializer can run more than once.
    @State private var awaitsTour: Bool
    /// The tour just ended: the person's workspace opens on the connection card.
    @State private var connectsAfterTour = false

    public init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)? = nil,
        currentProcessProvider: (any CurrentProcessProviding)? = nil,
        auxiliaryToolbarLabel: String? = nil,
        auxiliaryToolbarAction: (() -> Void)? = nil,
        recoveryReviewInterval: TimeInterval = 86_400,
        tourPending: Bool = false,
        startLink: @escaping () -> Void = {}
    ) {
        self.model = model
        self.linkController = linkController
        self.currentProcessProvider = currentProcessProvider
        self.auxiliaryToolbarLabel = auxiliaryToolbarLabel
        self.auxiliaryToolbarAction = auxiliaryToolbarAction
        self.recoveryReviewInterval = recoveryReviewInterval
        self.startLink = startLink
        _awaitsTour = State(initialValue: tourPending)
    }

    public var body: some View {
        AnchorLaunchGate {
            ZStack {
                if let tour {
                    AnchorWorkspaceView(model: tour.model, recoveryReviewInterval: recoveryReviewInterval,
                                        tour: tour, log: tour.log)
                        // Above every sheet the workspace presents.
                        .environment(\.anchorTour, tour)
                        .transition(.opacity)
                } else if awaitsTour {
                    // Under the launch splash for the moment before the tour is made.
                    Color.clear
                } else {
                    AnchorWorkspaceView(
                        model: model,
                        linkController: linkController,
                        currentProcessProvider: currentProcessProvider,
                        auxiliaryToolbarLabel: auxiliaryToolbarLabel,
                        auxiliaryToolbarAction: auxiliaryToolbarAction,
                        recoveryReviewInterval: recoveryReviewInterval,
                        opensConnections: connectsAfterTour
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.45), value: tour == nil)
        }
        .background { HarborBackground() }
        .environment(\.replayTour, replayTour)
        .onAppear {
            if awaitsTour, tour == nil { tour = AnchorTour() }
        }
        .onChange(of: tour?.stage) { _, stage in
            if stage == .finished { finishTour() }
        }
    }

    private func replayTour() {
        connectsAfterTour = false
        tour = AnchorTour()
    }

    private func finishTour() {
        tour?.end()
        AnchorTourGate.markDone()
        awaitsTour = false
        startLink()
        connectsAfterTour = true
        tour = nil
    }
}

/// One workspace: the portrait home, the landscape desk, and their sheets,
/// for the person's own tasks or for the tour's.
struct AnchorWorkspaceView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let currentProcessProvider: (any CurrentProcessProviding)?
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?
    private let recoveryReviewInterval: TimeInterval
    private let tour: AnchorTour?
    private let log: AnchoringLog
    private let opensConnections: Bool

    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [AnchorRoute] = []
    @State private var sheet: AnchorSheet?
    @State private var setupDraft = AnchorSetupDraft()
    @State private var suspendedSetup = false
    @State private var fullScreen: AnchorFullScreen?
    @State private var invitation = WorkInvitation()
    @State private var harborMode: WorkInvitationHarbor.Mode?
    @State private var arrivalPending = false
    @State private var invitationDeferred = false
    @State private var anchorDrops = 0
    /// The task just anchored floats until its anchor catches, then settles (D10).
    @State private var settlingTaskID: UUID?
    @State private var settledTaskID: UUID?
    @State private var anchorSettles = 0
    @AnchorReducedMotion private var reduceMotion
    @State private var anchorWeighs = 0
    @State private var gravity = DeviceGravityMonitor()
    @State private var posture = DevicePosture.unknown
    @State private var promptedRecoverySessionID: UUID?
    /// The phone came off the desk during work: show the pick-up card (D05).
    @State private var pickedUp = false
    /// A fourth anchor was asked for; the home explains the three-task limit.
    @State private var showsCapNote = false
    @State private var reminder = DeskReminder()
    @AppStorage(DeskReminder.enabledKey) private var reminderEnabled = true
    @AppStorage(DeskReminder.minutesKey) private var reminderMinutes = DeskReminder.defaultMinutes
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var processTransition
    /// The tour's desk drawn sideways, for a screen held by orientation lock.
    @State private var showsSidewaysDesk = false

    init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)? = nil,
        currentProcessProvider: (any CurrentProcessProviding)? = nil,
        auxiliaryToolbarLabel: String? = nil,
        auxiliaryToolbarAction: (() -> Void)? = nil,
        recoveryReviewInterval: TimeInterval = 86_400,
        tour: AnchorTour? = nil,
        log: AnchoringLog = .shared,
        opensConnections: Bool = false
    ) {
        self.model = model
        self.linkController = linkController
        self.currentProcessProvider = currentProcessProvider
        self.auxiliaryToolbarLabel = auxiliaryToolbarLabel
        self.auxiliaryToolbarAction = auxiliaryToolbarAction
        self.recoveryReviewInterval = recoveryReviewInterval
        self.tour = tour
        self.log = log
        self.opensConnections = opensConnections
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if shouldShowLandscapeDashboard {
                    LandscapeAmbientDashboard(
                        projection: model.projection,
                        playsArrival: arrivalPending,
                        onTask: openHostedTask,
                        onManage: { sheet = .hostedTasks }
                    )
                    .tourDeskCoach(tour)
                } else {
                    PortraitDashboard(
                        projection: model.projection,
                        auxiliaryToolbarLabel: auxiliaryToolbarLabel,
                        auxiliaryToolbarAction: auxiliaryToolbarAction,
                        transitionNamespace: processTransition,
                        onRoute: { route in
                            // The tour stays on its home; the person's own pages wait for them.
                            if tour == nil { path.append(route) }
                        },
                        onSheet: { requested in
                            if requested == .setup, atTaskLimit { showsCapNote = true }
                            else if tour == nil || requested == .setup { sheet = requested }
                        },
                        onTask: openHostedTask,
                        invitation: harborMode,
                        onInvitationEnd: endHarbor,
                        anchorDrops: anchorDrops,
                        anchorWeighs: anchorWeighs,
                        gravity: gravity,
                        settlingTaskID: settlingTaskID,
                        settledTaskID: settledTaskID,
                        anchorSettles: anchorSettles,
                        showsCapNote: showsCapNote,
                        onCapNoteDismiss: { showsCapNote = false },
                        onCompleteTask: { await model.send(.forSession($0, .completeSession)) },
                        log: log
                    )
                    .overlayPreferenceValue(TourSpotKey.self) { anchors in
                        if let tour {
                            GeometryReader { proxy in
                                TourCoach(tour: tour, spots: anchors.mapValues { proxy[$0] }, size: proxy.size,
                                          inviting: harborMode == .inviting, gravity: gravity,
                                          onSideways: openSidewaysDesk)
                            }
                            .ignoresSafeArea()
                        }
                    }
                    .overlay { if let tour { TourTapLayer(tour: tour) } }
                    .overlay {
                        if pickedUp, let hold = deskHold {
                            DeskPickUpCard(
                                hold: hold,
                                current: deskCurrent,
                                tasks: model.projection.hostedSessions,
                                reminderEnabled: reminderEnabled,
                                reminderMinutes: reminderMinutes,
                                reminderAuthorization: reminder.authorization,
                                onSelect: { id in Task { _ = await model.selectHostedTask(id) } },
                                onAllowReminder: { Task { await reminder.requestAuthorization() } },
                                onUseAnyway: { pickedUp = false }
                            )
                            // It is there the moment the phone turns; it fades when dismissed.
                            .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        }
                    }
                    .animation(AnchorMotion.micro, value: pickedUp)
                }
            }
            .navigationDestination(for: AnchorRoute.self) { route in
                destination(for: route)
            }
        }
        .overlay {
            if showsSidewaysDesk, let tour {
                TourSidewaysDesk(tour: tour, projection: model.projection, gravity: gravity) {
                    showsSidewaysDesk = false
                    tour.leftDesk()
                }
                .transition(.opacity)
            }
        }
        .animation(AnchorMotion.panel, value: showsSidewaysDesk)
        .overlay {
            if tour?.stage == .walkingAway {
                TourLinkScene(mode: .apart)
                    .transition(.opacity)
            }
        }
        .animation(AnchorMotion.panel, value: tour?.stage == .walkingAway)
        .environment(\.openConnectionCard, { sheet = .connections })
        .tint(AnchorIOSStyle.action)
        .background { HarborBackground() }
        .sheet(item: $sheet) { item in
            sheetDestination(for: item)
                .tint(AnchorIOSStyle.action)
                .presentationBackground(item == .connections ? AnchorIOSStyle.surface : AnchorIOSStyle.canvasTop)
                .presentationCornerRadius(item == .connections ? 32 : (item == .setup ? 36 : 24))
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { fullScreen != nil },
                set: { isPresented in
                    if !isPresented { fullScreen = nil }
                }
            )
        ) {
            fullScreenDestination(for: fullScreen ?? .away)
        }
        .onGeometryChange(for: DevicePosture.self) { geometry in
            // Keyboard insets are part of the screen, not a change in device posture.
            let insets = geometry.safeAreaInsets
            let width = geometry.size.width + insets.leading + insets.trailing
            let height = geometry.size.height + insets.top + insets.bottom
            guard width > 0, height > 0 else { return .unknown }
            return width > height ? .landscape : .portrait
        } action: { newPosture in
            guard newPosture != posture else { return }
            let previous = posture
            posture = newPosture
            if let tour {
                if newPosture == .landscape {
                    showsSidewaysDesk = false
                    tour.reachedDesk()
                } else if previous == .landscape {
                    tour.leftDesk()
                }
            }
            notePickUp(from: previous, to: newPosture)
            synchronizeInvitation()
            // A rotation pauses setup without discarding its input or task identity.
            if newPosture == .landscape, sheet == .setup {
                suspendedSetup = true
                sheet = nil
            } else if newPosture == .portrait, suspendedSetup, sheet == nil {
                suspendedSetup = false
                sheet = .setup
            }
            // The empty workspace has no session to reduce a presence update into.
            // Remember the posture now and apply it once an anchor exists.
            guard model.projection.session != nil else { return }
            Task { await model.updatePosture(newPosture) }
        }
        .onChange(of: model.projection.session?.presence, initial: true) { previous, presence in
            // Coming back to the desk after being away invites again (D08);
            // in the tour, Back to Home ends it.
            if previous == .returning, presence == .atDesk {
                if let tour { tour.leave() } else { invitation.beginDeskSession() }
            }
            synchronizeCover(with: presence)
            synchronizeInvitation()
        }
        .onChange(of: model.projection.session?.returnSummary?.generatedAt) { _, generatedAt in
            guard generatedAt != nil, model.projection.session?.presence == .returning else { return }
            sheet = nil
            suspendedSetup = false
            fullScreen = .returning
        }
        .onChange(of: invitationInputs) { _, _ in synchronizeInvitation() }
        .onChange(of: model.projection.session?.id) { _, sessionID in
            if sessionID != nil {
                Task { await model.updatePosture(posture) }
            }
            evaluateRecoveryReview(for: sessionID)
        }
        .onChange(of: sheet) { previousSheet, presentedSheet in
            if presentedSheet == .setup {
                suspendedSetup = false
                tour?.setupOpened()
            }
            guard presentedSheet == nil else {
                holdInvitationBehindCover()
                return
            }
            // The success ending plays first; a waiting invitation follows it.
            let dropped = previousSheet == .setup && setupDraft.wasCreated
            if dropped { playDrop(of: setupDraft.hostedTaskID, titled: setupDraft.goalTitle) }
            if let tour, previousSheet == .setup {
                if dropped {
                    // The turn is offered once the anchor has caught, as after any drop.
                    tour.dropped(setupDraft.hostedTaskID)
                    synchronizeInvitation(holdingOffer: true)
                } else {
                    tour.setupClosed()
                }
            }
            presentDeferredInvitation(after: dropped ? 1.9 : 0.4)
            if suspendedSetup, posture == .portrait {
                suspendedSetup = false
                sheet = .setup
                return
            }
            // Closing keeps the draft. Only a successful submission or an explicit
            // discard consumes its input and task identity.
            if previousSheet == .setup, setupDraft.isConsumed { setupDraft = AnchorSetupDraft() }
            evaluateRecoveryReview(for: model.projection.session?.id)
        }
        .onChange(of: fullScreen) { _, presentedCover in
            guard presentedCover == nil else {
                holdInvitationBehindCover()
                return
            }
            presentDeferredInvitation(after: 0.4)
            evaluateRecoveryReview(for: model.projection.session?.id)
        }
        .alert(
            L10n.actionFailed,
            isPresented: Binding(
                get: { model.lastError != nil },
                set: { isPresented in
                    if !isPresented { model.dismissLastError() }
                }
            )
        ) {
            Button(L10n.done) { model.dismissLastError() }
        } message: {
            Text(model.lastError ?? "")
        }
        .onChange(of: scenePhase) { _, phase in noteScenePhase(phase) }
        // Once nothing holds the person at the desk, or they are away, the pick-up
        // is over: a later run must not bring the card back while they use the phone.
        .onChange(of: deskHold == nil || !isAtDesk) { _, released in
            if released { pickedUp = false }
        }
        .task {
            // The tour starts its own model once its sample tasks are in place.
            if tour == nil { model.start() }
            await reminder.refresh()
            if opensConnections {
                try? await Task.sleep(for: .seconds(0.6))
                sheet = .connections
            }
        }
    }

    // MARK: Back to the desk

    /// The task the person is on, as the desk board shows it.
    private var deskCurrent: AnchorSession? {
        let tasks = model.projection.hostedSessions
        return model.projection.session.flatMap { selected in tasks.first { $0.id == selected.id } } ?? tasks.first
    }

    /// Why the person belongs at the desk right now, if they do.
    private var deskHold: DeskHold? {
        DeskHold(current: deskCurrent, among: model.projection.hostedSessions)
    }

    /// Turning the phone upright off the desk board during work is the moment
    /// the person asked to be interrupted; turning it back puts the card away.
    /// Presence is untouched: the work continues either way (D05, D08).
    private func notePickUp(from previous: DevicePosture, to posture: DevicePosture) {
        guard tour == nil else { return }
        if posture == .landscape {
            pickedUp = false
        } else if previous == .landscape, posture == .portrait, isAtDesk,
                  sheet == nil, fullScreen == nil, deskHold != nil {
            pickedUp = true
        }
    }

    /// Leaving Anchor during work schedules the reminder; coming back withdraws it.
    /// Only a phone held upright counts: the board on its stand locking itself
    /// on battery also sends Anchor to the background, and that is not leaving.
    private func noteScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            guard tour == nil, posture == .portrait, isAtDesk, isMacConnected, let hold = deskHold else { return }
            let subtitle: String? = if case let .waiting(_, title, _, _) = hold { title } else { nil }
            reminder.schedule(hold, subtitle: subtitle)
        case .active:
            reminder.cancel()
            Task { await reminder.refresh() }
        default:
            break
        }
    }

    // MARK: Landscape invitation

    /// Everything the invitation depends on besides posture.
    private var invitationInputs: [Bool] {
        [hasAnchor, isMacConnected, isAtDesk]
    }

    /// The tour's sample tasks are already down; its invitation waits for the person's own drop.
    private var hasAnchor: Bool {
        !model.projection.hostedSessions.isEmpty && (tour.map { $0.stage >= .turn && $0.stage < .leaving } ?? true)
    }

    private var isMacConnected: Bool {
        model.projection.connection == .connected
    }

    /// Away, handing off and the return review all take precedence (D08).
    private var isAtDesk: Bool {
        switch model.projection.session?.presence {
        case .away, .handingOff, .returning: false
        case .atDesk, .unknown, nil: true
        }
    }

    /// `holdingOffer` keeps a new invitation back until `presentDeferredInvitation`.
    private func synchronizeInvitation(holdingOffer: Bool = false) {
        let event = invitation.update(
            hasAnchor: hasAnchor,
            macConnected: isMacConnected,
            atDesk: isAtDesk,
            posture: posture
        )
        switch event {
        case .offered:
            // Never over a sheet or cover: wait until the home is in view.
            if holdingOffer || sheet != nil || fullScreen != nil { invitationDeferred = true } else { harborMode = .inviting }
        case .arrived:
            harborMode = nil
            arrivalPending = true
            // Play once for this turn, not again when a pushed detail returns.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                arrivalPending = false
            }
        case .weighed:
            harborMode = .weighing
            anchorWeighs += 1
        case nil:
            if !invitation.isOffered {
                invitationDeferred = false
                if harborMode == .inviting { harborMode = nil }
            }
        }
        // One motion sensor, read only while the invitation is on screen.
        if harborMode == .inviting { gravity.start() } else { gravity.stop() }
    }

    /// A sheet or cover opened over a running invitation (for example the
    /// grown anchor was tapped to drop another one): pause it, unseen time
    /// must not use it up, and bring it back once the home is in view.
    private func holdInvitationBehindCover() {
        guard harborMode == .inviting else { return }
        harborMode = nil
        invitationDeferred = true
        gravity.stop()
    }

    /// The anchor falls once the sheet has gone; the new task's card waits,
    /// floating, until the anchor catches, then settles in its place.
    private func playDrop(of taskID: UUID, titled title: String) {
        settlingTaskID = taskID
        Task { @MainActor in
            try? await Task.sleep(for: AnchorDrop.lead)
            anchorDrops += 1
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : AnchorDrop.hold))
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : AnchorMotion.continuity) {
                if settlingTaskID == taskID { settlingTaskID = nil }
            }
            settledTaskID = taskID
            anchorSettles += 1
            AccessibilityNotification.Announcement(String(format: SetupCopy.dropped, title)).post()
        }
    }

    private func presentDeferredInvitation(after delay: Double) {
        guard invitationDeferred else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard invitationDeferred, invitation.isOffered, sheet == nil, fullScreen == nil, posture == .portrait else { return }
            invitationDeferred = false
            harborMode = .inviting
            gravity.start()
        }
    }

    private func endHarbor() {
        if harborMode == .inviting { invitation.expire() }
        harborMode = nil
        gravity.stop()
    }

    @ViewBuilder
    private func destination(for route: AnchorRoute) -> some View {
        switch route {
        case let .process(id):
            if let owner = model.projection.hostedSessions.first(where: { $0.processes.contains(where: { $0.id == id }) }),
               let process = owner.processes.first(where: { $0.id == id }) {
                ProcessDetailView(process: process)
                .navigationTransition(.zoom(sourceID: process.id, in: processTransition))
            } else {
                ContentUnavailableView(L10n.emptyTitle, systemImage: "square.dashed")
            }
        case .insights:
            InsightsView(projection: model.projection)
        case .profile:
            ProfileView(
                projection: model.projection,
                onRoute: { path.append($0) },
                onSheet: { sheet = $0 }
            )
        case .history:
            HistoryView(projection: model.projection) { path.append(.historyDetail($0)) }
        case let .historyDetail(id):
            HistoryDetailView(projection: model.projection, sessionID: id)
        case .connections:
            ConnectionDetailView(projection: model.projection, controller: linkController)
        case .sources:
            SourceSettingsView(projection: model.projection)
        case .localData:
            LocalDataSettingsView(model: model)
        }
    }

    @ViewBuilder
    private func sheetDestination(for item: AnchorSheet) -> some View {
        switch item {
        case .connections:
            ConnectionSettingsView(projection: model.projection, controller: linkController)
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(verticalSizeClass == .compact ? 260 : 400)])
                .presentationDragIndicator(.hidden)
                .presentationCompactAdaptation(.none)
        case .hostedTasks:
            HostedTasksView(model: model, onCreate: {
                if atTaskLimit { sheet = nil; showsCapNote = true } else { sheet = .setup }
            }, onEdit: { sheet = .goal }, onNote: { sheet = .note }, onFinish: { sheet = .finish })
        case .account:
            ProfileEditorView(projection: model.projection) { destination(for: $0) }
                .presentationDetents([.large])
        case let .profileDetail(kind):
            ProfileDetailSheet(
                projection: model.projection,
                kind: kind,
                onManage: { sheet = .layout },
                onFinish: { sheet = .finish },
                onToggleStep: { id, done in
                    Task { _ = await model.send(.setPlanStep(id: id, done: done)) }
                },
                onEditSteps: { steps in
                    Task { _ = await model.send(.updatePlanSteps(steps)) }
                }
            )
            .presentationDetents([.large])
        case .setup:
            NavigationStack {
                AnchorSetupView(model: model, draft: setupDraft)
            }
            .presentationDetents([.large])
        case .note:
            AnchorNoteView(model: model)
                .presentationDetents([.large])
        case .goal:
            if let goal = model.projection.session?.goal {
                GoalEditorView(model: model, goal: goal)
            }
        case .layout:
            TaskManagementView(model: model)
        case .finish:
            FinishSessionView(model: model)
        case let .recovery(sessionID):
            if let session = model.projection.session, session.id == sessionID {
                StaleWorkspaceRecoveryView(
                    session: session,
                    lastObservedAt: model.projection.dataObservedAt,
                    onContinue: { continueRecoveredSession(sessionID) },
                    onComplete: { completeRecoveredSession(sessionID) },
                    onNewWork: { beginNewWorkFromRecovery(sessionID) }
                )
                .presentationDetents([.large])
            }
        }
    }

    @ViewBuilder
    private func fullScreenDestination(for item: AnchorFullScreen) -> some View {
        AnchorFullScreenHost(
            item: item,
            model: model,
            tour: tour,
            onProfile: {
                fullScreen = nil
                path.append(.profile)
            },
            onSettings: {
                fullScreen = nil
                sheet = .account
            },
            onLayout: {
                fullScreen = nil
                sheet = .layout
            }
        )
    }

    private func openSidewaysDesk() {
        showsSidewaysDesk = true
        tour?.reachedDesk()
    }

    private func openHostedTask(_ id: UUID) {
        Task {
            if await model.selectHostedTask(id) { sheet = .profileDetail(.session) }
        }
    }

    private func evaluateRecoveryReview(for sessionID: UUID?) {
        guard tour == nil, let sessionID,
              promptedRecoverySessionID != sessionID,
              sheet == nil,
              !suspendedSetup,
              fullScreen == nil else {
            return
        }
        promptedRecoverySessionID = sessionID
        guard model.projection.needsRecoveryReview(
            at: .now,
            after: recoveryReviewInterval
        ) else {
            return
        }
        sheet = .recovery(sessionID)
    }

    private func continueRecoveredSession(_ sessionID: UUID) {
        Task {
            guard await model.send(.forSession(sessionID, .resumeSession)) else { return }
            sheet = nil
        }
    }

    private func completeRecoveredSession(_ sessionID: UUID) {
        Task {
            guard await model.send(.forSession(sessionID, .completeSession)) else { return }
            sheet = nil
        }
    }

    private func beginNewWorkFromRecovery(_ sessionID: UUID) {
        Task {
            guard await model.send(.forSession(sessionID, .archiveSession)) else { return }
            sheet = .setup
        }
    }

    private var atTaskLimit: Bool {
        model.projection.hostedSessions.count >= HomeTaskLimit.count
    }

    private var shouldShowLandscapeDashboard: Bool {
        guard posture == .landscape else { return false }
        switch model.projection.session?.presence {
        case .away, .returning:
            return false
        case .atDesk, .handingOff, .unknown, nil:
            return true
        }
    }

    private func synchronizeCover(with presence: PresenceStatus?) {
        switch presence {
        case .handingOff: fullScreen = .handingOff
        case .away: fullScreen = .away
        case .returning: fullScreen = .returning
        case .atDesk, .unknown, nil: fullScreen = nil
        }
    }
}

private struct AnchorFullScreenHost: View {
    let item: AnchorFullScreen
    let model: AnchorSessionModel
    let tour: AnchorTour?
    let onProfile: () -> Void
    let onSettings: () -> Void
    let onLayout: () -> Void

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        ZStack {
            content
                .id(item)
                .transition(reduceMotion || item == .returning
                    ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
        .animation(reduceMotion ? nil : AnchorMotion.panel, value: item)
        // The tour's phone comes back in range over the away screen.
        .overlay {
            if tour?.stage == .comingBack {
                TourLinkScene(mode: .together)
                    .transition(.opacity)
            }
        }
        .animation(AnchorMotion.panel, value: tour?.stage == .comingBack)
    }

    @ViewBuilder
    private var content: some View {
        switch item {
        case .handingOff:
            HandoffView(model: model)
        case .away:
            AwayView(
                projection: model.projection,
                model: model,
                onProfile: onProfile,
                onSettings: onSettings,
                onLayout: onLayout
            )
        case .returning:
            ReturnView(projection: model.projection, model: model)
                .id(model.projection.session?.returnSummary?.generatedAt)
        }
    }
}
#endif
