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
    private let currentProcessProvider: AnchorBonjourClient?
    private let recoveryReviewInterval: TimeInterval

    init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITesting: Bool
        let uiTestStorageURL: URL?
        let pairingIdentityService: String
        let recoveryReviewInterval: TimeInterval
#if DEBUG
        isUITesting = environment["ANCHOR_UI_TESTING"] == "1"
        let uiTestStorageID = environment["ANCHOR_UI_TEST_STORAGE_ID"]
            .flatMap(UUID.init(uuidString:)) ?? UUID()
        uiTestStorageURL = isUITesting
            ? FileManager.default.temporaryDirectory
                .appending(path: "AnchorUITests", directoryHint: .isDirectory)
                .appending(path: uiTestStorageID.uuidString, directoryHint: .isDirectory)
                .appending(path: "session-repository.json")
            : nil
        pairingIdentityService = isUITesting
            ? "com.andywang.anchor.ui-tests.\(uiTestStorageID.uuidString)"
            : "com.andywang.anchor.local-link"
        recoveryReviewInterval = isUITesting
            ? environment["ANCHOR_UI_TEST_RECOVERY_INTERVAL"].flatMap(TimeInterval.init) ?? 86_400
            : 86_400
#else
        isUITesting = false
        uiTestStorageURL = nil
        pairingIdentityService = "com.andywang.anchor.local-link"
        recoveryReviewInterval = 86_400
#endif
        if let uiTestStorageURL {
            try? FileManager.default.createDirectory(
                at: uiTestStorageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        let identityStore = PairingIdentityStore(service: pairingIdentityService)
        let client = AnchorBonjourClient(identityStore: identityStore)
        let scanner = AnchorProximityScanner { proximity in
            client.updateProximity(proximity)
        }
        let localRepository = LocalSessionRepository(
            storageURL: uiTestStorageURL,
            sourceID: identityStore.localDeviceID()
        )
        let cloudSyncRunner: DurableSyncRunner?
        let presenceProvider: (any PresenceSignalProviding)?
        let currentProcessProvider: AnchorBonjourClient?
#if DEBUG
        if isUITesting {
            cloudSyncRunner = nil
            presenceProvider = nil
            currentProcessProvider = nil
        } else {
            cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
            presenceProvider = client
            currentProcessProvider = client
        }
#else
        cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
        presenceProvider = client
        currentProcessProvider = client
#endif
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
        self.currentProcessProvider = currentProcessProvider
        self.recoveryReviewInterval = recoveryReviewInterval
        model = AnchorSessionModel(
            repository: repository,
            presenceProvider: presenceProvider,
            durableSyncStatusProvider: cloudSyncRunner
        )
#if DEBUG
        if !isUITesting {
            scanner.start()
            Task { await cloudSyncRunner?.start() }
        }
#else
        scanner.start()
        Task { await cloudSyncRunner?.start() }
#endif
    }

    var body: some Scene {
        WindowGroup {
            AnchorIOSRootView(
                model: model,
                linkController: client,
                currentProcessProvider: currentProcessProvider,
                recoveryReviewInterval: recoveryReviewInterval
            )
        }
    }
}
