#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSourceDetailView: View {
    let source: MacSourceGroup
    let connection: ConnectionState
    let dataObservedAt: Date?
    let openDecisions: [Decision]

    @Environment(\.dismiss) private var dismiss

    private var recentEvents: [ProcessEvent] {
        Array(
            source.processes
                .flatMap(\.events)
                .sorted { lhs, rhs in lhs.occurredAt > rhs.occurredAt }
                .prefix(8)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                header
                healthOverview

                if !openDecisions.isEmpty {
                    attentionSection
                }

                processSection
                activitySection
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(AnchorSpacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(HarborBackground())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.close, action: dismiss.callAsFunction)
            }
        }
        .frame(minWidth: 620, idealWidth: 760, minHeight: 560)
        .accessibilityIdentifier("mac.source.detail")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            SourceMark(
                symbol: source.sourceSymbol,
                tone: source.sourceTone,
                size: 58
            )

            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                Text(L10n.sourceDetails)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.deepSea)
                    .textCase(.uppercase)
                Text(source.sourceName)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.processCount(source.processes.count))
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            Spacer(minLength: AnchorSpacing.medium)

            VStack(alignment: .trailing, spacing: AnchorSpacing.small) {
                StatusBadge(status: source.status, text: L10n.status(source.status))
                Label(connectionLabel, systemImage: connectionSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(connectionTint)
            }
        }
    }

    private var healthOverview: some View {
        AnchorCard(tint: AnchorPalette.source(source.sourceTone)) {
            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                HStack {
                    Text(L10n.sourceProgress)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                    Spacer(minLength: AnchorSpacing.small)
                    if let progress = source.progress {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(.headline.bold().monospacedDigit())
                            .foregroundStyle(AnchorPalette.sourceInk(source.sourceTone))
                    } else {
                        Text(L10n.unknown)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }

                if let progress = source.progress {
                    ProgressView(value: progress, total: 1)
                        .tint(AnchorPalette.source(source.sourceTone))
                        .accessibilityLabel(L10n.sourceProgress)
                        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
                }

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 128), spacing: AnchorSpacing.small)],
                    alignment: .leading,
                    spacing: AnchorSpacing.small
                ) {
                    sourceMetric(value: source.runningCount, label: L10n.live, symbol: "play.fill")
                    sourceMetric(value: source.attentionCount, label: L10n.attentionNeeded, symbol: "exclamationmark.bubble")
                    sourceMetric(value: source.completedCount, label: L10n.completed, symbol: "checkmark.circle.fill")
                    sourceMetric(value: source.eventCount, label: L10n.activity, symbol: "waveform.path.ecg")
                }

                if let estimatedCompletion = source.estimatedCompletion {
                    Label {
                        Text(estimatedCompletion)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AnchorPalette.ink)
                    } icon: {
                        Image(systemName: "clock")
                            .foregroundStyle(AnchorPalette.deepSea)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L10n.estimated)
                    .accessibilityValue(estimatedCompletion)
                }

                if let dataObservedAt {
                    Label {
                        Text(dataObservedAt, style: .relative)
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .accessibilityHidden(true)
                    }
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(L10n.lastUpdated)
                }
            }
        }
    }

    private func sourceMetric(value: Int, label: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(value, format: .number)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.ink)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(AnchorPalette.sourceInk(source.sourceTone))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnchorSpacing.small)
        .padding(.vertical, AnchorSpacing.xSmall)
        .background(AnchorPalette.source(source.sourceTone).opacity(0.10), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            Text(L10n.attentionNeeded)
                .font(.title2.bold())
                .foregroundStyle(AnchorPalette.ink)

            AnchorCard(tint: AnchorPalette.sand) {
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    ForEach(openDecisions) { decision in
                        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                            Label(decision.title, systemImage: "exclamationmark.bubble.fill")
                                .font(.headline)
                                .foregroundStyle(AnchorPalette.sourceInk("sand"))
                            Text(decision.prompt)
                                .font(.callout)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            Text(L10n.processes)
                .font(.title2.bold())
                .foregroundStyle(AnchorPalette.ink)

            VStack(spacing: AnchorSpacing.small) {
                ForEach(source.processes) { process in
                    MacSourceProcessRow(process: process)
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            Text(L10n.sourceActivity)
                .font(.title2.bold())
                .foregroundStyle(AnchorPalette.ink)

            if recentEvents.isEmpty {
                ContentUnavailableView(L10n.noEvents, systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity, minHeight: 130)
                    .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 18))
            } else {
                VStack(spacing: AnchorSpacing.small) {
                    ForEach(recentEvents) { event in
                        MacSourceEventRow(event: event)
                    }
                }
            }
        }
    }

    private var connectionLabel: String {
        switch connection {
        case .connected: L10n.connected
        case .pairing: L10n.pairDevice
        case .disconnected: L10n.disconnected
        case .unavailable: L10n.unknown
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        }
    }

    private var connectionSymbol: String {
        switch connection {
        case .connected: "checkmark.circle.fill"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected: "wifi.slash"
        case .unavailable: "questionmark.circle"
        case .permissionDenied: "lock.slash"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionTint: Color {
        switch connection {
        case .connected: AnchorPalette.mintInk
        case .pairing: AnchorPalette.sourceInk("sand")
        case .disconnected, .permissionDenied, .failed: AnchorPalette.sourceInk("coral")
        case .unavailable: AnchorPalette.secondaryInk
        }
    }
}

private struct MacSourceProcessRow: View {
    let process: AnchorProcess

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(process.title)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(process.detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AnchorSpacing.small)

                VStack(alignment: .trailing, spacing: AnchorSpacing.xSmall) {
                    StatusBadge(status: process.status, text: L10n.status(process.status))
                    if let progress = process.progress {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    } else {
                        Text(L10n.unknown)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }
            }

            if let progress = process.progress {
                ProgressView(value: progress, total: 1)
                    .tint(AnchorPalette.source(process.sourceTone))
                    .accessibilityLabel(L10n.taskProgress)
                    .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
            }

            HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.medium) {
                if !process.estimatedCompletion.isEmpty {
                    Label(process.estimatedCompletion, systemImage: "clock")
                }
                if let latestEvent = process.events.max(by: { $0.occurredAt < $1.occurredAt }) {
                    Label(latestEvent.title, systemImage: sourceEventSymbol(latestEvent.kind))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(AnchorPalette.secondaryInk)
        }
        .padding(AnchorSpacing.medium)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MacSourceEventRow: View {
    let event: ProcessEvent

    var body: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            Image(systemName: sourceEventSymbol(event.kind))
                .font(.body.weight(.semibold))
                .foregroundStyle(eventTint)
                .frame(width: 34, height: 34)
                .background(eventTint.opacity(0.16), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                Text(event.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AnchorPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(event.occurredAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            Spacer(minLength: 0)
        }
        .padding(AnchorSpacing.medium)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var eventTint: Color {
        switch event.kind {
        case .decisionRequired, .failed: AnchorPalette.coral
        case .completed, .decisionResolved: AnchorPalette.mintInk
        case .outputReady: AnchorPalette.periwinkle
        case .presence, .connection: AnchorPalette.cyan
        case .created, .progress, .note: AnchorPalette.deepSea
        }
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
#endif
