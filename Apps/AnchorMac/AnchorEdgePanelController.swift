import AnchorCore
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
    private let notificationService = MacDecisionNotificationService()
    private let soundPlayer: AnchorEdgeSoundPlayer

    private let controlPanel: AnchorControlPanel
    private let effectsPanel: AnchorDecorativePanel
    private var isStarted = false

    init(
        model: AnchorSessionModel,
        phoneAnchorState: AnchorPhoneAnchorState,
        onOpenDetails: @escaping () -> Void
    ) {
        self.model = model
        self.phoneAnchorState = phoneAnchorState
        self.onOpenDetails = onOpenDetails
        let soundPlayer = AnchorEdgeSoundPlayer()
        self.soundPlayer = soundPlayer
        presentation = AnchorEdgePresentationModel(playSound: soundPlayer.play)

        controlPanel = AnchorControlPanel(
            contentRect: NSRect(x: 0, y: 0, width: 88, height: 88),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        effectsPanel = AnchorDecorativePanel(
            contentRect: NSRect(x: 0, y: 0, width: 112, height: 700),
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
    }

    func stop() {
        soundPlayer.stop()
        controlPanel.orderOut(nil)
        effectsPanel.orderOut(nil)
    }

    func reposition() {
        guard let screen = targetScreen() else { return }
        let visibleFrame = screen.visibleFrame
        controlPanel.setFrame(
            NSRect(
                x: visibleFrame.maxX - 88,
                y: visibleFrame.maxY - 92,
                width: 88,
                height: 88
            ),
            display: true
        )
        effectsPanel.setFrame(
            NSRect(
                x: visibleFrame.maxX - 112,
                // The waterline follows the physical screen edge, including the Dock area.
                y: screen.frame.minY,
                width: 112,
                height: visibleFrame.maxY - screen.frame.minY
            ),
            display: true
        )
        effectsPanel.orderFrontRegardless()
        controlPanel.orderFrontRegardless()
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
            onOpenDetails: onOpenDetails
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
        let snapshot = withObservationTracking {
            (
                phoneAnchorState.activeSessionID(in: model.projection),
                model.projection.session?.status,
                model.isLoading,
                model.projection
            )
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.observeModel()
            }
        }

        let activeSessionID = snapshot.1 == .active ? snapshot.0 : nil
        presentation.synchronize(
            activeSessionID: activeSessionID,
            isLoading: snapshot.2,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        let decisionNotificationsEnabled = UserDefaults.standard.bool(
            forKey: "anchor.mac.notifications.decisions"
        )
        notificationService.observe(
            snapshot.3,
            enabled: decisionNotificationsEnabled
        )
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
