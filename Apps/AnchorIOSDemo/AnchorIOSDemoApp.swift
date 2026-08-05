import AnchorCore
import AnchorDemoSupport
import AnchorIOSFeatures
import SwiftUI

@main
struct AnchorIOSDemoApp: App {
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
            initialScenario: forcedScenario ?? .needsDecision,
            restoresSavedState: forcedScenario == nil
        )
        self.repository = repository
        model = AnchorSessionModel(
            repository: repository,
            presenceProvider: repository
        )
    }

    var body: some Scene {
        WindowGroup {
            AnchorIOSDemoRootView(model: model, controller: repository)
        }
    }
}
