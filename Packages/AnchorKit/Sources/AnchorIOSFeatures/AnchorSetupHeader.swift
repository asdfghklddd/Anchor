#if os(iOS)
import AnchorDesign
import SwiftUI

struct AnchorSetupHeader: View {
    let reviewing: Bool
    let canGoBack: Bool
    let back: () -> Void
    let close: () -> Void
    @ScaledMetric(relativeTo: .title) private var inputTitleSize: CGFloat = 28
    @ScaledMetric(relativeTo: .title3) private var reviewTitleSize: CGFloat = 20
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 16

    var body: some View {
        VStack(spacing: 0) {
            HarborAnchorGlyph(color: AnchorSetupStyle.accent, lineWidth: 2)
                .frame(width: reviewing ? 32 : 40, height: reviewing ? 36 : 40)
                // Compensate for the shared glyph’s internal Canvas inset.
                .scaleEffect(reviewing ? 1.15 : 1.2)
                .accessibilityHidden(true)
            Text(SetupCopy.title)
                .font(.system(size: reviewing ? reviewTitleSize : inputTitleSize, weight: .heavy))
                .foregroundStyle(AnchorSetupStyle.heading)
                .frame(minHeight: reviewing ? 28 : 39)
                .padding(.top, reviewing ? 6 : 13)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("setup.screen")
            Text(reviewing ? SetupCopy.reviewSubtitle : SetupCopy.subtitle)
                .font(reviewing ? .caption : .system(size: subtitleSize, weight: .medium))
                .foregroundStyle(AnchorSetupStyle.secondary)
                .frame(minHeight: reviewing ? 18 : 22)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, reviewing ? 12 : 36)
        .padding(.bottom, reviewing ? 16 : 29)
        .overlay(alignment: .top) {
            HStack {
                if canGoBack {
                    Button(action: back) {
                        Image(systemName: "chevron.left").font(.subheadline)
                            .frame(width: 28, height: 28)
                            .background(AnchorSetupStyle.controlSurface, in: .circle)
                            .frame(width: 44, height: 44).contentShape(.rect)
                    }
                    .accessibilityLabel(SetupCopy.back)
                    .accessibilityIdentifier("setup.back.button")
                }
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark").font(.system(.subheadline, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(AnchorSetupStyle.controlSurface, in: .circle)
                        .frame(width: 44, height: 44).contentShape(.rect)
                }
                .accessibilityLabel(L10n.close)
                .accessibilityIdentifier("setup.close.button")
            }
            .foregroundStyle(AnchorSetupStyle.ink)
            .buttonStyle(.plain)
            .padding(.top, 14)
        }
    }
}
#endif
