import AnchorCore
import AnchorMacFeatures
import AnchorTransport
import AppKit
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
        usesAutomaticICloudPairing = !isUITesting
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
        let identityStore = PairingIdentityStore(service: pairingIdentityService)
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
        let taskRunStore = validationRootURL.map {
            TaskRunStore(url: $0.appending(path: "task-runs.json"))
        } ?? TaskRunStore()
        let codexCheckpointStore = validationRootURL.map {
            CodexLifecycleCheckpointStore(storageURL: $0.appending(path: "codex-checkpoints.json"))
        } ?? CodexLifecycleCheckpointStore()
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
        let workspaceSource = MacWorkspaceProcessSource(
            sessionIDProvider: currentSessionID
        )
        let sources: [any ProcessSource] = validationRootURL == nil ? [
            FileProcessSource(sessionContextProvider: currentSessionContext),
            WebProcessSource(sessionContextProvider: currentSessionContext),
            workspaceSource,
        ] : []
        // Register Codex after manual selection or a high-confidence automatic match.
        let sourceCoordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: sources,
            taskRunStore: taskRunStore
        )
        let currentProcessSnapshot: @Sendable () async throws -> CurrentProcessSnapshot = {
            let projection = await repository.currentProjection()
            if let session = projection.session {
                return CurrentProcessSnapshot(
                    processNames: session.processes.map(\.sourceName)
                )
            }

            let runningApplications = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap(\ .localizedName)
            return CurrentProcessSnapshot(processNames: runningApplications)
        }
        server.onCurrentProcessSnapshot = currentProcessSnapshot
        advertiser.onCurrentProcessSnapshot = currentProcessSnapshot
        let phoneAnchorState = AnchorPhoneAnchorState()
        let decisionActionGate = SourceDecisionActionGate()
        let applyInboundEvent: @Sendable (EventEnvelope) async throws -> Void = { envelope in
            let before = await repository.currentProjection()
            try await repository.applyRemote(envelope)
            let appliedProjection = await repository.currentProjection()
            await phoneAnchorState.receive(envelope, projection: appliedProjection, localSourceID: deviceID)
            guard let operation = try? JSONDecoder.anchor.decode(SessionOperation.self, from: envelope.payload),
                  let claimed = await decisionActionGate.claim(operation: operation,
                    sessionID: envelope.sessionID, before: before, after: appliedProjection) else { return }
            // The local event is already durable. A source action is best
            // effort and is reported through source health without blocking
            // the transport acknowledgement or causing a retry storm.
            Task {
                _ = try? await sourceCoordinator.perform(claimed.action, on: claimed.sourceID)
            }
        }
        server.onEvent = applyInboundEvent
        advertiser.onEvent = applyInboundEvent
        advertiser.onConnectionState = { state in
            server.updateFallbackConnection(state)
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
        let bindCodexSession: @MainActor @Sendable (URL, UUID?) async throws -> Void = { fileURL, automaticSessionID in
            let projection = await repository.currentProjection()
            guard let session = automaticSessionID.flatMap({ id in projection.hostedSessions.first { $0.id == id } }) ?? (automaticSessionID == nil ? projection.session : nil) else {
                throw SessionRepositoryError.noActiveSession
            }
            let sourceID = StableProcessIdentity.id(
                namespace: "anchor.source.codex-session",
                sessionID: session.id,
                externalID: fileURL.lastPathComponent
            )
            let task = AnchorTask(
                id: session.id,
                title: session.goal.title,
                completionCriteria: session.goal.completionCriteria,
                createdAt: session.startedAt
            )
            let workItemID = StableProcessIdentity.id(
                namespace: "anchor.work-item.codex",
                sessionID: session.id,
                externalID: fileURL.lastPathComponent
            )
            let workItem = AnchorWorkItem(
                id: workItemID,
                taskID: task.id,
                title: "Codex conversation",
                createdAt: session.startedAt
            )
            try await taskRunStore.host(task: task)
            try await taskRunStore.upsert(workItem: workItem)
            let boundSessionContext: @Sendable () async -> ProcessSourceSessionContext? = {
                guard let bound = await repository.currentProjection().hostedSessions.first(where: { $0.id == session.id }) else { return nil }
                return ProcessSourceSessionContext(sessionID: bound.id, startedAt: bound.startedAt)
            }
            let codexSource = CodexLifecycleFileSource(
                fileURL: fileURL,
                sessionContextProvider: boundSessionContext,
                checkpointStore: codexCheckpointStore,
                descriptor: SourceDescriptor(
                    id: sourceID,
                    name: "Codex",
                    kind: .integration,
                    symbol: "C",
                    tone: "cyan",
                    capabilities: [.observe],
                    permission: .granted
                )
            )
            try await sourceCoordinator.setAssociation(
                AnchorEventAssociation(taskID: task.id, workItemID: workItem.id, confirmedByUser: automaticSessionID == nil, automaticallyMatched: automaticSessionID != nil),
                for: session.id,
                sourceID: codexSource.descriptor.id
            )
            await sourceCoordinator.register(codexSource)
        }
        let setupModel = MacSourceSetupModel(
            defaults: validationDefaults ?? .standard,
            onCodexSessionSelected: { url in try await bindCodexSession(url, nil) },
            currentAnchorSessionID: currentSessionID,
            taskStateProvider: {
                await taskRunStore.currentTaskRecord()?.state
            },
            autoAssociationSessions: { await repository.currentProjection().hostedSessions },
            onAutoAssociation: { url, sessionID in try await bindCodexSession(url, sessionID) }
        )
        sourceSetupModel = setupModel
        model = AnchorSessionModel(
            repository: repository,
            sourceHealthProvider: sourceCoordinator,
            sourceActionProvider: sourceCoordinator,
            durableSyncStatusProvider: cloudSyncRunner
        )
        self.sourceCoordinator = sourceCoordinator
        self.taskLifecycleBridge = taskLifecycleBridge
        applicationDelegate.configure(
            model: model,
            linkController: server,
            sourceSetupModel: sourceSetupModel,
            phoneAnchorState: phoneAnchorState,
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
