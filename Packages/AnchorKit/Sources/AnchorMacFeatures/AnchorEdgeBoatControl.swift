#if os(macOS)
import SwiftUI

struct AnchorEdgeBoatControl: View {
    let isWorking: Bool
    let isHovering: Bool
    let hoverBias: CGFloat
    let hoverStartedAt: Date
    var anchorTravel: CGFloat = 0

    var body: some View {
        // The transparent parent owns the hit area; only the boat is visible.
        AnchorEdgeBoatArtwork(
            isWorking: isWorking, isHovering: isHovering,
            hoverBias: hoverBias, hoverStartedAt: hoverStartedAt,
            anchorTravel: anchorTravel
        )
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}
#endif
