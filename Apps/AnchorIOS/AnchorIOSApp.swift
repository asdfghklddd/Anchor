import AnchorCore
import AnchorIOSFeatures
import AnchorTransport
import CoreBluetooth
import SwiftUI
import UIKit

@main
struct AnchorIOSApp: App {
    private let model: AnchorSessionModel
    private let client: AnchorBonjourClient
    private let proximityScanner: AnchorProximityScanner
    private let cloudSyncRunner: DurableSyncRunner?
    private let currentProcessProvider: (any CurrentProcessProviding)?
    private let recoveryReviewInterval: TimeInterval
    private let tourPending: Bool
    private let linkLauncher: LinkLauncher

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
        // The default local build should never query a synchronizable
        // Keychain item just to discover a nearby Mac.
        usesAutomaticICloudPairing = !isUITesting
            && environment["ANCHOR_ENABLE_ICLOUD_PAIRING"] == "1"
        recoveryReviewInterval = isUITesting
            ? environment["ANCHOR_UI_TEST_RECOVERY_INTERVAL"].flatMap(TimeInterval.init) ?? 86_400
            : 86_400
#else
        isUITesting = false
        uiTestStorageURL = nil
        pairingIdentityService = "com.andywang.anchor.local-link"
        usesAutomaticICloudPairing = false
        recoveryReviewInterval = 86_400
#endif
        if let uiTestStorageURL {
            try? FileManager.default.createDirectory(
                at: uiTestStorageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }
        let identityStore = isUITesting
            ? PairingIdentityStore.inMemory()
            : PairingIdentityStore(service: pairingIdentityService)
        let peerDeviceInfo = PeerDeviceInfo(
            name: AnchorDeviceName.current(),
            model: UIDevice.current.localizedModel,
            systemName: UIDevice.current.systemName,
            systemVersion: UIDevice.current.systemVersion
        )
        let client = AnchorBonjourClient(
            identityStore: identityStore,
            automaticPairing: usesAutomaticICloudPairing ? .iOSProduction() : .manualOnly,
            localDeviceInfo: peerDeviceInfo
        )
        let scanner = AnchorProximityScanner(
            identityStore: identityStore,
            onUpdate: { proximity in
                client.updateProximity(proximity)
            },
            onPairingCredential: { deviceID, secret in
                client.offerBluetoothPairingSecret(secret, for: deviceID)
            },
            onPeerDeviceInfo: { info in
                client.updateFallbackPeerDeviceInfo(info)
            },
            localDeviceInfo: peerDeviceInfo
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
            // The Mac's day so far is a snapshot for the home, not history.
            if AnchoringLog.receive(event) { return }
            guard let repository else { throw CancellationError() }
            try await repository.applyRemote(event)
        }
        client.onEvent = applyEvent
        // Heartbeat answers keep "last synced" true while nothing else moves.
        client.onPeerContact = { [weak localRepository] in
            Task { await localRepository?.notePeerContact() }
        }
        scanner.setEventHandler(applyEvent)
        client.onConnectionState = { [weak repository, weak scanner] state in
            guard state == .connected else { return }
            scanner?.refreshDataLink()
            Task { await repository?.reconcilePeerHistory() }
        }
        scanner.setConnectionStateHandler { [weak repository] state in
            client.updateFallbackConnection(state)
            // Anchoring time runs while the Bluetooth link to the Mac is up.
            let at = Date.now
            Task { @MainActor in AnchoringLog.shared.linkChanged(connected: state == .connected, at: at) }
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
            durableSyncStatusProvider: cloudSyncRunner,
            usesTaskDashboard: true
        )
        linkLauncher = LinkLauncher {
            guard !isUITesting else { return }
            scanner.start()
            Task { await cloudSyncRunner?.start() }
        }
        // A first run holds Bluetooth back until its tour ends, so the system
        // prompt arrives over the connection card rather than over the tour.
        var tourPending = !isUITesting
            && AnchorTourGate.isPending(bluetoothAsked: CBManager.authorization != .notDetermined)
#if DEBUG
        if environment["ANCHOR_TOUR"] == "1" { tourPending = true }
#endif
        self.tourPending = tourPending
        if !tourPending { linkLauncher.start() }
    }

    var body: some Scene {
        WindowGroup {
            AnchorIOSRootView(
                model: model,
                linkController: client,
                currentProcessProvider: currentProcessProvider,
                recoveryReviewInterval: recoveryReviewInterval,
                tourPending: tourPending,
                startLink: linkLauncher.start
            )
        }
    }
}

/// Bluetooth and sync start once: at launch, or when the first-run tour ends.
@MainActor
private final class LinkLauncher {
    private var started = false
    private let launch: () -> Void

    init(launch: @escaping () -> Void) {
        self.launch = launch
    }

    func start() {
        guard !started else { return }
        started = true
        launch()
    }
}
