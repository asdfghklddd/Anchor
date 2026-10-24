import AnchorCore
import AnchorDesign
import AnchorMacFeatures
import AnchorTransport
import AppKit
import CoreBluetooth
import SwiftUI

@main
struct AnchorMacApp: App {
    @NSApplicationDelegateAdaptor(AnchorMacApplicationDelegate.self)
    private var applicationDelegate

    private let model: AnchorSessionModel
    private let server: AnchorBonjourServer
    private let proximityAdvertiser: AnchorProximityAdvertiser
    private let sourceCoordinator: ProcessSourceCoordinator
    private let taskLifecycleBridge: TaskSessionLifecycleBridge
    private let cloudSyncRunner: DurableSyncRunner?
    private let sourceSetupModel: MacSourceSetupModel

    init() {
        let environment = ProcessInfo.processInfo.environment
        let validationRootURL: URL?
        let validationCodexURL: URL?
        let validationShouldSeedSession: Bool
        let validationDefaults: UserDefaults?
        let isUITesting: Bool
        let pairingIdentityService: String
        let usesAutomaticICloudPairing: Bool
#if DEBUG
        isUITesting = environment["ANCHOR_UI_TESTING"] == "1"
        // Apply appearance only to the isolated test app, without changing macOS settings.
        if isUITesting {
            switch environment["ANCHOR_UI_TEST_APPEARANCE"] {
            case "Dark": NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
            case "Light": NSApplication.shared.appearance = NSAppearance(named: .aqua)
            default: break
            }
        }
        let uiTestStorageID = environment["ANCHOR_UI_TEST_STORAGE_ID"]
            .flatMap(UUID.init(uuidString:)) ?? UUID()
        let uiTestRootURL = isUITesting
            ? FileManager.default.temporaryDirectory
                .appending(path: "AnchorUITests", directoryHint: .isDirectory)
                .appending(path: uiTestStorageID.uuidString, directoryHint: .isDirectory)
            : nil
        validationRootURL = uiTestRootURL ?? environment["ANCHOR_LOCAL_VALIDATION_ROOT"].map {
            URL(filePath: $0, directoryHint: .isDirectory)
        }
        validationCodexURL = environment["ANCHOR_LOCAL_VALIDATION_CODEX_FILE"].map {
            URL(filePath: $0)
        }
        validationShouldSeedSession = environment["ANCHOR_LOCAL_VALIDATION_SEED_SESSION"] == "1"
        validationDefaults = environment["ANCHOR_LOCAL_VALIDATION_DEFAULTS_SUITE"]
            .flatMap { UserDefaults(suiteName: $0) }
            ?? (isUITesting
                ? UserDefaults(suiteName: "com.andywang.anchor.ui-tests.\(uiTestStorageID.uuidString)")
                : nil)
            ?? validationRootURL.flatMap {
                UserDefaults(suiteName: "com.andywang.anchor.validation.\($0.lastPathComponent)")
            }
        pairingIdentityService = environment["ANCHOR_PAIRING_IDENTITY_SERVICE"]
            ?? (isUITesting
                ? "com.andywang.anchor.ui-tests.\(uiTestStorageID.uuidString)"
                : validationRootURL.map { "com.andywang.anchor.validation.\($0.lastPathComponent)" }
                    ?? "com.andywang.anchor.local-link")
        // Keep nearby pairing independent of iCloud Keychain on local builds.
        usesAutomaticICloudPairing = validationRootURL == nil && !isUITesting
            && environment["ANCHOR_ENABLE_ICLOUD_PAIRING"] == "1"
#else
        isUITesting = false
        validationRootURL = nil
        validationCodexURL = nil
        validationShouldSeedSession = false
        validationDefaults = nil
        pairingIdentityService = "com.andywang.anchor.local-link"
        usesAutomaticICloudPairing = false
#endif
#if DEBUG
        if let validationRootURL {
            try? FileManager.default.createDirectory(
                at: validationRootURL,
                withIntermediateDirectories: true
            )
            try? Data("anchor-mac-local-validation-v1".utf8).write(
                to: validationRootURL.appending(path: "launch-marker.txt"),
                options: .atomic
            )
        }
#endif
        // A reset asked for by the previous copy runs before any store loads.
        let resetDefaults = validationDefaults ?? .standard
        let startsOver = MacLocalReset.takePending(defaults: resetDefaults)
        let taskRunsURL = validationRootURL?.appending(path: "task-runs.json")
            ?? TaskRunStore.defaultStorageURL()
        let checkpointsURL = validationRootURL?.appending(path: "codex-checkpoints.json")
            ?? CodexLifecycleCheckpointStore().storageURL
        if startsOver {
            MacLocalReset.waitForPreviousInstance()
            MacLocalReset.wipe(files: [taskRunsURL, checkpointsURL], defaults: resetDefaults)
        }
        let pairingKeychain: PairingIdentityStore.Keychain
#if DEBUG && !ANCHOR_SIGNED_DEVELOPMENT
        // The ad-hoc development target has no Keychain access entitlements.
        // Formal releases use the Data Protection keychain and stable signing.
        pairingKeychain = .legacy
#else
        pairingKeychain = .dataProtection
#endif
        let identityStore = validationRootURL == nil
            ? PairingIdentityStore(service: pairingIdentityService, keychain: pairingKeychain)
            : PairingIdentityStore.inMemory()
        let deviceID = validationRootURL == nil
            ? identityStore.localDeviceID()
            : UUID(uuidString: "00000000-0000-4000-8000-0000000004F0")!
        let bluetoothPairingToken = AnchorBluetoothPairingToken()
        let advertiser = AnchorProximityAdvertiser(
            deviceID: deviceID,
            pairingToken: bluetoothPairingToken,
            identityStore: identityStore
        )
        let server = AnchorBonjourServer(
            identityStore: identityStore,
            deviceID: deviceID,
            automaticPairing: usesAutomaticICloudPairing ? .macProduction() : .manualOnly,
            bluetoothPairingToken: bluetoothPairingToken,
            // Local validation must not appear as another production Mac to
            // the phone's Bonjour browser.
            serviceType: validationRootURL == nil
                ? AnchorBonjourServer.serviceType : "_anchorval._tcp"
        )
        let localRepository = LocalSessionRepository(
            storageURL: validationRootURL?.appending(path: "session-repository.json"),
            sourceID: deviceID
        )
        let taskRunStore = TaskRunStore(url: taskRunsURL)
        let codexCheckpointStore = CodexLifecycleCheckpointStore(storageURL: checkpointsURL)
        let cloudSyncRunner: DurableSyncRunner?
#if DEBUG
        cloudSyncRunner = validationRootURL != nil
            ? nil
            : AnchorCloudSyncFactory.makeRunner(local: localRepository)
#else
        cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
#endif
        let transport = AnchorAdaptiveEventTransport(
            network: server,
            bluetooth: advertiser
        )
        let repository = LinkedSessionRepository(base: localRepository, transport: transport)
        let taskLifecycleBridge = TaskSessionLifecycleBridge(
            repository: repository,
            taskRunStore: taskRunStore
        )
        let currentSessionContext: @Sendable () async -> ProcessSourceSessionContext? = {
            guard let session = await repository.currentProjection().session else {
                return nil
            }
            return ProcessSourceSessionContext(
                sessionID: session.id,
                startedAt: session.startedAt
            )
        }
        let currentSessionID: @Sendable () async -> UUID? = {
            await currentSessionContext()?.sessionID
        }
        // Observe structured task signals only; ordinary app/browser activity
        // does not describe the progress of an AI or terminal task.
        let sources: [any ProcessSource] = validationRootURL == nil ? [
            FileProcessSource(sessionContextProvider: currentSessionContext,
                commandSessionContextProvider: { signal in
                    signal.sessionContext(in: await repository.currentProjection())
                }),
        ] : []
        // Register Codex after manual selection or a high-confidence automatic match.
        let sourceCoordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: sources,
            taskRunStore: taskRunStore
        )
        let currentProcessSnapshot: @Sendable () async throws -> CurrentProcessSnapshot = {
            let projection = await repository.currentProjection()
            return CurrentProcessSnapshot(
                processNames: projection.hostedSessions.flatMap { session in
                    session.processes.filter(TaskDashboardPolicy.includes).map(\.sourceName)
                }
            )
        }
        server.onCurrentProcessSnapshot = currentProcessSnapshot
        advertiser.onCurrentProcessSnapshot = currentProcessSnapshot
        let phoneAnchorState = AnchorPhoneAnchorState()
        let applyInboundEvent: @Sendable (EventEnvelope) async throws -> Void = { envelope in
            try await repository.applyRemote(envelope)
            let appliedProjection = await repository.currentProjection()
            await phoneAnchorState.receive(envelope, projection: appliedProjection, localSourceID: deviceID)
        }
        server.onEvent = applyInboundEvent
        advertiser.onEvent = applyInboundEvent
        advertiser.onConnectionState = { state in
            server.updateFallbackConnection(state)
        }
        advertiser.onPeerDeviceInfo = { peerID, info in
            server.updateFallbackPeerDeviceInfo(info, for: peerID)
        }
        let bluetoothRadio = MacBluetoothRadioState()
        advertiser.onRadioState = { state in
            let radio: MacBluetoothRadio = switch state {
            case .poweredOn: .on
            case .poweredOff: .off
            case .unauthorized: .notAllowed
            default: .unknown
            }
            Task { @MainActor in bluetoothRadio.radio = radio }
        }
        server.onConnectionState = { state in
            Task {
                try? await repository.send(
                    .updateSignals(connection: state, proximity: .unknown, at: .now)
                )
                if state == .connected {
                    await repository.reconcilePeerHistory()
                }
            }
        }
        if !isUITesting {
            do {
                try server.start()
            } catch {
                Task {
                    try? await repository.send(
                        .updateSignals(connection: .failed, proximity: .unknown, at: .now)
                    )
                }
            }
            if validationRootURL == nil { advertiser.start() }
        }
        self.server = server
        proximityAdvertiser = advertiser
        self.cloudSyncRunner = cloudSyncRunner
        // Short conversation names and leave recaps. Written locally until a model is set up.
        let summaryBook = SummaryBook(local: LocalSummarizer())
        let codexBinder = CodexSessionBinder(repository: repository, coordinator: sourceCoordinator,
            taskRunStore: taskRunStore, checkpointStore: codexCheckpointStore, names: summaryBook)
        let setupModel = MacSourceSetupModel(
            defaults: validationDefaults ?? .standard,
            currentAnchorSessionID: currentSessionID,
            taskStateProvider: {
                await taskRunStore.currentTaskRecord()?.state
            },
            autoAssociationSessions: { await repository.currentProjection().hostedSessions },
            onCodexSessionAssociated: { url, sessionID, automaticallyMatched, stepID in
                try await codexBinder.bind(fileURL: url, sessionID: sessionID,
                                           automaticallyMatched: automaticallyMatched, stepID: stepID)
            },
            onCodexSessionUnbound: { url, sessionID in
                try await codexBinder.unbind(fileURL: url, sessionID: sessionID)
            },
            summaryBook: summaryBook
        )
        sourceSetupModel = setupModel
        model = AnchorSessionModel(
            repository: repository,
            sourceHealthProvider: sourceCoordinator,
            durableSyncStatusProvider: cloudSyncRunner,
            usesTaskDashboard: true
        )
        self.sourceCoordinator = sourceCoordinator
        self.taskLifecycleBridge = taskLifecycleBridge
        applicationDelegate.configure(
            model: model,
            linkController: server,
            sourceSetupModel: sourceSetupModel,
            phoneAnchorState: phoneAnchorState,
            bluetoothRadio: bluetoothRadio,
            defaults: validationDefaults
        )
        let startup: @MainActor @Sendable () async -> Void = {
#if DEBUG
            if let validationRootURL {
                try? Data("startup-task-running".utf8).write(
                    to: validationRootURL.appending(path: "startup-marker.txt"),
                    options: .atomic
                )
            }
#endif
            if startsOver {
                // Before any folder is read: clear conversations here and on the phone.
                try? await repository.clearConversations()
            }
            await taskLifecycleBridge.start()
#if DEBUG
            if let validationRootURL {
                if (validationShouldSeedSession || validationCodexURL != nil),
                   await repository.currentProjection().session == nil {
                    try? await repository.send(
                        .createSession(
                            goal: AnchorGoal(
                                title: "Mac local validation",
                                completionCriteria: "Codex lifecycle is captured without an iPhone."
                            ),
                            processes: []
                        )
                    )
                }
                if !isUITesting {
                    await sourceCoordinator.start()
                    if let validationCodexURL {
                        try? await setupModel.connectCodexSession(validationCodexURL)
                    } else {
                        await setupModel.restoreCodexSession()
                    }
                }
            } else {
                await sourceCoordinator.start()
                await setupModel.restoreCodexSession()
            }
#else
            await sourceCoordinator.start()
            await setupModel.restoreCodexSession()
#endif
            if !isUITesting && validationRootURL == nil {
                setupModel.presentCodexSetupIfNeeded()
            }
            if !isUITesting {
                await cloudSyncRunner?.start()
            }
        }
        DispatchQueue.main.async {
            Task { await startup() }
        }
    }

    var body: some Scene {
        Settings {
            AnchorMacSettingsScene(
                model: model,
                controller: server,
                sourceSetupModel: sourceSetupModel
            )
        }
    }
}
