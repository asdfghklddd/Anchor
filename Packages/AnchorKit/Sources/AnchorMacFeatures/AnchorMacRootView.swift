#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorMacRootView: View {
    private let model: AnchorSessionModel
    private let linkController: (any LocalLinkControlling)?
    private let auxiliaryToolbarLabel: String?
    private let auxiliaryToolbarAction: (() -> Void)?
    @State private var selection = MacSection.current

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
            List(MacSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
                    .frame(minHeight: 28)
            }
            .navigationTitle(L10n.appName)
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AnchorPalette.paper)
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar {
            ToolbarItemGroup {
                connectionStatus
                if let auxiliaryToolbarLabel, let auxiliaryToolbarAction {
                    Button(action: auxiliaryToolbarAction) {
                        Label(auxiliaryToolbarLabel, systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .task { model.start() }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .current:
            MacCurrentWorkView(model: model)
        case .timeline:
            MacTimelineView(projection: model.projection)
        case .history:
            MacHistoryView(projection: model.projection)
        case .sources:
            MacSourcesView(projection: model.projection)
        case .settings:
            MacSettingsView(projection: model.projection, controller: linkController)
        }
    }

    private var connectionStatus: some View {
        Label(
            model.projection.connection == .connected ? L10n.connected : L10n.disconnected,
            systemImage: model.projection.connection == .connected ? "checkmark.circle.fill" : "wifi.slash"
        )
        .foregroundStyle(model.projection.connection == .connected ? AnchorPalette.ink : AnchorPalette.coral)
        .accessibilityElement(children: .combine)
    }
}

private enum MacSection: String, CaseIterable, Identifiable {
    case current
    case timeline
    case history
    case sources
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .current: L10n.currentWork
        case .timeline: L10n.timeline
        case .history: L10n.history
        case .sources: L10n.sources
        case .settings: L10n.settings
        }
    }
    var symbol: String {
        switch self {
        case .current: "scope"
        case .timeline: "waveform.path.ecg"
        case .history: "clock.arrow.circlepath"
        case .sources: "point.3.filled.connected.trianglepath.dotted"
        case .settings: "gearshape"
        }
    }
}
#endif
