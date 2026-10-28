#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import SwiftUI

struct MacTimelineView: View {
    let projection: SessionProjection
    let onOpenSettings: () -> Void

    private var processesByID: [UUID: AnchorProcess] {
        Dictionary(
            uniqueKeysWithValues: (projection.session?.processes ?? []).map { ($0.id, $0) }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AnchorSpacing.small) {
                if let events = projection.session?.timeline, !events.isEmpty {
                    ForEach(events) { event in
                        let process = process(for: event)
                        timelineRow(event, process: process)
                        .padding(.horizontal, MacMetrics.cardPadding)
                        .padding(.vertical, 12)
                        .background(AnchorPalette.fluoriteSurface, in: .rect(cornerRadius: MacMetrics.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: MacMetrics.cardRadius, style: .continuous)
                                .stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(eventAccessibilityLabel(event, process: process))
                    }
                } else {
                    timelineEmptyState
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, MacMetrics.pageInset)
            .padding(.bottom, MacMetrics.pageInset)
        }
        .background(.clear)
        .navigationTitle(L10n.timeline)
        .accessibilityIdentifier("mac.timeline.screen")
    }

    private func timelineRow(_ event: ProcessEvent, process: AnchorProcess?) -> some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            Image(systemName: macEventSymbol(event.kind))
                .font(.body.weight(.semibold))
                .foregroundStyle(process.map { AnchorPalette.sourceInk($0.sourceTone) } ?? AnchorPalette.deepSeaInk)
                .frame(width: 30, height: 30)
                .background(
                    (process.map { AnchorPalette.source($0.sourceTone) } ?? AnchorPalette.cyan).opacity(0.20),
                    in: .circle
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                if let process {
                    HStack(spacing: AnchorSpacing.xSmall) {
                        SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 22)
                        Text(process.sourceName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    }
                } else {
                    Text(L10n.appName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AnchorPalette.brandDeep)
                }

                Text(event.title)
                    .font(.callout.weight(.semibold))
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(event.occurredAt, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            Spacer(minLength: 0)
        }
    }

    private func process(for event: ProcessEvent) -> AnchorProcess? {
        guard let processID = event.processID else { return nil }
        return processesByID[processID]
    }

    private func eventAccessibilityLabel(_ event: ProcessEvent, process: AnchorProcess?) -> String {
        let sourceName = process?.sourceName ?? L10n.appName
        let time = event.occurredAt.formatted(date: .omitted, time: .shortened)
        let parts = [sourceName, event.title, event.detail, time]
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    private var timelineEmptyState: some View {
        VStack(spacing: AnchorSpacing.medium) {
            ContentUnavailableView(
                projection.session == nil ? L10n.emptyTitle : L10n.noEvents,
                systemImage: "waveform.path.ecg",
                description: Text(
                    projection.session == nil
                        ? L10n.emptyDetail
                        : L10n.timelineEmptyDetail
                )
            )

            if projection.session == nil {
                Button(L10n.pairDevice, systemImage: "link", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.interaction)
                    .controlSize(.large)
                    .accessibilityIdentifier("mac.timeline.pair.button")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(.horizontal, AnchorSpacing.large)
        .background(AnchorPalette.fluoriteSurface.opacity(0.72), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("mac.timeline.empty")
    }
}

private func macEventSymbol(_ kind: ProcessEventKind) -> String {
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
#endif
