#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacEventStrip: View {
    let events: [ProcessEvent]
    let processes: [AnchorProcess]
    let onOpenTimeline: () -> Void

    private var processesByID: [UUID: AnchorProcess] {
        Dictionary(uniqueKeysWithValues: processes.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(L10n.activityLog)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AnchorPalette.deepSea)
                        .textCase(.uppercase)
                    Text(L10n.recentActivity)
                        .font(.title2.bold())
                }
                Spacer()
                Button(L10n.timeline, systemImage: "waveform.path.ecg", action: onOpenTimeline)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("mac.timeline.open")
            }

            if events.isEmpty {
                ContentUnavailableView(L10n.noEvents, systemImage: "waveform.path.ecg", description: nil)
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 18, style: .continuous))
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                        ForEach(events) { event in
                            MacEventCard(
                                event: event,
                                process: event.processID.flatMap { processesByID[$0] }
                            )
                            .frame(width: 250, alignment: .topLeading)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct MacEventCard: View {
    let event: ProcessEvent
    let process: AnchorProcess?

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack {
                Image(systemName: eventSymbol(event.kind))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(eventTint(event.kind))
                    .frame(width: 30, height: 30)
                    .background(eventTint(event.kind).opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                Spacer()
                Text(event.occurredAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: AnchorSpacing.xSmall) {
                if let process {
                    SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 22)
                    Text(process.sourceName)
                        .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                } else {
                    Image(systemName: "scope")
                        .foregroundStyle(AnchorPalette.deepSea)
                    Text(L10n.appName)
                        .foregroundStyle(AnchorPalette.deepSea)
                }
            }
            .font(.caption.weight(.semibold))
            Text(event.title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(3)
            if !event.detail.isEmpty {
                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(3)
            }
        }
        .padding(AnchorSpacing.medium)
        .frame(minHeight: 156, alignment: .topLeading)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
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
        case .created, .progress, .note: AnchorPalette.deepSea
        }
    }
}
#endif
