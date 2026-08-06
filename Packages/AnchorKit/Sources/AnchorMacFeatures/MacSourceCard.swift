#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSourceCard: View {
    let source: MacSourceGroup
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            AnchorCard(tint: AnchorPalette.source(source.sourceTone)) {
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    HStack(alignment: .top, spacing: AnchorSpacing.small) {
                        SourceMark(
                            symbol: source.sourceSymbol,
                            tone: source.sourceTone,
                            size: 46
                        )

                        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                            Text(source.sourceName)
                                .font(.headline)
                                .foregroundStyle(AnchorPalette.ink)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            Text(L10n.processCount(source.processes.count))
                                .font(.caption)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }

                        Spacer(minLength: AnchorSpacing.small)

                        Image(systemName: "chevron.right")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: AnchorSpacing.small) {
                        StatusBadge(status: source.status, text: L10n.status(source.status))
                        Spacer(minLength: AnchorSpacing.small)
                        Text(source.lastUpdated, style: .relative)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .lineLimit(1)
                    }

                    sourceProgress

                    if let estimatedCompletion = source.estimatedCompletion {
                        Label {
                            Text(estimatedCompletion)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    }

                    if let latestEvent = source.latestEvent {
                        Divider()
                        Label(latestEvent.title, systemImage: sourceEventSymbol(latestEvent.kind))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: dynamicTypeSize.isAccessibilitySize ? 274 : 210,
                    alignment: .topLeading
                )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(source.sourceName)
        .accessibilityValue(source.accessibilityValue)
        .accessibilityHint(L10n.openSourceDetails)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("mac.sources.card")
    }

    @ViewBuilder
    private var sourceProgress: some View {
        if let progress = source.progress {
            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                HStack {
                    Label(L10n.sourceProgress, systemImage: "chart.bar.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Spacer(minLength: AnchorSpacing.small)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(AnchorPalette.sourceInk(source.sourceTone))
                }
                ProgressView(value: progress, total: 1)
                    .tint(AnchorPalette.source(source.sourceTone))
                    .accessibilityLabel(L10n.sourceProgress)
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            }
        } else {
            Label(L10n.unknown, systemImage: "minus")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func sourceEventSymbol(_ kind: ProcessEventKind) -> String {
        switch kind {
        case .created: "plus"
        case .progress: "arrow.up.right"
        case .outputReady: "sparkles"
        case .decisionRequired: "exclamationmark.bubble.fill"
        case .decisionResolved: "checkmark.bubble.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .note: "bookmark.fill"
        case .presence: "person.wave.2.fill"
        case .connection: "network"
        }
    }
}
#endif
