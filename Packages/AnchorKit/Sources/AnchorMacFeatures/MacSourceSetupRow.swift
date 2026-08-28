#if os(macOS)
import AnchorDesign
import SwiftUI

struct MacSourceSetupRow<Actions: View>: View {
    let symbol: String
    let title: String
    let detail: String
    let status: String
    let isReady: Bool
    @ViewBuilder let actions: Actions

    init(
        symbol: String,
        title: String,
        detail: String,
        status: String,
        isReady: Bool,
        @ViewBuilder actions: () -> Actions
    ) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.status = status
        self.isReady = isReady
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AnchorPalette.deepSea)
                    .frame(width: 36, height: 36)
                    .background(AnchorPalette.cyan.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AnchorSpacing.small)
                Label(
                    status,
                    systemImage: isReady ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.caption.bold())
                .foregroundStyle(isReady ? AnchorPalette.mintInk : AnchorPalette.secondaryInk)
            }
            HStack(spacing: AnchorSpacing.small) {
                actions
            }
            .controlSize(.large)
            .padding(.leading, 52)
        }
    }
}

extension MacSourceSetupRow where Actions == EmptyView {
    init(
        symbol: String,
        title: String,
        detail: String,
        status: String,
        isReady: Bool
    ) {
        self.init(
            symbol: symbol,
            title: title,
            detail: detail,
            status: status,
            isReady: isReady
        ) {
            EmptyView()
        }
    }
}
#endif
