#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkProcessList: View {
    let processes: [AnchorProcess]
    let onOpenProcess: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAllProcesses = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.currentTasks)
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                Spacer(minLength: AnchorSpacing.medium)
                Text(L10n.processCount(processes.count))
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            if processes.isEmpty {
                ContentUnavailableView(
                    L10n.noEvents,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text(L10n.emptyDetail)
                )
                .frame(maxWidth: .infinity, minHeight: 190)
                .fluoriteSurface(cornerRadius: 16)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(visibleProcesses) { process in
                        if process.id != processes.first?.id {
                            Divider().padding(.leading, 68)
                        }
                        MacWorkProcessRow(
                            process: process,
                            action: { onOpenProcess(process.id) }
                        )
                    }
                }
                .clipShape(.rect(cornerRadius: 16))
                .fluoriteSurface(cornerRadius: 16)

                if processes.count > collapsedProcessLimit {
                    Button(action: toggleProcessList) {
                        Label(
                            showsAllProcesses
                                ? L10n.showFewerProcesses
                                : L10n.showAllProcesses(processes.count),
                            systemImage: showsAllProcesses ? "chevron.up" : "chevron.down"
                        )
                        .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("mac.current.process-list.toggle")
                }
            }
        }
        .accessibilityIdentifier("mac.current.process-list")
    }

    private let collapsedProcessLimit = 6

    private var visibleProcesses: [AnchorProcess] {
        showsAllProcesses ? processes : Array(processes.prefix(collapsedProcessLimit))
    }

    private func toggleProcessList() {
        withAnimation(reduceMotion ? nil : AnchorMotion.panel) {
            showsAllProcesses.toggle()
        }
    }
}

private struct MacWorkProcessRow: View {
    let process: AnchorProcess
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var statusWidth = 110.0
    @ScaledMetric(relativeTo: .body) private var progressWidth = 100.0
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    verticalContent
                } else {
                    ViewThatFits(in: .horizontal) {
                        horizontalContent
                        verticalContent
                    }
                }
            }
            .padding(.horizontal, AnchorSpacing.medium)
            .padding(.vertical, AnchorSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(isHovering ? AnchorPalette.softBlue.opacity(0.34) : .clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover(perform: updateHover)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(processLabel)
        .accessibilityValue("\(L10n.processStatus(process)), \(progressDescription)")
        .accessibilityHint(L10n.openCurrentProcess)
        .help([processLabel, process.detail, progressDescription]
            .filter { !$0.isEmpty }.joined(separator: "\n"))
        .accessibilityIdentifier("mac.current.process")
    }

    private var processLabel: String {
        process.sourceName == process.title
            ? process.title
            : "\(process.sourceName), \(process.title)"
    }

    private var horizontalContent: some View {
        HStack(alignment: .center, spacing: AnchorSpacing.medium) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 36)
            processCopy
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            // Stable trailing columns keep status and progress scannable across rows.
            StatusBadge(status: process.status, text: L10n.compactProcessStatus(process), interrupted: process.isInterrupted)
                .frame(width: statusWidth, alignment: .trailing)
            progress
                .frame(width: progressWidth, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.callout.bold())
                .foregroundStyle(AnchorPalette.secondaryInk)
                .accessibilityHidden(true)
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 36)
                processCopy
            }
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                StatusBadge(status: process.status, text: L10n.compactProcessStatus(process), interrupted: process.isInterrupted)
                Spacer(minLength: AnchorSpacing.small)
                progress
            }
        }
    }

    private var processCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            taskTitle
            HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.small) {
                if process.sourceName != process.title {
                    sourceLabel
                        .layoutPriority(1)
                }
                if !process.detail.isEmpty {
                    Text(process.detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
            }
        }
    }

    private var taskTitle: some View {
        Text(process.title)
            .font(.headline)
            .foregroundStyle(AnchorPalette.ink)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sourceLabel: some View {
        Text(process.sourceName)
            .font(.caption)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .foregroundStyle(AnchorPalette.brandDeep)
            .padding(.horizontal, AnchorSpacing.xSmall)
            .padding(.vertical, 2)
            .background(AnchorPalette.softBlue.opacity(0.34), in: .capsule)
    }

    @ViewBuilder
    private var progress: some View {
        if let progressValue = process.progress {
            Text(progressValue, format: .percent.precision(.fractionLength(0)))
                .font(.callout.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
                .fixedSize()
        } else if !process.metric.isEmpty {
            VStack(alignment: .trailing, spacing: 2) {
                Text(process.metric)
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.ink)
                Text(process.metricLabel)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Label(L10n.unknown, systemImage: "minus")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var progressDescription: String {
        if let progressValue = process.progress {
            return progressValue.formatted(.percent.precision(.fractionLength(0)))
        }
        // VoiceOver should read the same source metric that is visible in the row.
        return process.metric.isEmpty ? L10n.unknown : "\(process.metric) \(process.metricLabel)"
    }

    private func updateHover(_ hovering: Bool) {
        withAnimation(reduceMotion ? nil : AnchorMotion.micro) {
            isHovering = hovering
        }
    }
}
#endif
