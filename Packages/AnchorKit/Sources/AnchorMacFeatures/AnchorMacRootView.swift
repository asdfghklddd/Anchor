#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorMacRootView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let sourceSetupModel: MacSourceSetupModel?
    private let showsCompletedSessionInCurrentWork: Bool
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?

    @AppStorage("anchor.mac.selected-section") private var storedSection = MacSection.current.rawValue
    @State private var workPath: [MacWorkRoute] = []
    @State private var isSidebarExpanded = false
    @State private var requestsSidebarToggleFocus = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState

    public init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)? = nil,
        sourceSetupModel: MacSourceSetupModel? = nil,
        showsCompletedSessionInCurrentWork: Bool = true,
        auxiliaryToolbarLabel: String? = nil,
        auxiliaryToolbarAction: (() -> Void)? = nil
    ) {
        self.model = model
        self.linkController = linkController
        self.sourceSetupModel = sourceSetupModel
        self.showsCompletedSessionInCurrentWork = showsCompletedSessionInCurrentWork
        self.auxiliaryToolbarLabel = auxiliaryToolbarLabel
        self.auxiliaryToolbarAction = auxiliaryToolbarAction
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            MacWorkspaceBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Reserve real layout space for notices; scrolling content must never pass beneath them.
                VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                    if !workPath.isEmpty {
                        Button(L10n.currentWork, systemImage: "chevron.left") {
                            workPath.removeAll()
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, AnchorSpacing.xLarge)
                        .padding(.top, AnchorSpacing.small)
                        .accessibilityIdentifier("mac.navigation.current")
                    }
                    MacRootStatusBanners(
                        model: model,
                        linkController: linkController
                    )
                }
                .fixedSize(horizontal: false, vertical: true)

                NavigationStack(path: $workPath) {
                    detail
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationDestination(for: MacWorkRoute.self) { route in
                            workDestination(route)
                        }
                }
                .toolbar(.hidden, for: .windowToolbar)
            }
            .padding(.top, 48)
            .zIndex(0)

            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                MacSidebarRail(
                    isExpanded: isSidebarExpanded,
                    requestsToggleFocus: $requestsSidebarToggleFocus,
                    onToggle: expandSidebar,
                    onCollapse: collapseSidebar
                )
                .onHover { hovering in
                    if hovering { expandSidebar() }
                }

                if isSidebarExpanded {
                    MacSidebar(
                        selection: selection,
                        projection: model.projection,
                        onSelect: selectSection,
                        onCollapse: collapseSidebar
                    )
                    .transition(sidebarTransition)
                }
            }
            .padding(.leading, AnchorSpacing.small)
            .padding(.top, 2)
            .onHover { hovering in
                // The trigger and menu share one hit region, including the gap between them.
                if !hovering { collapseSidebar() }
            }
            .zIndex(3)
        }
        .animation(reduceMotion ? nil : AnchorMotion.panel, value: isSidebarExpanded)
        .onExitCommand(perform: collapseSidebar)
        .onChange(of: controlActiveState) { _, state in
            if state == .inactive {
                collapseSidebar()
            }
        }
        .onAppear(perform: migrateStoredSection)
        .tint(AnchorPalette.interaction)
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
        }
    }

    private var selection: MacSection {
        MacSection(storedValue: storedSection)
    }

    private var sidebarTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .leading).combined(with: .opacity)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .current:
            MacFocusDashboard(
                model: model,
                showsCompletedSessionInCurrentWork: showsCompletedSessionInCurrentWork,
                onOpenProcess: openProcess,
                onOpenTimeline: openTimeline,
                onOpenSettings: { selectSection(.settings) }
            )
        case .history:
            MacHistoryTrackView(
                projection: model.projection,
                onOpenCurrentWork: { selectSection(.current) }
            )
        case .settings:
            MacSettingsView(
                projection: model.projection,
                controller: linkController,
                sourceSetupModel: sourceSetupModel
            )
        }
    }

    @ViewBuilder
    private func workDestination(_ route: MacWorkRoute) -> some View {
        switch route {
        case let .process(processID):
            MacProcessDetailView(
                model: model,
                processID: processID,
                onOpenTimeline: openTimeline
            )
        case .timeline:
            MacTimelineView(
                projection: model.projection,
                onOpenSettings: { selectSection(.settings) }
            )
        }
    }

    private func migrateStoredSection() {
        storedSection = selection.rawValue
    }

    private func selectSection(_ section: MacSection) {
        storedSection = section.rawValue
        workPath.removeAll()
        collapseSidebar()
    }

    private func openProcess(_ processID: UUID) {
        workPath.append(.process(processID))
    }

    private func openTimeline() {
        workPath.append(.timeline)
    }

    private func expandSidebar() {
        isSidebarExpanded = true
    }

    private func collapseSidebar() {
        guard isSidebarExpanded else { return }
        isSidebarExpanded = false
        requestsSidebarToggleFocus = true
    }
}

private struct MacRootStatusBanners: View {
    let model: AnchorSessionModel
    let linkController: (any LocalLinkControlling)?

    var body: some View {
        VStack(spacing: 0) {
            if let errorMessage {
                MacErrorBanner(
                    message: errorMessage,
                    // A transport retry cannot repair a repository or command error.
                    onRetry: nil,
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

    private var errorMessage: String? {
        model.lastError ?? model.projection.errorMessage
    }
}
#endif
