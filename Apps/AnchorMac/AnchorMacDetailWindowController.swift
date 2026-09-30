import AnchorCore
import AnchorMacFeatures
import AppKit
import SwiftUI

@MainActor
final class AnchorMacDetailWindowController: NSWindowController {
    private static let frameName = "anchor.details.window"

    init(
        model: AnchorSessionModel,
        linkController: (any LocalLinkControlling)?,
        sourceSetupModel: MacSourceSetupModel,
        defaults: UserDefaults?
    ) {
        let rootView = AnchorMacRootView(
            model: model,
            linkController: linkController,
            sourceSetupModel: sourceSetupModel,
            showsCompletedSessionInCurrentWork: false
        )
        let hostingController = NSHostingController(
            rootView: rootView.defaultAppStorage(defaults ?? .standard)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Anchor"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        // Extend the workspace behind native window controls instead of drawing a title bar.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 1080, height: 720))
        window.minSize = NSSize(width: 900, height: 620)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed

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
        guard let window else { return }
        // SwiftUI navigation may update native title-bar attributes while mounting.
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
