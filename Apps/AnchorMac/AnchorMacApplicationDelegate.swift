import AnchorCore
import AnchorMacFeatures
import AppKit

@MainActor
final class AnchorMacApplicationDelegate: NSObject, NSApplicationDelegate {
    private var model: AnchorSessionModel?
    private var linkController: (any LocalLinkControlling)?
    private var sourceSetupModel: MacSourceSetupModel?
    private var detailWindowController: AnchorMacDetailWindowController?
    private var settingsWindowController: AnchorSettingsWindowController?
    private var notchController: AnchorNotchController?
    private var bluetoothRadio: MacBluetoothRadioState?
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
        // Opening Anchor again, from Finder or Spotlight, brings up its settings.
        openSettings()
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
        if let bluetoothRadio {
            settingsWindowController = AnchorSettingsWindowController(
                model: model,
                linkController: linkController,
                sourceSetupModel: sourceSetupModel,
                bluetooth: bluetoothRadio,
                defaults: interfaceDefaults
            )
        }
        // First run: the island opens on its one button, connecting the agent folders.
        sourceSetupModel.onNeedsAttention = { [weak self, weak sourceSetupModel] in
            sourceSetupModel?.finishCodexOnboarding()
            self?.notchController?.openPinned()
        }
        model.start()
        startNotch()
        if sourceSetupModel.showsCodexOnboarding {
            sourceSetupModel.onNeedsAttention?()
        }
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
            onOpenSettings: { [weak self] in self?.openSettings() },
            onOpenWindow: { [weak self] in self?.detailWindowController?.present() }
        )
        notchController = controller
        controller.start()
    }

    private func openSettings() {
        settingsWindowController?.present()
    }
}
