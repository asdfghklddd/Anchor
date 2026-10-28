import AnchorCore
import AnchorMacFeatures
import AppKit
import UserNotifications

@MainActor
final class AnchorMacApplicationDelegate: NSObject, NSApplicationDelegate {
    private var model: AnchorSessionModel?
    private var linkController: (any LocalLinkControlling)?
    private var sourceSetupModel: MacSourceSetupModel?
    private var detailWindowController: AnchorMacDetailWindowController?
    private var notchController: AnchorNotchController?
    private var bluetoothRadio: MacBluetoothRadioState?
    private var codexTurnEndNotifier: MacCodexTurnEndNotifier?
    private var phoneAnchorState: AnchorPhoneAnchorState?
    private var interfaceDefaults: UserDefaults?
    private var didFinishLaunching = false

    func configure(
        model: AnchorSessionModel,
        linkController: any LocalLinkControlling,
        sourceSetupModel: MacSourceSetupModel,
        phoneAnchorState: AnchorPhoneAnchorState,
        bluetoothRadio: MacBluetoothRadioState,
        defaults: UserDefaults?
    ) {
        self.model = model
        self.linkController = linkController
        self.sourceSetupModel = sourceSetupModel
        self.phoneAnchorState = phoneAnchorState
        self.bluetoothRadio = bluetoothRadio
        interfaceDefaults = defaults
        startInterfaceIfReady()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Set before launch completes, so a click on a ping can open the app.
        UNUserNotificationCenter.current().delegate = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        didFinishLaunching = true
        startInterfaceIfReady()
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        notchController?.reposition()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        detailWindowController?.present()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        sourceSetupModel?.stopObserving()
        notchController?.stop()
        model?.stop()
    }

    private func startInterfaceIfReady() {
        guard didFinishLaunching,
              detailWindowController == nil,
              let model,
              let sourceSetupModel else {
            return
        }

        let detailWindowController = AnchorMacDetailWindowController(
            model: model,
            linkController: linkController,
            sourceSetupModel: sourceSetupModel,
            defaults: interfaceDefaults
        )
        self.detailWindowController = detailWindowController
        sourceSetupModel.onNeedsAttention = { [weak detailWindowController] in
            detailWindowController?.present()
        }
        if sourceSetupModel.showsCodexOnboarding {
            detailWindowController.present()
        }
        let codexTurnEndNotifier = MacCodexTurnEndNotifier(defaults: interfaceDefaults ?? .standard)
        self.codexTurnEndNotifier = codexTurnEndNotifier
        // A ping names the task and step its conversation was placed under.
        sourceSetupModel.onCodexTurnsEnded = { [weak codexTurnEndNotifier, weak sourceSetupModel, weak model] endings in
            guard let sourceSetupModel else { return }
            let tasks = model?.projection.hostedSessions ?? []
            codexTurnEndNotifier?.notify(endings) { CodexTurnEndContext.of($0.id, setup: sourceSetupModel, tasks: tasks) }
        }

        model.start()
        startNotch()
    }

    /// Anchor lives in the island around the camera housing.
    private func startNotch() {
        guard notchController == nil, let model, let linkController, let sourceSetupModel,
              let bluetoothRadio else { return }
        let controller = AnchorNotchController(
            model: model,
            linkController: linkController,
            sourceSetupModel: sourceSetupModel,
            bluetooth: bluetoothRadio,
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        notchController = controller
        controller.start()
    }

    private func openSettings() {
        AnchorMacRootView.showSettings(in: interfaceDefaults ?? .standard)
        detailWindowController?.present()
    }

    /// Makes a task the one the person is on and opens the island on it.
    private func openTask(_ id: UUID) {
        if let notchController {
            notchController.openTask(id)
            return
        }
        Task {
            _ = await model?.selectHostedTask(id)
            detailWindowController?.present()
        }
    }
}

extension AnchorMacApplicationDelegate: UNUserNotificationCenterDelegate {
    /// A Codex ping opens its task when the conversation was placed under one,
    /// else the dashboard, where its conversation row has the rest.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let thread = response.notification.request.content.threadIdentifier
        guard response.notification.request.identifier
            .hasPrefix(MacCodexTurnEndNotifier.identifierPrefix) else { return }
        await MainActor.run {
            let conversationID = String(thread.dropFirst(MacCodexTurnEndNotifier.identifierPrefix.count))
            if let taskID = self.sourceSetupModel?.conversationTasks[conversationID] {
                self.openTask(taskID)
            } else {
                self.detailWindowController?.present()
            }
        }
    }
}
