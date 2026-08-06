#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorIOSRootView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?

    @State private var path: [AnchorRoute] = []
    @State private var sheet: AnchorSheet?
    @State private var fullScreen: AnchorFullScreen?
    @State private var posture = DevicePosture.unknown

    public init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)? = nil,
        auxiliaryToolbarLabel: String? = nil,
        auxiliaryToolbarAction: (() -> Void)? = nil
    ) {
        self.model = model
        self.linkController = linkController
        self.auxiliaryToolbarLabel = auxiliaryToolbarLabel
        self.auxiliaryToolbarAction = auxiliaryToolbarAction
    }

    public var body: some View {
        AnchorLaunchGate {
            NavigationStack(path: $path) {
                Group {
                    if shouldShowLandscapeDashboard {
                        LandscapeAmbientDashboard(
                            projection: model.projection,
                            onGoal: {
                                sheet = model.projection.session == nil ? .setup : .goal
                            },
                            onAnchor: {
                                sheet = model.projection.session == nil ? .setup : .note
                            },
                            onResolve: resolve,
                            onProcessAction: { process in
                                Task {
                                    if process.status == .queued {
                                        var updated = process
                                        updated.status = .running
                                        updated.updatedAt = .now
                                        _ = await model.send(.updateProcess(updated))
                                    }

                                    _ = await model.send(
                                        .recordEvent(
                                            ProcessEvent(
                                                processID: process.id,
                                                kind: .note,
                                                title: L10n.openCurrentProcess
                                            )
                                        )
                                    )
                                }
                            }
                        )
                    } else {
                        PortraitDashboard(
                            projection: model.projection,
                            auxiliaryToolbarLabel: auxiliaryToolbarLabel,
                            auxiliaryToolbarAction: auxiliaryToolbarAction,
                            onRoute: { path.append($0) },
                            onSheet: { sheet = $0 }
                        )
                    }
                }
                .navigationDestination(for: AnchorRoute.self) { route in
                    destination(for: route)
                }
            }
        }
        .tint(AnchorPalette.link)
        .background(AnchorPalette.paper.ignoresSafeArea())
        .sheet(item: $sheet) { item in
            sheetDestination(for: item)
        }
        .fullScreenCover(item: $fullScreen) { item in
            fullScreenDestination(for: item)
        }
        .onGeometryChange(for: DevicePosture.self) { geometry in
            guard geometry.size.width > 0, geometry.size.height > 0 else { return .unknown }
            return geometry.size.width > geometry.size.height ? .landscape : .portrait
        } action: { newPosture in
            guard newPosture != posture else { return }
            posture = newPosture
            // The empty workspace has no session to reduce a presence update into.
            // Remember the posture now and apply it once an anchor exists.
            guard model.projection.session != nil else { return }
            Task { await model.updatePosture(newPosture) }
        }
        .onChange(of: model.projection.session?.presence, initial: true) { _, presence in
            synchronizeCover(with: presence)
        }
        .onChange(of: model.projection.session?.id) { _, sessionID in
            guard sessionID != nil else { return }
            Task { await model.updatePosture(posture) }
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

    @ViewBuilder
    private func destination(for route: AnchorRoute) -> some View {
        switch route {
        case let .process(id):
            if let process = model.projection.session?.processes.first(where: { $0.id == id }) {
                ProcessDetailView(
                    process: process,
                    decision: model.projection.session?.decisions.first {
                        $0.processID == id && $0.status == .open
                    },
                    onDecision: { sheet = .decision($0) }
                )
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
            HistoryDetailView(projection: model.projection, snapshotID: id)
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
        case .account:
            ProfileInfoSheet(kind: .account)
                .presentationDetents([.large])
        case .icloud:
            ProfileInfoSheet(kind: .icloud)
                .presentationDetents([.large])
        case let .profileDetail(kind):
            ProfileDetailSheet(
                projection: model.projection,
                kind: kind,
                onManage: { sheet = .layout },
                onFinish: { sheet = .finish }
            )
            .presentationDetents([.large])
        case .setup:
            NavigationStack {
                AnchorSetupView(model: model)
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
            if let decision = model.projection.session?.decisions.first(where: { $0.id == id }) {
                DecisionView(model: model, decision: decision)
            }
        case .layout:
            TaskManagementView(model: model)
        case .finish:
            FinishSessionView(model: model)
        }
    }

    @ViewBuilder
    private func fullScreenDestination(for item: AnchorFullScreen) -> some View {
        switch item {
        case .handingOff:
            HandoffView(model: model)
        case .away:
            AwayView(
                projection: model.projection,
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
        case .returning:
            ReturnView(projection: model.projection, model: model)
        }
    }

    private func resolve(decision: Decision, option: DecisionOption) {
        Task { await model.resolve(decision: decision, option: option) }
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
#endif
