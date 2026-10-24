import AnchorCore
import AnchorDesign
import AnchorMacFeatures
import AppKit

/// The default Mac Anchor: an icon in the menu bar and a short native menu.
/// The phone holds the dashboard; this shows whether it is connected, the one
/// thing that fixes it when not, and what only the Mac can do.
@MainActor
final class AnchorStatusItemController: NSObject, NSMenuDelegate {
    private let model: AnchorSessionModel
    private let linkController: any LocalLinkControlling
    private let sourceSetupModel: MacSourceSetupModel
    private let bluetooth: MacBluetoothRadioState
    private let onOpenSettings: () -> Void
    private var statusItem: NSStatusItem?
    private var pairing = DevicePairingStatus.automatic
    private var pairingCode: String?
    private var pairingTask: Task<Void, Never>?
    private var isStarted = false

    init(
        model: AnchorSessionModel,
        linkController: any LocalLinkControlling,
        sourceSetupModel: MacSourceSetupModel,
        bluetooth: MacBluetoothRadioState,
        onOpenSettings: @escaping () -> Void
    ) {
        self.model = model
        self.linkController = linkController
        self.sourceSetupModel = sourceSetupModel
        self.bluetooth = bluetooth
        self.onOpenSettings = onOpenSettings
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // A crowded bar beside the notch hides the newest icon; once the person
        // ⌘-drags it somewhere visible, it stays there.
        item.autosaveName = "anchor.status-item"
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        item.menu = menu
        item.button?.toolTip = L10n.appName
        statusItem = item
        observe()
        let updates = linkController.pairingStatusUpdates()
        pairingTask = Task { [weak self] in
            for await status in updates {
                guard let self else { return }
                pairing = status
                pairingCode = status.phase == .verificationCodeRequired
                    ? await linkController.currentPairingCode() : nil
                updateIcon()
            }
        }
    }

    func stop() {
        isStarted = false
        pairingTask?.cancel()
        pairingTask = nil
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    private var state: AnchorStatusMenu {
        AnchorStatusMenu(
            projection: model.projection,
            radio: bluetooth.radio,
            pairing: pairing,
            codexReady: sourceSetupModel.codexSessionsFolderName != nil,
            claudeReady: sourceSetupModel.claudeProjectsFolderName != nil
        )
    }

    // MARK: Icon

    private func observe() {
        guard isStarted else { return }
        withObservationTracking {
            updateIcon()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    /// Full when connected, dimmed while the phone is away, with a dot when
    /// something needs the person.
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let state = state
        button.image = Self.image(withDot: state.icon == .needsAttention)
        button.appearsDisabled = state.icon == .away
        button.setAccessibilityLabel("\(L10n.appName), \(StatusMenuCopy.link(state.link))")
    }

    private static func image(withDot: Bool) -> NSImage? {
        guard let base = NSImage(named: "AnchorMenuBarIcon") else {
            return NSImage(systemSymbolName: "sailboat", accessibilityDescription: L10n.appName)
        }
        base.isTemplate = true
        guard withDot else { return base }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: size.width - 6, y: size.height - 6, width: 6, height: 6)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = state

        menu.addItem(Self.note(StatusMenuCopy.link(state.link)))
        if !state.isConnected, state.unsent > 0 {
            menu.addItem(Self.note(StatusMenuCopy.unsent(state.unsent), secondary: true))
        }
        if state.link == .notPaired, let pairingCode {
            let code = Self.note(StatusMenuCopy.pairingCode(pairingCode))
            code.subtitle = StatusMenuCopy.pairingCodeHint
            menu.addItem(code)
        }
        if let fix = state.fix {
            let item = StatusMenuAction.item(StatusMenuCopy.fix(fix)) { [weak self] in self?.perform(fix) }
            if fix == .reconnect { item.subtitle = StatusMenuCopy.reconnectHint }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(agentItem("Codex", ready: state.codexReady) { [weak self] in
            await self?.sourceSetupModel.authorizeCodexSessionsFolder()
        })
        menu.addItem(agentItem("Claude Code", ready: state.claudeReady) { [weak self] in
            await self?.sourceSetupModel.authorizeClaudeCodeFolder()
        })

        menu.addItem(.separator())
        let copy = StatusMenuAction.item(StatusMenuCopy.copyNextStep) {
            guard let prompt = state.prompt else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        }
        copy.isEnabled = state.prompt != nil
        copy.subtitle = state.nextStepLine ?? StatusMenuCopy.copyUnavailable
        menu.addItem(copy)

        menu.addItem(.separator())
        let login = StatusMenuAction.item(StatusMenuCopy.openAtLogin) {
            try? MacLaunchAtLogin.setEnabled(!MacLaunchAtLogin.isEnabled)
        }
        login.state = MacLaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        let settings = StatusMenuAction.item(StatusMenuCopy.settings) { [weak self] in self?.onOpenSettings() }
        settings.keyEquivalent = ","
        menu.addItem(settings)
        let quit = StatusMenuAction.item(StatusMenuCopy.quit) { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func agentItem(_ name: String, ready: Bool,
                           authorize: @escaping @MainActor () async -> Void) -> NSMenuItem {
        if ready { return Self.note(StatusMenuCopy.agentReady(name)) }
        let item = StatusMenuAction.item(StatusMenuCopy.agentGrant(name)) {
            // A menu bar app has no window in front; the folder panel needs one.
            NSApp.activate(ignoringOtherApps: true)
            Task { await authorize() }
        }
        item.subtitle = StatusMenuCopy.agentGrantHint
        return item
    }

    private func perform(_ fix: AnchorStatusMenu.Fix) {
        switch fix {
        case .reconnect:
            Task { await linkController.retryConnection() }
        case .openBluetoothSettings:
            Self.openSystemSettings("x-apple.systempreferences:com.apple.BluetoothSettings")
        case .openBluetoothPrivacy:
            Self.openSystemSettings(
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
        }
    }

    private static func openSystemSettings(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }

    /// A line of status: not clickable, but not greyed out like a disabled action.
    private static func note(_ title: String, secondary: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: secondary ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ])
        item.isEnabled = false
        return item
    }
}

/// Menu items that run a closure, for menus built in code.
private final class StatusMenuAction: NSObject {
    /// Items hold their target weakly; one shared target outlives every menu.
    static let shared = StatusMenuAction()

    static func item(_ title: String, run: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(perform(_:)), keyEquivalent: "")
        item.target = shared
        item.representedObject = run
        return item
    }

    @MainActor @objc private func perform(_ item: NSMenuItem) {
        (item.representedObject as? @MainActor () -> Void)?()
    }
}
