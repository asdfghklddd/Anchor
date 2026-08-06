import AnchorCore
import AnchorMacFeatures
import AnchorTransport
import SwiftUI

@main
struct AnchorMacApp: App {
    private let model: AnchorSessionModel
    private let server: AnchorBonjourServer
    private let proximityAdvertiser: AnchorProximityAdvertiser
    private let sourceCoordinator: ProcessSourceCoordinator
    private let cloudSyncRunner: DurableSyncRunner?

    init() {
        let identityStore = PairingIdentityStore()
        let server = AnchorBonjourServer(identityStore: identityStore)
        let localRepository = LocalSessionRepository(sourceID: identityStore.localDeviceID())
        let cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
        let repository = LinkedSessionRepository(base: localRepository, transport: server)
        let sourceCoordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: [FileProcessSource()]
        )
        let advertiser = AnchorProximityAdvertiser()
        server.onEvent = { envelope in
            let wasAlreadyApplied = await repository.currentProjection().session?.processedEventIDs.contains(envelope.id) == true
            try await repository.applyRemote(envelope)
            guard !wasAlreadyApplied,
                  let operation = try? JSONDecoder.anchor.decode(
                      SessionOperation.self,
                      from: envelope.payload
                  ),
                  let action = operation.sourceAction,
                  case let .resolveDecision(decisionID, _) = action else {
                return
            }
            let projection = await repository.currentProjection()
            guard let decision = projection.session?.decisions.first(where: { $0.id == decisionID }),
                  let sourceID = projection.session?.processes.first(where: { $0.id == decision.processID })?.sourceID else {
                return
            }
            // The local event is already durable. A source action is best
            // effort and is reported through source health without blocking
            // the transport acknowledgement or causing a retry storm.
            try? await sourceCoordinator.perform(action, on: sourceID)
        }
        server.onConnectionState = { state in
            Task {
                try? await repository.send(
                    .updateSignals(connection: state, proximity: .unknown, at: .now)
                )
                if state == .connected {
                    await repository.flushPendingEvents()
                }
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
        self.cloudSyncRunner = cloudSyncRunner
        model = AnchorSessionModel(
            repository: repository,
            sourceHealthProvider: sourceCoordinator,
            sourceActionProvider: sourceCoordinator,
            durableSyncStatusProvider: cloudSyncRunner
        )
        self.sourceCoordinator = sourceCoordinator
        Task { await sourceCoordinator.start() }
        Task { await cloudSyncRunner?.start() }
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
