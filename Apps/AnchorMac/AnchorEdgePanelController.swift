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
    private let soundPlayer: AnchorEdgeSoundPlayer

    private let controlPanel: AnchorControlPanel
    private let effectsPanel: AnchorDecorativePanel
    private var isStarted = false
    private var activationObserver: NSObjectProtocol?
    private var awayMonitor: MacAwayMonitor?
    private var welcomePanel: AnchorWelcomePanel?
    private var welcomeTimeout: Task<Void, Never>?
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
        onOpenDetails: @escaping () -> Void
    ) {
        self.model = model
        self.phoneAnchorState = phoneAnchorState
        self.onOpenDetails = onOpenDetails
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
            styleMask: [.borderless],
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
            onLeave: { [weak self] in self?.dismissWelcome() },
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
        dismissWelcome()
        soundPlayer.stop()
        controlPanel.orderOut(nil)
        effectsPanel.orderOut(nil)
    }

    func reposition() {
        guard let screen = targetScreen() else { return }
        let visibleFrame = screen.visibleFrame
        let side = AnchorEdgeBerth.controlSide
        let effects = AnchorEdgeBerth.effectsSize
        // The boat berths in the lower-right corner, away from toolbar controls. Its
        // short water column ends just above the Dock, so a dropped anchor sinks a
        // fixed distance below the boat instead of crossing the whole screen.
        let berthTop = visibleFrame.minY + effects.height
        controlPanel.setFrame(
            NSRect(x: visibleFrame.maxX - side, y: berthTop - side, width: side, height: side),
            display: true
        )
        effectsPanel.setFrame(
            NSRect(
                x: visibleFrame.maxX - effects.width,
                y: berthTop - effects.height,
                width: effects.width,
                height: effects.height
            ),
            display: true
        )
        effectsPanel.orderFrontRegardless()
        controlPanel.orderFrontRegardless()
        positionWelcome()
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

    private func welcomeBack(awaySince: Date) {
        let welcome = MacWelcomeBack(
            tasks: model.projection.hostedSessions,
            currentID: model.projection.session?.id,
            awaySince: awaySince,
            returnedAt: .now
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

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || UserDefaults.standard.bool(forKey: AnchorMotion.reduceMotionDefaultsKey)
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

    /// Above the boat, right-aligned with it, so the card never covers it.
    private func positionWelcome() {
        guard let welcomePanel, let screen = targetScreen() else { return }
        let visibleFrame = screen.visibleFrame
        let berthTop = visibleFrame.minY + AnchorEdgeBerth.effectsSize.height
        let size = welcomePanel.frame.size
        welcomePanel.setFrameOrigin(NSPoint(x: visibleFrame.maxX - size.width - 16, y: berthTop + 8))
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
            onOpenDetails: { [weak self] in
                self?.markBuoySeen()
                self?.onOpenDetails()
            }
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
