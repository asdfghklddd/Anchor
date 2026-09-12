import AnchorCore
import AnchorDesign
import SwiftUI

#if os(iOS)
import AnchorIOSFeatures

public struct AnchorIOSDemoRootView: View {
    private let model: AnchorSessionModel
    private let controller: any DemoControlling
    @State private var showingControls = false

    public init(model: AnchorSessionModel, controller: any DemoControlling) {
        self.model = model
        self.controller = controller
    }

    public var body: some View {
        AnchorIOSRootView(
            model: model,
            currentProcessProvider: controller,
            auxiliaryToolbarLabel: DemoL10n.controls,
            auxiliaryToolbarAction: { showingControls = true },
            onReturnFromAway: {
                Task { await controller.playScenario(to: .returning) }
            }
        )
        .sheet(isPresented: $showingControls) {
            IOSDemoControlsView(controller: controller)
        }
    }
}

private struct IOSDemoControlsView: View {
    let controller: any DemoControlling
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScenario = DemoScenario.active

    private var scenarioSelection: Binding<DemoScenario> {
        Binding(
            get: { selectedScenario },
            set: { scenario in
                selectedScenario = scenario
                Task { await controller.playScenario(to: scenario) }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(DemoL10n.explanation)
                }
                Section(DemoL10n.controls) {
                    Picker(DemoL10n.controls, selection: scenarioSelection) {
                        ForEach(DemoScenario.allCases) { scenario in
                            Text(DemoL10n.scenario(scenario)).tag(scenario)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section {
                    Button(DemoL10n.reset) {
                        selectedScenario = .active
                        Task { await controller.reset() }
                    }
                }
            }
            .navigationTitle(DemoL10n.controls)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
            .task { selectedScenario = await controller.activeScenario() }
        }
    }
}
#endif

#if os(macOS)
import AnchorMacFeatures

public struct AnchorMacDemoRootView: View {
    private let model: AnchorSessionModel
    private let controller: any DemoControlling
    @State private var showingControls = false

    public init(model: AnchorSessionModel, controller: any DemoControlling) {
        self.model = model
        self.controller = controller
    }

    public var body: some View {
        AnchorMacRootView(
            model: model,
            auxiliaryToolbarLabel: DemoL10n.controls,
            auxiliaryToolbarAction: { showingControls = true }
        )
        .sheet(isPresented: $showingControls) {
            MacDemoControlsView(controller: controller)
        }
    }
}

private struct MacDemoControlsView: View {
    let controller: any DemoControlling
    @Environment(\.dismiss) private var dismiss
    @State private var selection = DemoScenario.active

    private var scenarioSelection: Binding<DemoScenario> {
        Binding(
            get: { selection },
            set: { scenario in
                selection = scenario
                Task { await controller.playScenario(to: scenario) }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.large) {
            Text(DemoL10n.controls).font(.title.bold())
            Text(DemoL10n.explanation).foregroundStyle(.secondary)
            Picker(DemoL10n.controls, selection: scenarioSelection) {
                ForEach(DemoScenario.allCases) { scenario in
                    Text(DemoL10n.scenario(scenario)).tag(scenario)
                }
            }
            HStack {
                Button(DemoL10n.reset) {
                    selection = .active
                    Task { await controller.reset() }
                }
                Spacer()
                Button(L10n.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AnchorSpacing.large)
        .frame(width: 460)
        .task { selection = await controller.activeScenario() }
    }
}
#endif
