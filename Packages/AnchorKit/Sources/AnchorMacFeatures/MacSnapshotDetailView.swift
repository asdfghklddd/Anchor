#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSnapshotDetailView: View {
    let snapshot: ContextSnapshot

    @Environment(\.dismiss) private var dismiss

    private var runningCount: Int {
        snapshot.processes.filter { $0.status == .running }.count
    }

    private var completedCount: Int {
        snapshot.processes.filter { $0.status == .completed }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                header
                summary
                processes
                if let latestNote = snapshot.latestNote, !latestNote.isEmpty {
                    note(latestNote)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(AnchorSpacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .background(HarborBackground())
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.close, action: dismiss.callAsFunction)
            }
        }
        .frame(minWidth: 560, idealWidth: 680, minHeight: 460)
        .accessibilityIdentifier("mac.snapshot.detail")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Label(L10n.currentSnapshot, systemImage: "camera.metering.center.weighted")
                .font(.caption.weight(.bold))
                .foregroundStyle(AnchorPalette.deepSea)
                .textCase(.uppercase)
            Text(snapshot.goalTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(AnchorPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(snapshot.createdAt, format: .dateTime.year().month().day().hour().minute())
                .font(.callout.monospacedDigit())
                .foregroundStyle(AnchorPalette.secondaryInk)
        }
    }

    private var summary: some View {
        AnchorCard(tint: AnchorPalette.seafoam) {
            HStack(spacing: 0) {
                snapshotMetric(value: snapshot.processes.count, label: L10n.processes, symbol: "square.grid.2x2")
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                snapshotMetric(value: runningCount, label: L10n.live, symbol: "play.fill")
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                snapshotMetric(value: completedCount, label: L10n.completed, symbol: "checkmark.circle.fill")
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                snapshotMetric(value: snapshot.openDecisionIDs.count, label: L10n.decisions, symbol: "exclamationmark.bubble")
            }
        }
    }

    private func snapshotMetric(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: AnchorSpacing.xSmall) {
            HStack(spacing: AnchorSpacing.xSmall) {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
                Text(value, format: .number)
            }
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(AnchorPalette.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var processes: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            Text(L10n.processes)
                .font(.title2.bold())
                .foregroundStyle(AnchorPalette.ink)

            VStack(spacing: AnchorSpacing.small) {
                ForEach(snapshot.processes) { process in
                    HStack(alignment: .top, spacing: AnchorSpacing.small) {
                        SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(process.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(AnchorPalette.ink)
                            Text(process.sourceName)
                                .font(.caption)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                        Spacer(minLength: AnchorSpacing.small)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(L10n.status(process.status))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
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
                    .padding(AnchorSpacing.medium)
                    .background(AnchorPalette.surface, in: .rect(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func note(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Label(L10n.notes, systemImage: "bookmark.fill")
                .font(.title2.bold())
            Text(text)
                .font(.body)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
                .padding(AnchorSpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnchorPalette.sand.opacity(0.22), in: .rect(cornerRadius: 16, style: .continuous))
        }
    }
}
#endif
