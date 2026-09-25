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
    private let currentProcessProvider: (any CurrentProcessProviding)?
    private let recoveryReviewInterval: TimeInterval

    init() {
        let environment = ProcessInfo.processInfo.environment
        let isUITesting: Bool
        let uiTestStorageURL: URL?
        let pairingIdentityService: String
        let usesAutomaticICloudPairing: Bool
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
        pairingIdentityService = environment["ANCHOR_PAIRING_IDENTITY_SERVICE"]
            ?? (isUITesting
                ? "com.andywang.anchor.ui-tests.\(uiTestStorageID.uuidString)"
                : "com.andywang.anchor.local-link")
        usesAutomaticICloudPairing = !isUITesting
            && environment["ANCHOR_DISABLE_ICLOUD_PAIRING"] != "1"
        recoveryReviewInterval = isUITesting
            ? environment["ANCHOR_UI_TEST_RECOVERY_INTERVAL"].flatMap(TimeInterval.init) ?? 86_400
            : 86_400
#else
        isUITesting = false
        uiTestStorageURL = nil
        pairingIdentityService = "com.andywang.anchor.local-link"
        usesAutomaticICloudPairing = true
        recoveryReviewInterval = 86_400
#endif
        if let uiTestStorageURL {
            try? FileManager.default.createDirectory(
                at: uiTestStorageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        let identityStore = PairingIdentityStore(service: pairingIdentityService)
        let client = AnchorBonjourClient(
            identityStore: identityStore,
            automaticPairing: usesAutomaticICloudPairing ? .iOSProduction() : .manualOnly
        )
        let scanner = AnchorProximityScanner(
            identityStore: identityStore,
            onUpdate: { proximity in
                client.updateProximity(proximity)
            },
            onPairingCredential: { deviceID, secret in
                client.offerBluetoothPairingSecret(secret, for: deviceID)
            }
        )
        let localRepository = LocalSessionRepository(
            storageURL: uiTestStorageURL,
            sourceID: identityStore.localDeviceID()
        )
        let cloudSyncRunner: DurableSyncRunner?
        let presenceProvider: (any PresenceSignalProviding)?
        let currentProcessProvider: (any CurrentProcessProviding)?
#if DEBUG
        if isUITesting {
            cloudSyncRunner = nil
            presenceProvider = nil
            currentProcessProvider = nil
        } else {
            cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
            presenceProvider = client
            currentProcessProvider = AnchorAdaptiveCurrentProcessProvider(
                network: client,
                bluetooth: scanner
            )
        }
#else
        cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
        presenceProvider = client
        currentProcessProvider = AnchorAdaptiveCurrentProcessProvider(
            network: client,
            bluetooth: scanner
        )
#endif
        let transport = AnchorAdaptiveEventTransport(
            network: client,
            bluetooth: scanner
        )
        let repository = LinkedSessionRepository(base: localRepository, transport: transport)
        let applyEvent: @Sendable (EventEnvelope) async throws -> Void = { [weak repository] event in
            guard let repository else { throw CancellationError() }
            try await repository.applyRemote(event)
        }
        client.onEvent = applyEvent
        scanner.setEventHandler(applyEvent)
        client.onConnectionState = { [weak repository, weak scanner] state in
            guard state == .connected else { return }
            scanner?.refreshDataLink()
            Task { await repository?.reconcilePeerHistory() }
        }
        scanner.setConnectionStateHandler { [weak repository] state in
            client.updateFallbackConnection(state)
            guard state == .connected else { return }
            Task { await repository?.reconcilePeerHistory() }
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
