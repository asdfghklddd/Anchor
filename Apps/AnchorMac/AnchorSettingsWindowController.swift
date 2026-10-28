import AnchorCore
import AnchorDesign
import AnchorMacFeatures
import AppKit
import SwiftUI

/// Anchor's only window: a short, native settings window, opened from the
/// island's gear or by opening Anchor again.
@MainActor
final class AnchorSettingsWindowController: NSWindowController {
    private static let frameName = "anchor.settings.window"

    init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)?,
        sourceSetupModel: MacSourceSetupModel,
        bluetooth: MacBluetoothRadioState,
        defaults: UserDefaults?
    ) {
        let rootView = AnchorMacSettingsScene(
            model: model,
            controller: linkController,
            sourceSetupModel: sourceSetupModel,
            bluetooth: bluetooth
        )
        let hostingController = NSHostingController(
            rootView: rootView.defaultAppStorage(defaults ?? .standard)
                .environment(\.locale, AnchorStrings.interfaceLocale)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = L10n.settings
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 480, height: 640))
        if !window.setFrameUsingName(Self.frameName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameName)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
