#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacProcessEventTimeline: View {
    let events: [ProcessEvent]

    private var orderedEvents: [ProcessEvent] {
        events.sorted { $0.occurredAt < $1.occurredAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            Text(L10n.timeline)
                .font(.title2.bold())
                .foregroundStyle(AnchorPalette.ink)

            if orderedEvents.isEmpty {
                ContentUnavailableView(
                    L10n.noEvents,
                    systemImage: "waveform.path.ecg",
                    description: Text(L10n.timelineEmptyDetail)
                )
                .frame(maxWidth: .infinity, minHeight: 220)
                .fluoriteSurface(cornerRadius: 18)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(orderedEvents.enumerated()), id: \.element.id) { index, event in
                        MacProcessEventRow(
                            event: event,
                            showsLineAbove: index > 0,
                            showsLineBelow: index < orderedEvents.count - 1
                        )
                    }
                }
                .padding(AnchorSpacing.large)
                .fluoriteSurface(cornerRadius: 18)
            }
        }
        .accessibilityIdentifier("mac.process.timeline")
    }
}

private struct MacProcessEventRow: View {
    let event: ProcessEvent
    let showsLineAbove: Bool
    let showsLineBelow: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(showsLineAbove ? AnchorPalette.aiBlue.opacity(0.42) : .clear)
                    .frame(width: 2, height: 12)
                Image(systemName: symbol)
                    .font(.caption.bold())
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.14), in: .circle)
                    .overlay {
                        Circle().stroke(tint.opacity(0.36), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
                Rectangle()
                    .fill(showsLineBelow ? AnchorPalette.aiBlue.opacity(0.42) : .clear)
                    .frame(width: 2, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                    Spacer(minLength: AnchorSpacing.small)
                    Text(event.occurredAt, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 9)
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch event.kind {
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

    private var tint: Color {
        switch event.kind {
        case .decisionRequired, .failed: AnchorPalette.sourceInk("coral")
        case .completed, .decisionResolved: AnchorPalette.mintInk
        case .outputReady: AnchorPalette.sourceInk("periwinkle")
        case .presence, .connection: AnchorPalette.sourceInk("cyan")
        case .created, .progress, .note: AnchorPalette.brandDeep
        }
    }
}
#endif
