#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorMacRootView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?
    @AppStorage("anchor.mac.selected-section") private var selection = MacSection.current
    @AppStorage("anchor.mac.notifications.decisions") private var decisionAlerts = false
    @State private var notificationService = MacDecisionNotificationService()

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
        NavigationSplitView {
            MacSidebar(selection: $selection, projection: model.projection)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AnchorPalette.paper)
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        if let errorMessage {
                            MacErrorBanner(
                                message: errorMessage,
                                onRetry: linkController.map { controller in
                                    { Task { await controller.retryConnection() } }
                                },
                                onDismiss: { Task { await model.clearError() } }
                            )
                        }
                        if model.projection.isStale {
                            MacFreshnessBanner(
                                observedAt: model.projection.dataObservedAt,
                                onRetry: linkController.map { controller in
                                    { Task { await controller.retryConnection() } }
                                }
                            )
                        }
                    }
                }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 620)
        .toolbar {
            if let auxiliaryToolbarLabel, let auxiliaryToolbarAction {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: auxiliaryToolbarAction) {
                        Label(auxiliaryToolbarLabel, systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .task {
            model.start()
            notificationService.observe(model.projection, enabled: decisionAlerts)
        }
        .onChange(of: model.projection) { _, projection in
            notificationService.observe(projection, enabled: decisionAlerts)
        }
    }

    private var errorMessage: String? {
        model.lastError ?? model.projection.errorMessage
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .current:
            MacFocusDashboard(
                model: model,
                onOpenTimeline: { selection = .timeline },
                onOpenSettings: { selection = .settings }
            )
        case .timeline:
            MacTimelineView(
                projection: model.projection,
                onOpenSettings: { selection = .settings }
            )
        case .history:
            MacHistoryView(
                projection: model.projection,
                onOpenCurrentWork: { selection = .current }
            )
        case .sources:
            MacSourcesView(
                projection: model.projection,
                onOpenSettings: { selection = .settings }
            )
        case .settings:
            MacSettingsView(projection: model.projection, controller: linkController)
        }
    }
}
#endif
