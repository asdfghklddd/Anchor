import AnchorCore
import AnchorDesign
import AnchorMacFeatures
import AppKit
import Observation
import SwiftUI

@MainActor
final class AnchorEdgePanelController {
    private let model: AnchorSessionModel
    private let phoneAnchorState: AnchorPhoneAnchorState
    private let presentation: AnchorEdgePresentationModel
    private let onOpenDetails: () -> Void
    private let onOpenSettings: () -> Void
    private let soundPlayer: AnchorEdgeSoundPlayer

    private let controlPanel: AnchorControlPanel
    private let effectsPanel: AnchorDecorativePanel
    private var isStarted = false
    private var activationObserver: NSObjectProtocol?
    private var awayMonitor: MacAwayMonitor?
    private var welcomePanel: AnchorWelcomePanel?
    private var welcomeTimeout: Task<Void, Never>?
    /// The buttons around the boat, while they are out.
    private var menuPanel: AnchorWelcomePanel?
    private var menuMonitors: [Any] = []
    private var menuCloseTask: Task<Void, Never>?
    /// Where the boat berths; the person moves it by dragging.
    private var dock = AnchorEdgeDock.load(from: .standard)
    /// The pointer and the boat's origin when a drag began.
    private var drag: (mouse: NSPoint, origin: NSPoint)?
    /// The last time away and its recaps, for "Catch me up".
    private var lastAway: (since: Date, recaps: [UUID: String])?
    private let summaryBook: SummaryBook?
    /// Each open task's state when the person left, for the welcome back.
    private var leaveRecaps: [UUID: String] = [:]
    private var recapTask: Task<Void, Never>?
    /// A card nobody answered leaves on its own: the buoy still says what needs the person.
    private static let welcomeLifetime: Duration = .seconds(5 * 60)

