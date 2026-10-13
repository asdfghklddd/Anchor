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
        Task { await MacNotificationSettings.removeRetiredDecisionNotifications() }
    }

    func stop() {
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
        // The edge follows whether any phone anchor is down, not the foreground task,
        // so switching or viewing tasks on either device leaves it still.
        let snapshot = withObservationTracking {
            (
                phoneAnchorState.anchoredSessionIDs(in: model.projection),
                model.isLoading
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
