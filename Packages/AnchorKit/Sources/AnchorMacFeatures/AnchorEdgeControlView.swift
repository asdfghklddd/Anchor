#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorEdgeControlView: View {
    private let presentation: AnchorEdgePresentationModel
    private let onOpenDetails: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var isKeyboardFocused: Bool
    @State private var isHovering = false
    @State private var hoverBias: CGFloat = 0
    @State private var hoverStartedAt = Date.now

    public init(
        presentation: AnchorEdgePresentationModel,
        onOpenDetails: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.onOpenDetails = onOpenDetails
    }

    public var body: some View {
        Button(action: openDetails) {
            AnchorEdgeBoatControl(
                isWorking: presentation.phase.isWorking,
                isHovering: isHovering,
                hoverBias: hoverBias,
                hoverStartedAt: hoverStartedAt,
                anchorTravel: presentation.anchorTravel
            )
                .frame(width: 72, height: 72)
                .contentShape(.rect)
                .modifier(AnchorBoatSailingModifier(
                    progress: presentation.isTucked ? 1 : 0,
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
        .overlay(alignment: .topLeading) {
            // The buoy floats toward the screen, outside the boat's sailing
            // motion, so it stays readable while the boat rests at the edge.
            if let buoy = presentation.buoy {
                AnchorEdgeBuoyView(buoy: buoy, reduceMotion: reduceMotion)
                    .padding(.leading, 6)
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
        .accessibilityLabel(L10n.openDetails)
        .accessibilityValue(accessibilityState)
        .accessibilityInputLabels([L10n.openDetails, L10n.appName])
        .accessibilityIdentifier("mac.edge.entry")
        .help(presentation.buoy.map(L10n.edgeBuoy) ?? L10n.openDetails)
    }

    private var accessibilityState: String {
        let state = presentation.phase.isWorking ? L10n.currentWork : L10n.emptyTitle
        guard let buoy = presentation.buoy else { return state }
        return state + ", " + L10n.edgeBuoy(buoy)
    }

    private func openDetails() {
        isHovering = false
        hoverBias = 0
        presentation.pointerPresenceChanged(false)
        presentation.controlActivated()
        onOpenDetails()
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
#endif
