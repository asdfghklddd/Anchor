import AnchorCore
import AnchorMacFeatures
import AnchorTransport
import AppKit
import SwiftUI

@main
struct AnchorMacApp: App {
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
#if DEBUG
        isUITesting = environment["ANCHOR_UI_TESTING"] == "1"
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
        pairingIdentityService = isUITesting
            ? "com.andywang.anchor.ui-tests.\(uiTestStorageID.uuidString)"
            : "com.andywang.anchor.local-link"
#else
        isUITesting = false
        validationRootURL = nil
        validationCodexURL = nil
        validationShouldSeedSession = false
        validationDefaults = nil
        pairingIdentityService = "com.andywang.anchor.local-link"
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
        let server = AnchorBonjourServer(identityStore: identityStore, deviceID: deviceID)
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
        cloudSyncRunner = isUITesting
            ? nil
            : AnchorCloudSyncFactory.makeRunner(local: localRepository)
#else
        cloudSyncRunner = AnchorCloudSyncFactory.makeRunner(local: localRepository)
#endif
        let repository = LinkedSessionRepository(base: localRepository, transport: server)
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
        let sources: [any ProcessSource] = [
            FileProcessSource(sessionContextProvider: currentSessionContext),
            WebProcessSource(sessionContextProvider: currentSessionContext),
            workspaceSource,
        ]
        // Discovery is a candidate only. Register Codex after explicit source-session binding.
        let sourceCoordinator = ProcessSourceCoordinator(
            repository: repository,
            sources: sources,
            taskRunStore: taskRunStore
        )
        server.onCurrentProcessSnapshot = {
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
            advertiser.start()
        }
        self.server = server
        proximityAdvertiser = advertiser
        self.cloudSyncRunner = cloudSyncRunner
        let bindCodexSession: @MainActor @Sendable (URL) async throws -> Void = { fileURL in
            guard let session = await repository.currentProjection().session else {
                throw SessionRepositoryError.noActiveSession
            }
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
            try await taskRunStore.upsert(task: task)
            try await taskRunStore.upsert(workItem: workItem)
            let codexSource = CodexLifecycleFileSource(
                fileURL: fileURL,
                sessionContextProvider: currentSessionContext,
                checkpointStore: codexCheckpointStore
            )
            try await sourceCoordinator.setAssociation(
                AnchorEventAssociation(taskID: task.id, workItemID: workItem.id, confirmedByUser: true),
                for: session.id,
                sourceID: codexSource.descriptor.id
            )
            await sourceCoordinator.register(codexSource)
        }
        let setupModel = MacSourceSetupModel(
            defaults: validationDefaults ?? .standard,
            onCodexSessionSelected: bindCodexSession,
            taskStateProvider: {
                await taskRunStore.currentTaskRecord()?.state
            }
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
        Window("Anchor", id: "anchor-details") {
            AnchorMacRootView(
                model: model,
                linkController: server,
                sourceSetupModel: sourceSetupModel,
                showsCompletedSessionInCurrentWork: false
            )
        }
        .defaultSize(width: 1080, height: 720)

        MenuBarExtra {
            MacMenuHost(model: model)
        } label: {
            Label {
                Text("Anchor")
            } icon: {
                Image("AnchorMenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
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
            onQuit: { NSApp.terminate(nil) },
            showsCompletedSessionInCurrentWork: false
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
