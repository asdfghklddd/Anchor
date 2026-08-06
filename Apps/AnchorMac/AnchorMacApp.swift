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
        let repository = InMemorySessionRepository()
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
        MenuBarExtra {
            MacMenuHost(model: model)
        } label: {
            Label("Anchor", systemImage: "scope")
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: "anchor-details") {
            AnchorMacRootView(model: model, linkController: server)
        }
        .defaultSize(width: 1080, height: 720)
    }
}

private struct MacMenuHost: View {
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
