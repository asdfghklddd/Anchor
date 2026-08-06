import AnchorCore
import AnchorMacFeatures
import AnchorTransport
import SwiftUI

@main
struct AnchorMacApp: App {
    private let model: AnchorSessionModel
    private let server: AnchorBonjourServer
    private let proximityAdvertiser: AnchorProximityAdvertiser

    init() {
        let repository = LocalSessionRepository()
        let server = AnchorBonjourServer()
        let advertiser = AnchorProximityAdvertiser()
        server.onEvent = { envelope in
            guard let session = LinkedSessionDecoder.session(from: envelope) else {
                throw AnchorLinkError.malformedFrame
            }
            try await repository.send(.mergeRemoteSession(envelope, session: session))
        }
        server.onConnectionState = { state in
            Task {
                try? await repository.send(
                    .updateSignals(connection: state, proximity: .unknown, at: .now)
                )
            }
        }
        do {
            try server.start()
        } catch {
            Task {
                try? await repository.send(
                    .updateSignals(connection: .failed, proximity: .unknown, at: .now)
                )
            }
        }
        advertiser.start()
        self.server = server
        proximityAdvertiser = advertiser
        model = AnchorSessionModel(repository: repository)
    }

    var body: some Scene {
        Window("Anchor", id: "anchor-details") {
            AnchorMacRootView(model: model, linkController: server)
        }
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra {
            MacMenuHost(model: model)
        } label: {
            Label("Anchor", systemImage: "scope")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MacMenuHost: View {
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
