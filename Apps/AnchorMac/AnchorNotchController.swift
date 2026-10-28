import AnchorCore
import AnchorDesign
import AnchorMacFeatures
import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Anchor on the Mac: the island around the camera housing. It opens when the
/// pointer rests on it and closes when the pointer leaves; ⌃⌥A opens it from
/// the keyboard. It never activates Anchor, so a copied step pastes straight
/// into the person's own app.
@MainActor
final class AnchorNotchController {
    private let model: AnchorSessionModel
    private let linkController: any LocalLinkControlling
    private let sourceSetupModel: MacSourceSetupModel
    private let bluetooth: MacBluetoothRadioState
    private let onOpenSettings: () -> Void

    private let state: NotchIslandState
    private let panel: AnchorNotchPanel
    private var hover = NotchHoverMachine()
    private var timerTask: Task<Void, Never>?
    private var pointerMonitors: [Any] = []
    /// While open: a click anywhere else closes the island.
    private var clickMonitors: [Any] = []
    private var pairing = DevicePairingStatus.automatic
    private var pairingTask: Task<Void, Never>?
    private var hotKey: AnchorHotKey?
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
        let geometry = Self.currentGeometry()
        state = NotchIslandState(
            content: NotchIslandContent(
                status: AnchorStatusMenu(
                    projection: model.projection, radio: bluetooth.radio, pairing: .automatic,
                    codexReady: sourceSetupModel.codexSessionsFolderName != nil,
                    claudeReady: sourceSetupModel.claudeProjectsFolderName != nil
                ),
                projection: model.projection
            ),
            geometry: geometry
        )
        panel = AnchorNotchPanel(
            contentRect: geometry.panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        model.start()
        installContent()
        reposition()
        panel.orderFrontRegardless()
        observe()
        let updates = linkController.pairingStatusUpdates()
        pairingTask = Task { [weak self] in
            for await status in updates {
                guard let self else { return }
                pairing = status
                refreshContent()
            }
        }
        let move: (NSEvent) -> Void = { [weak self] _ in self?.pointerMoved() }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: {
            event in MainActor.assumeIsolated { move(event) }
        }) {
            pointerMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: {
            event in
            MainActor.assumeIsolated { move(event) }
            return event
        }) {
            pointerMonitors.append(local)
        }
        hotKey = AnchorHotKey(keyCode: UInt32(kVK_ANSI_A), modifiers: UInt32(controlKey | optionKey)) {
            [weak self] in self?.toggleFromKeyboard()
        }
    }

    func stop() {
        isStarted = false
        timerTask?.cancel()
        pairingTask?.cancel()
        pairingTask = nil
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors = []
        removeClickMonitors()
        hotKey = nil
        panel.orderOut(nil)
    }

    /// Follows the housing when screens are plugged in, removed or rearranged.
    func reposition() {
        let geometry = Self.currentGeometry()
        state.geometry = geometry
        panel.setFrame(geometry.panelFrame, display: true)
    }

    /// From a notification about one task: that task, with the island open.
    func openTask(_ id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            _ = await model.selectHostedTask(id)
            hover.open(pinned: true)
            apply()
        }
    }

    private static func currentGeometry() -> NotchIslandGeometry {
        if let screen = NotchIslandGeometry.preferredScreen() {
            return NotchIslandGeometry(screen: screen)
        }
        return NotchIslandGeometry(notch: CGSize(width: 164, height: 24), notchMidX: 0, screenMaxY: 0, hasNotch: false)
    }

    // MARK: Pointer

    /// The panel lets clicks through everywhere but the island itself.
    private func pointerMoved() {
        let inside = state.pointerZone.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        guard inside != hover.isPointerInside else { return }
        timerTask?.cancel()
        let timer = inside ? hover.pointerEntered() : hover.pointerExited()
        if let timer { schedule(timer) }
        apply()
    }

    private func schedule(_ timer: NotchHoverMachine.Timer) {
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: timer == .dwell ? NotchHoverMachine.dwell : NotchHoverMachine.grace)
            guard !Task.isCancelled, let self else { return }
            switch timer {
            case .dwell: hover.dwellElapsed()
            case .grace: hover.graceElapsed()
            }
            apply()
        }
    }

    private func toggleFromKeyboard() {
        if hover.phase == .expanded {
            dismiss()
            return
        }
        hover.open(pinned: true)
        apply()
        panel.ignoresMouseEvents = false
        // Key without activating Anchor, so Esc and Tab work here.
        panel.makeKey()
    }

    private func dismiss() {
        timerTask?.cancel()
        hover.dismiss()
        apply()
    }

    /// Hands the new phase to the view, which animates it.
    private func apply() {
        guard state.phase != hover.phase else { return }
        state.phase = hover.phase
        if hover.phase == .expanded {
            installClickMonitors()
        } else {
            removeClickMonitors()
            if panel.isKeyWindow {
                // Give the keyboard back to the person's app without hiding the island.
                panel.orderOut(nil)
                panel.orderFrontRegardless()
            }
            panel.ignoresMouseEvents = !state.pointerZone.contains(NSEvent.mouseLocation)
        }
    }

    private func installClickMonitors() {
        guard clickMonitors.isEmpty else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: {
            [weak self] _ in MainActor.assumeIsolated { self?.dismiss() }
        }) {
            clickMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: {
            [weak self] event in
            MainActor.assumeIsolated {
                if let self, event.window !== self.panel { self.dismiss() }
            }
            return event
        }) {
            clickMonitors.append(local)
        }
    }

    private func removeClickMonitors() {
        clickMonitors.forEach(NSEvent.removeMonitor)
        clickMonitors = []
    }

    // MARK: Content

    private func observe() {
        guard isStarted else { return }
        withObservationTracking {
            refreshContent()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func refreshContent() {
        let content = NotchIslandContent(
            status: AnchorStatusMenu(
                projection: model.projection,
                radio: bluetooth.radio,
                pairing: pairing,
                codexReady: sourceSetupModel.codexSessionsFolderName != nil,
                claudeReady: sourceSetupModel.claudeProjectsFolderName != nil
            ),
            projection: model.projection
        )
        if content != state.content { state.content = content }
    }

    private func perform(_ action: NotchIslandAction) {
        switch action {
        case .copyNextStep:
            guard let prompt = state.content.prompt else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        case let .selectTask(id):
            Task { _ = await model.selectHostedTask(id) }
        case .openSettings:
            dismiss()
            onOpenSettings()
        case let .fixLink(fix):
            switch fix {
            case .reconnect:
                Task { await linkController.retryConnection() }
            case .openBluetoothSettings:
                Self.openSystemSettings("x-apple.systempreferences:com.apple.BluetoothSettings")
            case .openBluetoothPrivacy:
                Self.openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth")
            }
        case .connectSources:
            dismiss()
            NSApp.activate(ignoringOtherApps: true)
            Task { await sourceSetupModel.authorizeAgentSessionFolders() }
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private static func openSystemSettings(_ address: String) {
        guard let url = URL(string: address) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Panel

    private func configurePanel() {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // Above the menu bar, which the island sits in.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.animationBehavior = .none
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        // A click on a button leaves the person's app in front.
        panel.becomesKeyOnlyIfNeeded = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.onCancel = { [weak self] in self?.dismiss() }
    }

    private func installContent() {
        let view = NotchIslandView(state: state) { [weak self] action in self?.perform(action) }
            .environment(\.locale, AnchorStrings.interfaceLocale)
        let host = NSHostingView(rootView: view)
        // The panel keeps its size; only the island inside it moves.
        host.sizingOptions = []
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = host
    }
}

/// The island's window: borderless, yet able to take the keyboard when opened
/// with the shortcut, so Esc closes it.
final class AnchorNotchPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

/// A system-wide shortcut. Carbon's hot keys need no Accessibility permission
/// and work inside the sandbox.
@MainActor
final class AnchorHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), AnchorHotKey.handle, 1, &pressed,
                                            context, &handlerRef)
        // 'ANCH'
        let id = EventHotKeyID(signature: OSType(0x414E_4348), id: 1)
        guard installed == noErr,
              RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
        else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    isolated deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// Carbon calls this on the main thread.
    private static let handle: EventHandlerUPP = { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        let address = UInt(bitPattern: context)
        MainActor.assumeIsolated {
            guard let pointer = UnsafeRawPointer(bitPattern: address) else { return }
            Unmanaged<AnchorHotKey>.fromOpaque(pointer).takeUnretainedValue().action()
        }
        return noErr
    }
}
