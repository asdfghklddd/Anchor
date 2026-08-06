import AnchorCore
import AnchorDemoSupport
import AnchorMacFeatures
import SwiftUI

@main
struct AnchorMacDemoApp: App {
    private let repository: DemoSessionRepository
    private let model: AnchorSessionModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let argumentIndex = arguments.firstIndex(of: "--demo-scenario")
        let argumentScenario = argumentIndex.flatMap { index in
            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
        }
        let scenarioName = argumentScenario ?? ProcessInfo.processInfo.environment["ANCHOR_DEMO_SCENARIO"]
        let forcedScenario = scenarioName.flatMap(DemoScenario.init(rawValue:))
        let repository = DemoSessionRepository(
            initialScenario: forcedScenario ?? .active,
            restoresSavedState: forcedScenario == nil
        )
        self.repository = repository
        model = AnchorSessionModel(
            repository: repository,
            presenceProvider: repository
        )
    }

    var body: some Scene {
        Window("Anchor Demo", id: "anchor-details") {
            AnchorMacDemoRootView(model: model, controller: repository)
        }
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra {
            MacDemoMenuHost(model: model)
        } label: {
            Label("Anchor Demo", systemImage: "scope")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MacDemoMenuHost: View {
    let model: AnchorSessionModel
    @Environment(\.dismiss) private var dismissMenu
    @Environment(\.openWindow) private var openWindow
    @AppStorage("anchor.mac.selected-section") private var selectedSection = "current"

    var body: some View {
        AnchorMacMenuView(
            model: model,
            onOpenDetails: { open(.current) },
            onOpenTimeline: { open(.timeline) },
            onOpenSources: { open(.sources) },
            onOpenSettings: { open(.settings) },
            onContinueWorking: continueWorking,
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func continueWorking() {
        open(.current)
        Task { _ = await model.continueWorking() }
    }

    private func open(_ destination: MenuDestination) {
        selectedSection = destination.rawValue
        dismissMenu()
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "anchor-details")
    }

    private enum MenuDestination: String {
        case current
        case timeline
        case sources
        case settings
    }
}