    /// The last time the person looked at Anchor. Persisted so a relaunch does
    /// not re-announce work they already saw.
    private static let buoySeenKey = "anchor.mac.edge.buoy.seen-at"
    private var buoySeenAt: Date {
        get { UserDefaults.standard.object(forKey: Self.buoySeenKey) as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: Self.buoySeenKey) }
    }

    init(
        model: AnchorSessionModel,
        phoneAnchorState: AnchorPhoneAnchorState,
        summaryBook: SummaryBook? = nil,
        onOpenDetails: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.model = model
        self.phoneAnchorState = phoneAnchorState
        self.summaryBook = summaryBook
        self.onOpenDetails = onOpenDetails
        self.onOpenSettings = onOpenSettings
        if UserDefaults.standard.object(forKey: Self.buoySeenKey) == nil {
            UserDefaults.standard.set(Date.now, forKey: Self.buoySeenKey)
        }
        let soundPlayer = AnchorEdgeSoundPlayer()
        self.soundPlayer = soundPlayer
        presentation = AnchorEdgePresentationModel(playSound: soundPlayer.play)

        controlPanel = AnchorControlPanel(
            contentRect: NSRect(
                x: 0, y: 0,
                width: AnchorEdgeBerth.controlSide,
                height: AnchorEdgeBerth.controlSide
            ),
            // A click on the boat leaves the person's own app in front, so a copied
            // step can be pasted straight into it.
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        effectsPanel = AnchorDecorativePanel(
            contentRect: NSRect(origin: .zero, size: AnchorEdgeBerth.effectsSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanels()
        installContent()
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        model.start()
        reposition()
        effectsPanel.orderFrontRegardless()
        controlPanel.orderFrontRegardless()
        observeModel()
        // Bringing Anchor forward (Dock, window, or the boat) counts as looking.
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.markBuoySeen()
                self?.dismissWelcome()
            }
        }
        // After time away, a small card above the boat catches the person up (M4).
        let awayMonitor = MacAwayMonitor(
            onLeave: { [weak self] in
                self?.dismissWelcome()
                self?.recapTasksAsLeft()
            },
            onReturn: { [weak self] awaySince in self?.welcomeBack(awaySince: awaySince) }
        )
        self.awayMonitor = awayMonitor
        awayMonitor.start()
        Task { await MacNotificationSettings.removeRetiredDecisionNotifications() }
    }

    func stop() {
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        activationObserver = nil
        awayMonitor?.stop()
        awayMonitor = nil
        recapTask?.cancel()
        recapTask = nil
        dismissWelcome()
        closeMenu(animated: false)
        soundPlayer.stop()
        controlPanel.orderOut(nil)
        effectsPanel.orderOut(nil)
    }

    func reposition() {
        guard let screen = targetScreen() else { return }
        closeMenu(animated: false)
        place(control: berth(in: screen.visibleFrame))
        effectsPanel.orderFrontRegardless()
        controlPanel.orderFrontRegardless()
        positionWelcome()
    }

    private func berth(in visible: CGRect) -> CGRect {
        dock.controlFrame(in: visible, controlSide: AnchorEdgeBerth.controlSide,
                          columnHeight: AnchorEdgeBerth.effectsSize.height)
    }

    /// The boat, and its short water column under it, against its edge.
    private func place(control: CGRect) {
        presentation.side = dock.side
        controlPanel.setFrame(control, display: true)
        let effects = AnchorEdgeBerth.effectsSize
        effectsPanel.setFrame(
            NSRect(
                x: dock.side == .leading ? control.minX : control.maxX - effects.width,
                y: control.maxY - effects.height,
                width: effects.width,
                height: effects.height
            ),
            display: true
        )
    }

    // MARK: Moving the boat

    /// The boat follows the pointer, then settles on the nearer side, like the
    /// iPhone's floating ball. The rope waits at the berth until it settles.
    private func handleDrag(_ phase: AnchorEdgeDragPhase) {
        switch phase {
        case .began:
            closeMenu(animated: false)
            dismissWelcome()
            drag = (NSEvent.mouseLocation, controlPanel.frame.origin)
            effectsPanel.orderOut(nil)
        case .moved:
            guard let drag else { return }
            let mouse = NSEvent.mouseLocation
            controlPanel.setFrameOrigin(NSPoint(x: drag.origin.x + mouse.x - drag.mouse.x,
                                                y: drag.origin.y + mouse.y - drag.mouse.y))
        case .ended:
            guard drag != nil else { return }
            drag = nil
            let frame = controlPanel.frame
            let center = CGPoint(x: frame.midX, y: frame.midY)
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? targetScreen() else {
                return
            }
            dock = AnchorEdgeDock.nearest(to: frame, in: screen.visibleFrame,
                                          columnHeight: AnchorEdgeBerth.effectsSize.height)
            dock.save(to: .standard)
            let target = berth(in: screen.visibleFrame)
            presentation.side = dock.side
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reducesMotion ? 0 : 0.28
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
                controlPanel.animator().setFrame(target, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.drag == nil else { return }
                    self.place(control: target)
                    self.effectsPanel.orderFrontRegardless()
                    self.controlPanel.orderFrontRegardless()
                }
            }
        }
    }

    private var reducesMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || UserDefaults.standard.bool(forKey: AnchorMotion.reduceMotionDefaultsKey)
    }

    // MARK: The buttons around the boat

    private func toggleMenu() {
        if menuPanel == nil { openMenu() } else { closeMenu(animated: true) }
    }

    private func openMenu() {
        guard let screen = targetScreen() else { return }
        dismissWelcome()
        markBuoySeen()
        let visible = screen.visibleFrame
        let control = controlPanel.frame
        let size = AnchorEdgeMenuLayout.size
        let x = dock.side == .leading ? control.minX : control.maxX - size.width
        let y = min(max(control.midY - size.height / 2, visible.minY), visible.maxY - size.height)
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        let menu = AnchorEdgeMenu(projection: model.projection)

        let panel = AnchorWelcomePanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                       backing: .buffered, defer: false)
        configureFloating(panel)
        panel.hasShadow = false
        panel.onCancel = { [weak self] in self?.closeMenu(animated: true) }
        let view = AnchorEdgeMenuView(menu: menu, side: dock.side, boatY: frame.maxY - control.midY) { [weak self] in
            self?.perform($0, menu: menu)
        }
        let host = NSHostingController(rootView: view.environment(\.locale, AnchorStrings.interfaceLocale))
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = host
        panel.setFrame(frame, display: true)
        menuPanel = panel
        panel.orderFrontRegardless()
        // The boat stays on top, so a second click on it closes the buttons.
        controlPanel.orderFrontRegardless()
        // Key without activating Anchor, so Esc closes it and the person's app stays in front.
        panel.makeKey()
        presentation.menuPresenceChanged(true)

        // A click anywhere else puts the buttons away.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: {
            [weak self] _ in MainActor.assumeIsolated { self?.closeMenu(animated: true) }
        }) {
            menuMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: {
            [weak self] event in
            MainActor.assumeIsolated {
                if let self, event.window !== self.menuPanel, event.window !== self.controlPanel {
                    self.closeMenu(animated: true)
                }
            }
            return event
        }) {
            menuMonitors.append(local)
        }
    }

    private func closeMenu(animated: Bool) {
        menuCloseTask?.cancel()
        menuCloseTask = nil
        menuMonitors.forEach(NSEvent.removeMonitor)
        menuMonitors = []
        guard let panel = menuPanel else { return }
        menuPanel = nil
        presentation.menuPresenceChanged(false)
        guard animated, !reducesMotion else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func perform(_ action: AnchorEdgeAction, menu: AnchorEdgeMenu) {
        switch action {
        case .copyNextStep:
            guard let prompt = menu.prompt else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
            // Long enough to see "Copied", then out of the way of the paste.
            menuCloseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { return }
                self?.closeMenu(animated: true)
            }
        case .switchTask:
            popUp(menu.rows.map { row in
                let item = AnchorMenuAction.item(row.task.goal.title) { [weak self] in
                    self?.perform(.selectTask(row.id), menu: menu)
                }
                item.state = row.id == menu.current?.id ? .on : .off
                return item
            })
        case .catchUp:
            closeMenu(animated: true)
            catchUp()
        case .more:
            popUp([
                AnchorMenuAction.item(EdgeMenuCopy.openWindow) { [weak self] in
                    self?.closeMenu(animated: false)
                    self?.onOpenDetails()
                },
                AnchorMenuAction.item(EdgeMenuCopy.settings) { [weak self] in
                    self?.closeMenu(animated: false)
                    self?.onOpenSettings()
                },
                .separator(),
                AnchorMenuAction.item(EdgeMenuCopy.quit) { NSApp.terminate(nil) },
            ])
        case let .selectTask(id):
            closeMenu(animated: true)
            Task { _ = await model.selectHostedTask(id) }
        }
    }

    /// A short native menu at the pointer, for choices longer than a button.
    private func popUp(_ items: [NSMenuItem]) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        items.forEach(menu.addItem)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// Opens a task in the main window and makes it the one the person is on.
    func openTask(_ id: UUID) {
        dismissWelcome()
        Task { [weak self] in
            guard let self else { return }
            _ = await self.model.selectHostedTask(id)
            self.markBuoySeen()
            self.onOpenDetails()
        }
    }

    // MARK: Welcome back

    /// Writes down where each task stands as the person leaves; a model may
    /// take a while, and they are away for minutes at least.
    private func recapTasksAsLeft() {
        recapTask?.cancel()
        leaveRecaps = [:]
        guard let summaryBook else { return }
        let tasks = model.projection.hostedSessions
        recapTask = Task { [weak self] in
            let recaps = await summaryBook.leaveRecaps(for: tasks)
            guard !Task.isCancelled else { return }
            self?.leaveRecaps = recaps
        }
    }

    private func welcomeBack(awaySince: Date) {
        lastAway = (awaySince, leaveRecaps)
        // A recap belongs to one time away.
        let recaps = leaveRecaps
        leaveRecaps = [:]
        presentWelcome(awaySince: awaySince, recaps: recaps)
    }

    /// The welcome back on request: since the last time away, or today.
    private func catchUp() {
        presentWelcome(awaySince: lastAway?.since ?? Calendar.current.startOfDay(for: .now),
                       recaps: lastAway?.recaps ?? [:])
    }

    private func presentWelcome(awaySince: Date, recaps: [UUID: String]) {
        let welcome = MacWelcomeBack(
            tasks: model.projection.hostedSessions,
            currentID: model.projection.session?.id,
            awaySince: awaySince,
            returnedAt: .now,
            recaps: recaps
        )
        // With no open task there is nothing to catch up on.
        guard !welcome.isEmpty else { return }
        dismissWelcome()

        let panel = AnchorWelcomePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configureFloating(panel)
        panel.onCancel = { [weak self] in self?.dismissWelcome() }

        let card = MacWelcomeBackCard(
            welcome: welcome,
            onOpen: { [weak self] id in self?.openTask(id) },
            onDismiss: { [weak self] in self?.dismissWelcome() }
        )
        let host = NSHostingController(
            rootView: card.environment(\.locale, AnchorStrings.interfaceLocale)
        )
        host.view.wantsLayer = true
        host.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = host
        panel.setContentSize(host.view.fittingSize)
        welcomePanel = panel
        positionWelcome()

        let reduceMotion = reducesMotion
        panel.alphaValue = reduceMotion ? 1 : 0
        panel.orderFrontRegardless()
        if !reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }
        welcomeTimeout = Task { [weak self] in
            try? await Task.sleep(for: Self.welcomeLifetime)
            guard !Task.isCancelled else { return }
            self?.dismissWelcome()
        }
    }

    /// Above the boat on its side of the screen, or below it when the boat sits
    /// high, so the card never covers it.
    private func positionWelcome() {
        guard let welcomePanel, let screen = targetScreen() else { return }
        let visible = screen.visibleFrame
        let control = controlPanel.frame
        let size = welcomePanel.frame.size
        let x = dock.side == .leading ? visible.minX + 16 : visible.maxX - size.width - 16
        let above = control.maxY + 8
        let y = above + size.height <= visible.maxY ? above : max(visible.minY, control.minY - size.height - 8)
        welcomePanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// A small panel that floats over every Space without taking Anchor's focus.
    private func configureFloating(_ panel: NSPanel) {
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }

    private func dismissWelcome() {
        welcomeTimeout?.cancel()
        welcomeTimeout = nil
        welcomePanel?.orderOut(nil)
        welcomePanel = nil
    }

    private func configurePanels() {
        for panel in [controlPanel, effectsPanel] {
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .floating
            panel.hidesOnDeactivate = false
            panel.isMovable = false
            panel.isReleasedWhenClosed = false
            panel.isExcludedFromWindowsMenu = true
            panel.animationBehavior = .none
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
            ]
        }

        controlPanel.becomesKeyOnlyIfNeeded = true
        controlPanel.worksWhenModal = true
        controlPanel.setAccessibilityElement(true)
        controlPanel.setAccessibilityRole(.window)
        controlPanel.setAccessibilityLabel("Anchor")
        effectsPanel.ignoresMouseEvents = true
    }

    private func installContent() {
        let controlView = AnchorEdgeControlView(
            presentation: presentation,
            onActivate: { [weak self] in self?.toggleMenu() },
            onDrag: { [weak self] in self?.handleDrag($0) }
        )
        let controlHost = NSHostingController(rootView: controlView)
        controlHost.view.wantsLayer = true
        controlHost.view.layer?.backgroundColor = NSColor.clear.cgColor
        controlPanel.contentViewController = controlHost

        let effectsHost = NSHostingController(
            rootView: AnchorEdgeEffectsView(presentation: presentation)
        )
        effectsHost.view.wantsLayer = true
        effectsHost.view.layer?.backgroundColor = NSColor.clear.cgColor
        effectsPanel.contentViewController = effectsHost
    }

    private func observeModel() {
        // The edge follows whether any phone anchor is down, not the foreground task,
        // so switching or viewing tasks on either device leaves it still.
        let snapshot = withObservationTracking {
            (
                phoneAnchorState.anchoredSessionIDs(in: model.projection),
                model.isLoading,
                model.projection.hostedSessions
            )
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }

        presentation.synchronize(
            anchoredSessionIDs: snapshot.0,
            isLoading: snapshot.1,
            // Match the views: either the system or the app setting reduces motion.
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                || UserDefaults.standard.bool(forKey: AnchorMotion.reduceMotionDefaultsKey)
        )
        latestHostedSessions = snapshot.2
        presentation.showBuoy(EdgeBuoy.needsYou(in: snapshot.2, since: buoySeenAt))
    }

    private var latestHostedSessions: [AnchorSession] = []

    private func markBuoySeen() {
        buoySeenAt = .now
        presentation.showBuoy(EdgeBuoy.needsYou(in: latestHostedSessions, since: buoySeenAt))
    }

    private func targetScreen() -> NSScreen? {
        if let screen = controlPanel.screen {
            return screen
        }

        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

/// Menu items that run a closure, for menus built in code.
private final class AnchorMenuAction: NSObject {
    /// Items hold their target weakly; one shared target outlives every menu.
    static let shared = AnchorMenuAction()

    static func item(_ title: String, run: @escaping () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(perform(_:)), keyEquivalent: "")
        item.target = shared
        item.representedObject = run
        return item
    }

    @objc private func perform(_ item: NSMenuItem) {
        (item.representedObject as? () -> Void)?()
    }
}
