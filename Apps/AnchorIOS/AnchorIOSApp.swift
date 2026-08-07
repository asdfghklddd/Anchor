import AnchorCore
import AnchorIOSFeatures
import AnchorTransport
import SwiftUI

@main
struct AnchorIOSApp: App {
    private let model: AnchorSessionModel
    private let client: AnchorBonjourClient
    private let proximityScanner: AnchorProximityScanner
    private let cloudSyncRunner: DurableSyncRunner?

    init() {
        let identityStore = PairingIdentityStore()
        let client = AnchorBonjourClient(identityStore: identityStore)
        let scanner = AnchorProximityScanner { proximity in
            client.updateProximity(proximity)
        }
        let localRepository = LocalSessionRepository(sourceID: identityStore.localDeviceID())
        let cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
        let repository = LinkedSessionRepository(base: localRepository, transport: client)
        client.onEvent = { [weak repository] event in
            guard let repository else { throw CancellationError() }
            try await repository.applyRemote(event)
        }
        client.onConnectionState = { [weak repository] state in
            guard state == .connected else { return }
            Task { await repository?.flushPendingEvents() }
        }
        self.client = client
        proximityScanner = scanner
        self.cloudSyncRunner = cloudSyncRunner
        model = AnchorSessionModel(
            repository: repository,
            presenceProvider: client,
            durableSyncStatusProvider: cloudSyncRunner
        )
        scanner.start()
        Task { await cloudSyncRunner?.start() }
    }

    var body: some Scene {
        WindowGroup {
            AnchorIOSRootView(
                model: model,
                linkController: client,
                currentProcessProvider: client
            )
        }
    }
}
