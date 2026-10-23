#if os(iOS)
import AnchorDesign
import SwiftUI

/// Close on the left and the title in the middle; the drop itself is the
/// slider under the plan, where the hand already is.
struct AnchorSetupHeader: View {
    let close: () -> Void

    @ScaledMetric(relativeTo: .title2) private var figureSize: CGFloat = 26

    var body: some View {
        HStack(spacing: 8) {
            Button(action: close) {
                Image(systemName: "xmark").font(.system(.subheadline, weight: .medium))
                    .frame(width: 32, height: 32)
                    .background(AnchorSetupStyle.controlSurface, in: .circle)
                    .frame(width: 44, height: 44).contentShape(.rect)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AnchorSetupStyle.ink)
            .accessibilityLabel(L10n.close)
            .accessibilityIdentifier("setup.close.button")
            Spacer(minLength: 4)
            HStack(spacing: 8) {
                AnchorFigure(color: AnchorSetupStyle.accent, depth: true)
                    .frame(width: figureSize, height: figureSize)
                    .accessibilityHidden(true)
                Text(SetupCopy.title)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(AnchorSetupStyle.heading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("setup.screen")
            }
            Spacer(minLength: 4)
            // Balances the close button so the title stays centered.
            Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}
#endif
