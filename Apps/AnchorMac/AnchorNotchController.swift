import AnchorCore
import AnchorDesign
import AnchorMacFeatures
import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Anchor on the Mac: the island around the camera housing. It opens when the
/// pointer rests on it and closes when the pointer leaves; ⌃⌥A opens it from
/// the keyboard. It never activates Anchor, so a copied step pastes straight
/// into the person's own app. News stretches the closed island for a few
/// seconds: an agent finished or waits, the phone left, or a pairing code.
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
    private var pairingCode: String?
    private var pairingTask: Task<Void, Never>?
    private var detector = NotchPeekDetector()
    private var peeks = NotchPeekQueue()
    private var peekTask: Task<Void, Never>?
    private var hotKey: AnchorHotKey?
    /// A filing menu is open; the island stays put until it closes.
    private var isMenuTracking = false
    private var menuObservers: [NSObjectProtocol] = []
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
                pairingCode = status.phase == .verificationCodeRequired
                    ? await linkController.currentPairingCode() : nil
                refreshContent()
                if let pairingCode {
                    // Status repeats; only a new code is news.
                    if !peeks.items.contains(where: { $0.kind == .pairing && $0.detail == pairingCode }) {
                        peeks.add(.pairing(code: pairingCode))
                    }
                } else {
                    peeks.removePairing()
                }
                syncPeek()
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
        // The pointer leaves the island to reach a menu's items; that is not leaving.
        let center = NotificationCenter.default
        menuObservers = [
            center.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.menuTracking(true) }
            },
            center.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) {
                [weak self] _ in MainActor.assumeIsolated { self?.menuTracking(false) }
            },
        ]
    }

    private func menuTracking(_ tracking: Bool) {
        guard hover.phase == .expanded || !tracking else { return }
        isMenuTracking = tracking
        guard !tracking else { return }
        pointerMoved()
        // A close that came due while the menu was open still happens.
        if hover.phase == .expanded, !hover.isPointerInside { schedule(.grace) }
    }

    func stop() {
        isStarted = false
        timerTask?.cancel()
        peekTask?.cancel()
        pairingTask?.cancel()
        pairingTask = nil
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors = []
        removeClickMonitors()
        hotKey = nil
        menuObservers.forEach(NotificationCenter.default.removeObserver)
        menuObservers = []
        panel.orderOut(nil)
    }

    /// Follows the housing when screens are plugged in, removed or rearranged.
    func reposition() {
        let geometry = Self.currentGeometry()
        state.geometry = geometry
        panel.setFrame(geometry.panelFrame, display: true)
    }

    /// Opens the island and keeps it open until a click elsewhere, without
    /// taking the keyboard: for first run, when there is one thing to do.
    func openPinned() {
        hover.endPeek()
        hover.open(pinned: true)
        apply()
        panel.ignoresMouseEvents = !state.pointerZone.contains(NSEvent.mouseLocation)
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
        guard !isMenuTracking else { return }
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
            guard !Task.isCancelled, let self, !isMenuTracking else { return }
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
        hover.endPeek()
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
        let previous = state.phase
        guard previous != hover.phase else { return }
        state.phase = hover.phase
        if hover.phase == .expanded {
            installClickMonitors()
            // Opened from a peek: its task stands out, and the open island
            // shows the rest of the news at once.
            if previous == .peek { state.highlightedTaskID = state.peek?.taskID }
            peekTask?.cancel()
            peeks.clearNews()
            state.peek = nil
        } else {
            removeClickMonitors()
            if panel.isKeyWindow {
                // Give the keyboard back to the person's app without hiding the island.
                panel.orderOut(nil)
                panel.orderFrontRegardless()
            }
            panel.ignoresMouseEvents = !state.pointerZone.contains(NSEvent.mouseLocation)
            if hover.phase == .compact {
                state.highlightedTaskID = nil
                if previous != .peek { syncPeek() }
            }
        }
    }

    // MARK: News

    /// Shows the first queued peek, or closes the peek when none is left.
    /// Only a closed island the pointer is not on stretches out.
    private func syncPeek() {
        guard let next = peeks.current else {
            peekTask?.cancel()
            if hover.phase == .peek {
                hover.endPeek()
                apply()
                state.peek = nil
            }
            return
        }
        guard hover.showPeek(), state.peek?.id != next.id else { return }
        state.peek = next
        apply()
        announce(next)
        peekTask?.cancel()
        guard let duration = next.duration else { return }
        peekTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled, let self else { return }
            peeks.advance()
            syncPeek()
        }
    }

    private func receive(_ news: [NotchPeek]) {
        guard !news.isEmpty else { return }
        for peek in news {
            if let task = peek.taskID { state.flash(task) }
        }
        let agentsMayPeek = UserDefaults.standard.object(forKey: NotchPeek.enabledDefaultsKey) as? Bool ?? true
        let shown = news.filter { agentsMayPeek || $0.taskID == nil }
        // The open island already shows it; a closed one that won't stretch gives a nudge.
        guard hover.phase != .expanded, hover.phase != .primed else { return }
        if shown.isEmpty {
            if hover.phase == .compact { state.nudges += 1 }
            return
        }
        shown.forEach { peeks.add($0) }
        syncPeek()
    }

    /// VoiceOver reads the news the island shows.
    private func announce(_ peek: NotchPeek) {
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [
            .announcement: [peek.title, peek.detail].filter { !$0.isEmpty }.joined(separator: ", "),
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    private func installClickMonitors() {
        guard clickMonitors.isEmpty else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: {
            [weak self] _ in MainActor.assumeIsolated {
                if self?.isMenuTracking == false { self?.dismiss() }
            }
        }) {
            clickMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: {
            [weak self] event in
            MainActor.assumeIsolated {
                if let self, !self.isMenuTracking, event.window !== self.panel { self.dismiss() }
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
        let status = AnchorStatusMenu(
            projection: model.projection,
            radio: bluetooth.radio,
            pairing: pairing,
            codexReady: sourceSetupModel.codexSessionsFolderName != nil,
            claudeReady: sourceSetupModel.claudeProjectsFolderName != nil
        )
        let filing = NotchFiling(
            conversations: sourceSetupModel.codexConversations,
            placements: sourceSetupModel.conversationTasks,
            unsorted: sourceSetupModel.unsortedConversations,
            candidates: sourceSetupModel.unsortedCandidates,
            tasks: model.projection.hostedSessions.filter { $0.status == .active || $0.status == .draft }
        )
        let content = NotchIslandContent(status: status, projection: model.projection,
                                         pairingCode: pairingCode, sourcesError: sourceSetupModel.errorMessage,
                                         filing: filing)
        // A failed folder pick shows its reason where the button was.
        let setupFailed = content.sourcesError != nil && state.content.sourcesError == nil
        if content != state.content { state.content = content }
        if setupFailed { openPinned() }
        receive(detector.peeks(in: model.projection, link: status.link, now: .now))
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
            if let url = fix.settingsURL {
                NSWorkspace.shared.open(url)
            } else {
                Task { await linkController.retryConnection() }
            }
        case .connectSources:
            dismiss()
            NSApp.activate(ignoringOtherApps: true)
            sourceSetupModel.clearError()
            Task { await sourceSetupModel.authorizeAgentSessionFolders() }
        case let .assign(conversationID, task):
            guard let conversation = conversation(conversationID) else { return }
            Task { await sourceSetupModel.assign(conversation, to: task) }
        case let .ignore(conversationID):
            guard let conversation = conversation(conversationID) else { return }
            Task { await sourceSetupModel.ignore(conversation) }
        case .quit:
            NSApp.terminate(nil)
        }
    }

    private func conversation(_ id: String) -> CodexConversationSummary? {
        sourceSetupModel.codexConversations.first { $0.id == id }
            ?? sourceSetupModel.unsortedConversations.first { $0.id == id }
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
