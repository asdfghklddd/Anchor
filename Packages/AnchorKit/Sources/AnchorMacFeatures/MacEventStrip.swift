#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Recent events as compact rows; the surrounding card owns the heading and timeline link.
struct MacEventStrip: View {
    let events: [ProcessEvent]
    let processes: [AnchorProcess]

    private var processesByID: [UUID: AnchorProcess] {
        Dictionary(processes.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }

    var body: some View {
        if events.isEmpty {
            Label(L10n.noEvents, systemImage: "waveform.path.ecg")
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .padding(.horizontal, MacMetrics.cardPadding)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 0) {
                ForEach(events) { event in
                    Divider().padding(.leading, MacMetrics.cardPadding + 36)
                    MacEventRow(
                        event: event,
                        process: event.processID.flatMap { processesByID[$0] }
                    )
                }
            }
            .padding(.bottom, 4)
        }
    }
}

private struct MacEventRow: View {
    let event: ProcessEvent
    let process: AnchorProcess?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: eventSymbol(event.kind))
                .font(.caption.weight(.bold))
                .foregroundStyle(eventTint(event.kind))
                .frame(width: 24, height: 24)
                .background(eventTint(event.kind).opacity(0.14), in: .circle)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(process?.sourceName ?? L10n.appName)
                        .foregroundStyle(process.map { AnchorPalette.sourceInk($0.sourceTone) } ?? AnchorPalette.brandDeep)
                    if !event.detail.isEmpty {
                        Text("·")
                        Text(event.detail).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
            }
            Spacer(minLength: AnchorSpacing.small)
            Text(event.occurredAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                .font(.caption.monospacedDigit())
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(1)
        }
        .padding(.horizontal, MacMetrics.cardPadding)
        .padding(.vertical, 8)
        .help([event.title, event.detail].filter { !$0.isEmpty }.joined(separator: "\n"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let sourceName = process?.sourceName ?? L10n.appName
        let time = event.occurredAt.formatted(date: .omitted, time: .shortened)
        return [sourceName, event.title, event.detail, time]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func eventSymbol(_ kind: ProcessEventKind) -> String {
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

    private func eventTint(_ kind: ProcessEventKind) -> Color {
        switch kind {
        case .decisionRequired, .failed: AnchorPalette.coral
        case .completed, .decisionResolved: AnchorPalette.seafoam
        case .outputReady: AnchorPalette.periwinkle
        case .presence, .connection: AnchorPalette.cyan
        case .created, .progress, .note: AnchorPalette.deepSeaInk
        }
    }
}
#endif
