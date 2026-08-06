import AnchorCore
import AnchorDesign
import SwiftUI

#if os(iOS)
import AnchorIOSFeatures

public struct AnchorIOSDemoRootView: View {
    private let model: AnchorSessionModel

    public init(model: AnchorSessionModel, controller: any DemoControlling) {
        self.model = model
        _ = controller
    }

    public var body: some View {
        AnchorIOSRootView(model: model)
    }
}

private struct IOSDemoControlsView: View {
    let controller: any DemoControlling
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScenario = DemoScenario.active

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(DemoL10n.explanation)
                }
                Section(DemoL10n.controls) {
                    Picker(DemoL10n.controls, selection: $selectedScenario) {
                        ForEach(DemoScenario.allCases) { scenario in
                            Text(DemoL10n.scenario(scenario)).tag(scenario)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedScenario) { _, scenario in
                        Task { await controller.switchScenario(to: scenario) }
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.large) {
            Text(DemoL10n.controls).font(.title.bold())
            Text(DemoL10n.explanation).foregroundStyle(.secondary)
            Picker(DemoL10n.controls, selection: $selection) {
                ForEach(DemoScenario.allCases) { scenario in
                    Text(DemoL10n.scenario(scenario)).tag(scenario)
                }
            }
            .onChange(of: selection) { _, scenario in
                Task { await controller.switchScenario(to: scenario) }
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
