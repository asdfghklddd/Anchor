#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorIOSRootView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let currentProcessProvider: (any CurrentProcessProviding)?
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?
    private let recoveryReviewInterval: TimeInterval

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
    @State private var anchorWeighs = 0
    @State private var gravity = DeviceGravityMonitor()
    @State private var posture = DevicePosture.unknown
    @State private var promptedRecoverySessionID: UUID?
    /// The phone came off the desk during work: show the pick-up card (D05).
    @State private var pickedUp = false
    @State private var reminder = DeskReminder()
    @AppStorage(DeskReminder.enabledKey) private var reminderEnabled = true
    @AppStorage(DeskReminder.minutesKey) private var reminderMinutes = DeskReminder.defaultMinutes
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var processTransition

    public init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)? = nil,
        currentProcessProvider: (any CurrentProcessProviding)? = nil,
        auxiliaryToolbarLabel: String? = nil,
        auxiliaryToolbarAction: (() -> Void)? = nil,
        recoveryReviewInterval: TimeInterval = 86_400
    ) {
        self.model = model
        self.linkController = linkController
        self.currentProcessProvider = currentProcessProvider
        self.auxiliaryToolbarLabel = auxiliaryToolbarLabel
        self.auxiliaryToolbarAction = auxiliaryToolbarAction
        self.recoveryReviewInterval = recoveryReviewInterval
    }

    public var body: some View {
        AnchorLaunchGate {
            NavigationStack(path: $path) {
                Group {
                    if shouldShowLandscapeDashboard {
                        LandscapeAmbientDashboard(
                            projection: model.projection,
                            playsArrival: arrivalPending,
                            onTask: openHostedTask,
                            onManage: { sheet = .hostedTasks },
                            onSelect: { id in Task { _ = await model.selectHostedTask(id) } },
                            onStep: { task, step, done in
                                Task { _ = await model.send(.forSession(task, .setPlanStep(id: step, done: done))) }
                            },
                            onReviewed: { task in Task { _ = await model.send(.forSession(task, .markPlanReviewed)) } }
                        )
                    } else {
                        PortraitDashboard(
                            projection: model.projection,
                            auxiliaryToolbarLabel: auxiliaryToolbarLabel,
                            auxiliaryToolbarAction: auxiliaryToolbarAction,
                            transitionNamespace: processTransition,
                            onRoute: { path.append($0) },
                            onSheet: { sheet = $0 },
                            onTask: openHostedTask,
                            invitation: harborMode,
                            onInvitationEnd: endHarbor,
                            anchorDrops: anchorDrops,
                            anchorWeighs: anchorWeighs,
                            gravity: gravity
                        )
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
        }
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
            // Coming back to the desk after being away invites again (D08).
            if previous == .returning, presence == .atDesk { invitation.beginDeskSession() }
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
            if presentedSheet == .setup { suspendedSetup = false }
            guard presentedSheet == nil else {
                holdInvitationBehindCover()
                return
            }
            // The success ending plays first; a waiting invitation follows it.
            let dropped = previousSheet == .setup && setupDraft.wasCreated
            if dropped { anchorDrops += 1 }
            presentDeferredInvitation(after: dropped ? 1.1 : 0.4)
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
            model.start()
            await reminder.refresh()
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
            guard posture == .portrait, isAtDesk, isMacConnected, let hold = deskHold else { return }
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
        [!model.projection.hostedSessions.isEmpty, isMacConnected, isAtDesk]
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

    private func synchronizeInvitation() {
        let event = invitation.update(
            hasAnchor: !model.projection.hostedSessions.isEmpty,
            macConnected: isMacConnected,
            atDesk: isAtDesk,
            posture: posture
        )
        switch event {
        case .offered:
            // Never over a sheet or cover: wait until the home is in view.
            if sheet != nil || fullScreen != nil { invitationDeferred = true } else { harborMode = .inviting }
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
        case .taskManagement:
            TaskManagementView(model: model)
        case .connections:
            ConnectionSettingsView(projection: model.projection, controller: linkController)
        case .sources:
            SourceSettingsView(projection: model.projection)
        case .notificationSettings:
            NotificationSettingsView()
        case .privacy:
            PrivacySettingsView()
        case .accessibility:
            AccessibilitySettingsView()
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
            HostedTasksView(model: model, onCreate: { sheet = .setup }, onEdit: { sheet = .goal }, onNote: { sheet = .note }, onFinish: { sheet = .finish })
        case .account:
            ProfileEditorView()
                .presentationDetents([.large])
        case .icloud:
            ProfileInfoSheet(kind: .icloud, projection: model.projection)
                .presentationDetents([.large])
        case let .profileDetail(kind):
            ProfileDetailSheet(
                projection: model.projection,
                kind: kind,
                onManage: { sheet = .layout },
                onFinish: { sheet = .finish },
                onLeave: {
                    Task {
                        if await model.leaveDesk() { sheet = nil }
                    }
                },
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
                AnchorSetupView(
                    model: model,
                    draft: setupDraft
                )
            }
            .presentationDetents([.large])
        case .note:
            AnchorNoteView(model: model)
                .presentationDetents([.large])
        case .goal:
            if let goal = model.projection.session?.goal {
                GoalEditorView(model: model, goal: goal)
            }
        case .notifications:
            NotificationsView(projection: model.projection) { id in
                sheet = nil
                path.append(.process(id))
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
            onProfile: {
                fullScreen = nil
                path.append(.profile)
            },
            onNotifications: {
                fullScreen = nil
                sheet = .notifications
            },
            onLayout: {
                fullScreen = nil
                sheet = .layout
            }
        )
    }

    private func openHostedTask(_ id: UUID) {
        Task {
            if await model.selectHostedTask(id) { sheet = .profileDetail(.session) }
        }
    }

    private func evaluateRecoveryReview(for sessionID: UUID?) {
        guard let sessionID,
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
    let onProfile: () -> Void
    let onNotifications: () -> Void
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
                onNotifications: onNotifications,
                onLayout: onLayout
            )
        case .returning:
            ReturnView(projection: model.projection, model: model)
                .id(model.projection.session?.returnSummary?.generatedAt)
        }
    }
}
#endif
