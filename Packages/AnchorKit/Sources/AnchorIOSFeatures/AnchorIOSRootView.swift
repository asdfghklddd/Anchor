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
    @State private var showsLandscapeHint = false
    @State private var posture = DevicePosture.unknown
    @State private var promptedRecoverySessionID: UUID?
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
                            onTask: openHostedTask,
                            onManage: { sheet = .hostedTasks }
                        )
                    } else {
                        PortraitDashboard(
                            projection: model.projection,
                            auxiliaryToolbarLabel: auxiliaryToolbarLabel,
                            auxiliaryToolbarAction: auxiliaryToolbarAction,
                            transitionNamespace: processTransition,
                            onRoute: { path.append($0) },
                            onSheet: { sheet = $0 },
                            onTask: openHostedTask
                        )
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if showsLandscapeHint, posture == .portrait,
                       model.projection.session?.presence == .atDesk {
                        landscapeHint
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
            posture = newPosture
            if newPosture == .landscape { showsLandscapeHint = false }
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
            showsLandscapeHint = previous == .returning && presence == .atDesk && posture != .landscape
            synchronizeCover(with: presence)
        }
        .onChange(of: model.projection.session?.returnSummary?.generatedAt) { _, generatedAt in
            guard generatedAt != nil, model.projection.session?.presence == .returning else { return }
            sheet = nil
            suspendedSetup = false
            fullScreen = .returning
        }
        .onChange(of: model.projection.session?.id) { _, sessionID in
            showsLandscapeHint = false
            if sessionID != nil {
                Task { await model.updatePosture(posture) }
            }
            evaluateRecoveryReview(for: sessionID)
        }
        .onChange(of: sheet) { previousSheet, presentedSheet in
            if presentedSheet == .setup { suspendedSetup = false }
            guard presentedSheet == nil else { return }
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
            guard presentedCover == nil else { return }
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
        .task { model.start() }
    }

    private var landscapeHint: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen3.landscape")
                .font(.title3)
            Text(L10n.returnLandscapeHint)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("return.landscape.hint")
            Button { showsLandscapeHint = false } label: {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(L10n.close)
            .accessibilityIdentifier("return.landscape.dismiss")
        }
        .foregroundStyle(AnchorIOSStyle.action)
        .padding(.leading, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func destination(for route: AnchorRoute) -> some View {
        switch route {
        case let .process(id):
            if let owner = model.projection.hostedSessions.first(where: { $0.processes.contains(where: { $0.id == id }) }),
               let process = owner.processes.first(where: { $0.id == id }) {
                ProcessDetailView(
                    process: process,
                    decision: owner.decisions.first {
                        $0.processID == id && $0.status == .open
                    },
                    onDecision: { sheet = .decision($0) }
                )
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
                onDecision: { sheet = .decision($0) }
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
        case let .decision(id):
            if let decision = model.projection.hostedSessions.flatMap(\.decisions).first(where: { $0.id == id }) {
                DecisionView(model: model, decision: decision)
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

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    var body: some View {
        ZStack {
            content
                .id(item)
                .transition(reduceMotion || systemReduceMotion || item == .returning
                    ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
        .animation(reduceMotion || systemReduceMotion ? nil : AnchorMotion.panel, value: item)
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
