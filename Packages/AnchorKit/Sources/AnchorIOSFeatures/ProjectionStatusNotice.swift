#if os(iOS)
import AnchorDesign
import SwiftUI

struct ProjectionStatusNotice: View {
    let title: String
    let detail: String?
    let freshness: String?
    let symbol: String
    let tint: Color

    var body: some View {
        NavigationLink(value: AnchorRoute.connections) {
            HStack(alignment: .center, spacing: AnchorSpacing.small) {
                Image(systemName: symbol)
                    .font(.body.bold())
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.12), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(AnchorPalette.brandDeep)

                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let freshness {
                        Text(freshness)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryText)
                    }
                }

                Spacer(minLength: AnchorSpacing.xSmall)

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, AnchorSpacing.small)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("status.connection.notice")
    }
}
#endif
