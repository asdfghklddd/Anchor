import AnchorCore
import AnchorMacFeatures
import AppKit

@MainActor
final class AnchorMacApplicationDelegate: NSObject, NSApplicationDelegate {
    private var model: AnchorSessionModel?
    private var linkController: (any LocalLinkControlling)?
    private var sourceSetupModel: MacSourceSetupModel?
    private var detailWindowController: AnchorMacDetailWindowController?
    private var edgePanelController: AnchorEdgePanelController?
    private var phoneAnchorState: AnchorPhoneAnchorState?
    private var interfaceDefaults: UserDefaults?
    private var didFinishLaunching = false

    func configure(
        model: AnchorSessionModel,
        linkController: any LocalLinkControlling,
        sourceSetupModel: MacSourceSetupModel,
        phoneAnchorState: AnchorPhoneAnchorState,
        defaults: UserDefaults?
    ) {
        self.model = model
        self.linkController = linkController
        self.sourceSetupModel = sourceSetupModel
        self.phoneAnchorState = phoneAnchorState
        interfaceDefaults = defaults
        startInterfaceIfReady()
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
        edgePanelController?.stop()
        model?.stop()
    }

    private func startInterfaceIfReady() {
        guard didFinishLaunching,
              edgePanelController == nil,
              let model,
              let linkController,
              let sourceSetupModel,
              let phoneAnchorState else {
            return
        }

        let detailWindowController = AnchorMacDetailWindowController(
            model: model,
            linkController: linkController,
            sourceSetupModel: sourceSetupModel,
            defaults: interfaceDefaults
        )
        self.detailWindowController = detailWindowController

        let edgePanelController = AnchorEdgePanelController(
            model: model,
            phoneAnchorState: phoneAnchorState,
            onOpenDetails: { [weak detailWindowController] in
                detailWindowController?.present()
            }
        )
        self.edgePanelController = edgePanelController
        edgePanelController.start()
    }
}
