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
    private var edgePanelController: AnchorEdgePanelController?
    private var statusItemController: AnchorStatusItemController?
    private var bluetoothRadio: MacBluetoothRadioState?
    private var styleObserver: NSObjectProtocol?
    private var interfaceStyle: MacInterfaceStyle?
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
        edgePanelController?.reposition()
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
        edgePanelController?.stop()
        statusItemController?.stop()
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
        applyInterfaceStyle()
        // Settings writes the style; switch without a restart.
        styleObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyInterfaceStyle() }
        }
    }

    /// Shows Anchor as the menu bar icon (the default) or the floating boat.
    private func applyInterfaceStyle() {
        let style = MacInterfaceStyle.current(in: interfaceDefaults ?? .standard)
        guard style != interfaceStyle else { return }
        interfaceStyle = style
        switch style {
        case .menuBar:
            edgePanelController?.stop()
            edgePanelController = nil
            startStatusItem()
        case .boat:
            statusItemController?.stop()
            statusItemController = nil
            startEdgePanel()
        }
    }

    private func startStatusItem() {
        guard statusItemController == nil, let model, let linkController, let sourceSetupModel,
              let bluetoothRadio else { return }
        let controller = AnchorStatusItemController(
            model: model,
            linkController: linkController,
            sourceSetupModel: sourceSetupModel,
            bluetooth: bluetoothRadio,
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        statusItemController = controller
        controller.start()
    }

    private func startEdgePanel() {
        guard edgePanelController == nil, let model, let phoneAnchorState else { return }
        let edgePanelController = AnchorEdgePanelController(
            model: model,
            phoneAnchorState: phoneAnchorState,
            onOpenDetails: { [weak self] in
                self?.detailWindowController?.present()
            },
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
        self.edgePanelController = edgePanelController
        edgePanelController.start()
    }

    private func openSettings() {
        AnchorMacRootView.showSettings(in: interfaceDefaults ?? .standard)
        detailWindowController?.present()
    }

    /// Opens a task in the window and makes it the one the person is on.
    private func openTask(_ id: UUID) {
        if let edgePanelController {
            edgePanelController.openTask(id)
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
