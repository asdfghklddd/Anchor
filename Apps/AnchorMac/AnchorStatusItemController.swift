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
    private var feedbackTask: Task<Void, Never>?
    private var feedbackMessage: String?
    private var feedbackIsError = false
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
        feedbackTask?.cancel()
        feedbackTask = nil
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
        if let feedbackMessage {
            let symbol = feedbackIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: feedbackMessage)
            image?.isTemplate = true
            button.image = image
            button.appearsDisabled = false
            button.toolTip = feedbackMessage
            button.setAccessibilityLabel("\(L10n.appName), \(feedbackMessage)")
            return
        }
        button.image = Self.image(withDot: state.icon == .needsAttention)
        button.appearsDisabled = state.icon == .away
        button.toolTip = L10n.appName
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

        let connection = actionItem(
            StatusMenuCopy.link(state.link),
            selector: #selector(showConnectionSettings(_:))
        )
        connection.subtitle = [state.peerDeviceSummary, StatusMenuCopy.openConnectionSettings]
            .compactMap { $0 }
            .joined(separator: " · ")
        menu.addItem(connection)
        if !state.isConnected, state.unsent > 0 {
            menu.addItem(Self.note(StatusMenuCopy.unsent(state.unsent), secondary: true))
        }
        if state.link == .notPaired, let pairingCode {
            let code = Self.note(StatusMenuCopy.pairingCode(pairingCode))
            code.subtitle = StatusMenuCopy.pairingCodeHint
            menu.addItem(code)
        }
        if let fix = state.fix {
            let selector: Selector = switch fix {
            case .reconnect: #selector(reconnect(_:))
            case .openBluetoothSettings: #selector(openBluetoothSettings(_:))
            case .openBluetoothPrivacy: #selector(openBluetoothPrivacy(_:))
            }
            let item = actionItem(StatusMenuCopy.fix(fix), selector: selector)
            if fix == .reconnect { item.subtitle = StatusMenuCopy.reconnectHint }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(agentItem(ready: state.codexReady && state.claudeReady))

        menu.addItem(.separator())
        let copy = actionItem(StatusMenuCopy.copyNextStep, selector: #selector(copyNextStep(_:)))
        copy.isEnabled = state.prompt != nil
        copy.subtitle = state.nextStepLine ?? StatusMenuCopy.copyUnavailable
        menu.addItem(copy)

        menu.addItem(.separator())
        let login = actionItem(StatusMenuCopy.openAtLogin, selector: #selector(toggleLoginAtLaunch(_:)))
        login.state = MacLaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        let settings = actionItem(StatusMenuCopy.settings, selector: #selector(showConnectionSettings(_:)))
        settings.keyEquivalent = ","
        menu.addItem(settings)
        let quit = actionItem(StatusMenuCopy.quit, selector: #selector(quit(_:)))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    private func agentItem(ready: Bool) -> NSMenuItem {
        if ready {
            let item = actionItem(StatusMenuCopy.agentSourcesReady, selector: #selector(showSourceSettings(_:)))
            item.subtitle = StatusMenuCopy.openSourcesSettings
            return item
        }
        let item = actionItem(StatusMenuCopy.agentSourcesConnect, selector: #selector(authorizeAgentFolders(_:)))
        item.subtitle = StatusMenuCopy.agentSourcesConnectHint
        return item
    }

    private func actionItem(_ title: String, selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func showConnectionSettings(_ item: NSMenuItem) {
        onOpenSettings()
    }

    @objc private func showSourceSettings(_ item: NSMenuItem) {
        onOpenSettings()
    }

    @objc private func reconnect(_ item: NSMenuItem) {
        Task { await linkController.retryConnection() }
    }

    @objc private func openBluetoothSettings(_ item: NSMenuItem) {
        Self.openSystemSettings("x-apple.systempreferences:com.apple.BluetoothSettings")
    }

    @objc private func openBluetoothPrivacy(_ item: NSMenuItem) {
        Self.openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
    }

    @objc private func authorizeAgentFolders(_ item: NSMenuItem) {
        authorizeFolders { await self.sourceSetupModel.authorizeAgentSessionFolders() }
    }

    private func authorizeFolders(_ action: @escaping @MainActor () async -> Void) {
        NSApp.activate(ignoringOtherApps: true)
        Task { await action() }
    }

    @objc private func copyNextStep(_ item: NSMenuItem) {
        guard let prompt = state.prompt else { return }
        NSPasteboard.general.clearContents()
        if NSPasteboard.general.setString(prompt, forType: .string) {
            showFeedback(StatusMenuCopy.nextStepCopied)
        } else {
            showFeedback(StatusMenuCopy.copyFailed, isError: true)
        }
    }

    @objc private func toggleLoginAtLaunch(_ item: NSMenuItem) {
        let enabled = !MacLaunchAtLogin.isEnabled
        do {
            try MacLaunchAtLogin.setEnabled(enabled)
            showFeedback(enabled ? StatusMenuCopy.loginEnabled : StatusMenuCopy.loginDisabled)
        } catch {
            showFeedback(StatusMenuCopy.loginFailed(error.localizedDescription), isError: true)
        }
    }

    @objc private func quit(_ item: NSMenuItem) {
        NSApp.terminate(nil)
    }

    private static func openSystemSettings(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }

    /// A line of status: not clickable, but not greyed out like a disabled action.
    private static func note(_ title: String, secondary: Bool = false, subtitle: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: secondary ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ])
        if let subtitle { item.subtitle = subtitle }
        item.isEnabled = false
        return item
    }

    private func showFeedback(_ message: String, isError: Bool = false) {
        feedbackTask?.cancel()
        feedbackMessage = message
        feedbackIsError = isError
        updateIcon()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard let self, !Task.isCancelled else { return }
            self.feedbackMessage = nil
            self.feedbackIsError = false
            self.feedbackTask = nil
            self.updateIcon()
        }
    }
}
