#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacProcessDetailHeader: View {
    let process: AnchorProcess

    var body: some View {
        AnchorCard(tint: AnchorPalette.source(process.sourceTone)) {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                    SourceMark(
                        symbol: process.sourceSymbol,
                        tone: process.sourceTone,
                        size: 52
                    )
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        Text(process.sourceName)
                            .font(.caption.bold())
                            .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                        Text(process.title)
                            .font(.title2.bold())
                            .foregroundStyle(AnchorPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(process.detail)
                            .font(.callout)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: AnchorSpacing.medium)
                    StatusBadge(
                        status: process.status,
                        text: L10n.compactProcessStatus(process),
                        interrupted: process.isInterrupted
                    )
                }

                if let progress = process.progress {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        HStack {
                            Text(L10n.taskProgress)
                                .font(.callout.bold())
                            Spacer(minLength: AnchorSpacing.small)
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .font(.callout.bold().monospacedDigit())
                        }
                        ProgressView(value: progress, total: 1)
                            .tint(AnchorPalette.source(process.sourceTone))
                            .accessibilityLabel(L10n.taskProgress)
                            .accessibilityValue(
                                Text(progress, format: .percent.precision(.fractionLength(0)))
                            )
                    }
                }
            }
        }
    }
}
#endif
