#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorEdgeControlView: View {
    private let presentation: AnchorEdgePresentationModel
    private let onActivate: () -> Void
    private let onDrag: (AnchorEdgeDragPhase) -> Void

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var isKeyboardFocused: Bool
    @State private var isHovering = false
    @State private var hoverBias: CGFloat = 0
    @State private var hoverStartedAt = Date.now
    /// A press that moved the boat is a drag, not a click.
    @State private var isDragging = false

    public init(
        presentation: AnchorEdgePresentationModel,
        onActivate: @escaping () -> Void,
        onDrag: @escaping (AnchorEdgeDragPhase) -> Void
    ) {
        self.presentation = presentation
        self.onActivate = onActivate
        self.onDrag = onDrag
    }

    public var body: some View {
        let side = presentation.side
        Button(action: activate) {
            ZStack {
                // The border that makes the boat a floating button, like the iPhone's ball.
                Circle()
                    .fill(.thinMaterial)
                    .overlay {
                        Circle().strokeBorder(.white.opacity(contrast == .increased ? 1 : 0.85), lineWidth: 1.5)
                    }
                    .overlay {
                        Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5).padding(-0.5)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 2)
                    .frame(width: 78, height: 78)
                AnchorEdgeBoatControl(
                    isWorking: presentation.phase.isWorking,
                    isHovering: isHovering,
                    hoverBias: hoverBias,
                    hoverStartedAt: hoverStartedAt,
                    anchorTravel: presentation.anchorTravel
                )
                // The rope leaves from the stern, which faces the screen edge.
                .scaleEffect(x: side == .leading ? -1 : 1)
            }
                .frame(width: 80, height: 80)
                .contentShape(.circle)
                .modifier(AnchorBoatSailingModifier(
                    progress: presentation.isTucked ? 1 : 0,
                    side: side,
                    reduceMotion: reduceMotion,
                    restingOpacity: contrast == .increased ? 0.78 : 0.60
                ))
                .animation(
                    reduceMotion ? .easeOut(duration: 0.20)
                        : (presentation.isTucked ? AnchorMotion.boatDeparture : AnchorMotion.edgeRest),
                    value: presentation.isTucked
                )
        }
        .buttonStyle(AnchorPressButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { _ in
                    if !isDragging {
                        isDragging = true
                        onDrag(.began)
                    }
                    onDrag(.moved)
                }
                .onEnded { _ in
                    onDrag(.ended)
                    // The click that ends a drag arrives first or not at all; either way it is spent.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        isDragging = false
                    }
                }
        )
        .overlay(alignment: side == .leading ? .topTrailing : .topLeading) {
            // The buoy floats toward the screen, outside the boat's sailing
            // motion, so it stays readable while the boat rests at the edge.
            if let buoy = presentation.buoy {
                AnchorEdgeBuoyView(buoy: buoy, reduceMotion: reduceMotion)
                    .padding(side == .leading ? .trailing : .leading, 2)
                    .padding(.top, 10)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .focused($isKeyboardFocused)
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: presentation.phase)
        .frame(width: 88, height: 88)
        .contentShape(.rect)
        .onContinuousHover(perform: updateHover)
        .onChange(of: isKeyboardFocused) { _, isFocused in
            presentation.keyboardFocusChanged(isFocused)
        }
        .onAppear(perform: presentation.scheduleTuck)
        // [VERIFY] The boat opens the same Anchor workspace in idle and working states.
        .accessibilityLabel(L10n.appName)
        .accessibilityValue(accessibilityState)
        .accessibilityHint(EdgeMenuCopy.boatHint)
        .accessibilityInputLabels([L10n.appName, L10n.openDetails])
        .accessibilityIdentifier("mac.edge.entry")
        .help(presentation.buoy.map(L10n.edgeBuoy) ?? EdgeMenuCopy.boatHint)
    }

    private var accessibilityState: String {
        let state = presentation.phase.isWorking ? L10n.currentWork : L10n.emptyTitle
        guard let buoy = presentation.buoy else { return state }
        return state + ", " + L10n.edgeBuoy(buoy)
    }

    private func activate() {
        guard !isDragging else {
            isDragging = false
            return
        }
        hoverBias = 0
        presentation.controlActivated()
        onActivate()
    }

    private func updateHover(_ phase: HoverPhase) {
        switch phase {
        case let .active(location):
            if !isHovering {
                hoverStartedAt = .now
                isHovering = true
                presentation.pointerPresenceChanged(true)
            }
            hoverBias = min(1, max(-1, (location.x - 36) / 36))
        case .ended:
            isHovering = false
            hoverBias = 0
            presentation.pointerPresenceChanged(false)
        }
    }
}

/// Where a drag of the boat is; the panel follows the pointer itself.
public enum AnchorEdgeDragPhase: Sendable {
    case began
    case moved
    case ended
}
#endif
