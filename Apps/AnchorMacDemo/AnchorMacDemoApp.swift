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
        MenuBarExtra {
            MacDemoMenuHost(model: model)
        } label: {
            Label("Anchor Demo", systemImage: "scope")
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "anchor-details") {
            AnchorMacDemoRootView(model: model, controller: repository)
        }
        .defaultSize(width: 1080, height: 720)
    }
}

private struct MacDemoMenuHost: View {
    let model: AnchorSessionModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        AnchorMacMenuView(
            model: model,
            onOpenDetails: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "anchor-details")
            },
            onQuit: { NSApp.terminate(nil) }
        )
    }
}
