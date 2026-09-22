#if os(iOS)
import AnchorDesign
import SwiftUI

/// Gives each process group an explicit semantic heading and count.
struct WorkspaceProcessSectionHeader: View {
    let title: String
    let detail: String?
    let count: Int
    let identifier: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .accessibilityAddTraits(.isHeader)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: AnchorSpacing.small)
            Text(L10n.processCount(count))
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.secondaryText)
        }
        .padding(.top, AnchorSpacing.small)
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}
#endif
