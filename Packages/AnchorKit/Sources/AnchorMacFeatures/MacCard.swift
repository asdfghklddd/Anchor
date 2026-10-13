#if os(macOS)
import AnchorDesign
import SwiftUI

/// The Mac workspace's one card: a titled surface whose header row always sits in
/// the same place, so every block on the page scans the same way.
struct MacCard<Accessory: View, Content: View>: View {
    private let title: String?
    private let symbol: String?
    private let tint: Color?
    private let insetContent: Bool
    private let accessory: Accessory
    private let content: Content

    init(
        _ title: String? = nil,
        symbol: String? = nil,
        tint: Color? = nil,
        insetContent: Bool = true,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.insetContent = insetContent
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MacMetrics.cardSpacing) {
            if let title {
                HStack(alignment: .center, spacing: AnchorSpacing.small) {
                    MacCardTitle(title, symbol: symbol)
                    Spacer(minLength: AnchorSpacing.small)
                    accessory
                }
                .padding(.horizontal, MacMetrics.cardPadding)
                .padding(.top, MacMetrics.cardPadding - 2)
            }
            // One stack, so padding wraps the whole body rather than each child.
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(.horizontal, insetContent ? MacMetrics.cardPadding : 0)
                .padding(.top, title == nil && insetContent ? MacMetrics.cardPadding : 0)
                .padding(.bottom, insetContent ? MacMetrics.cardPadding : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(.rect(cornerRadius: MacMetrics.cardRadius, style: .continuous))
        .fluoriteSurface(
            fill: AnchorPalette.fluoriteSurface,
            border: tint?.opacity(0.36) ?? AnchorPalette.fluoriteBorder,
            cornerRadius: MacMetrics.cardRadius
        )
        .overlay(alignment: .leading) {
            // A tinted card marks its state with a slim edge, not a flood of color.
            if let tint {
                Capsule()
                    .fill(tint)
                    .frame(width: 3)
                    .padding(.vertical, MacMetrics.cardPadding)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct MacCardTitle: View {
    private let title: String
    private let symbol: String?

    init(_ title: String, symbol: String? = nil) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.interaction)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AnchorPalette.brandDeep)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// One glanceable number with its label, tinted only when it asks for a look.
struct MacStatTile: View {
    let value: String
    let label: String
    var symbol: String
    var tint: Color = AnchorPalette.interaction
    var emphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(emphasized ? tint : AnchorPalette.secondaryInk)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(emphasized ? tint : AnchorPalette.ink)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 84, alignment: .leading)
        .background(
            (emphasized ? tint.opacity(0.12) : AnchorPalette.softBlue.opacity(0.22)),
            in: .rect(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

enum MacMetrics {
    static let pageSpacing: CGFloat = 14
    static let pageInset: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let contentWidth: CGFloat = 1120
}
#endif
