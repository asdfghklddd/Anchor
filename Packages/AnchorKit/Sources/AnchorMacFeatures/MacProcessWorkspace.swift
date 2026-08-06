#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacProcessWorkspace: View {
    let session: AnchorSession
    @Binding var selectedProcessID: UUID?
    @Binding var selectedOptionID: UUID?
    let onResolve: (Decision, DecisionOption) -> Void

    private var selectedProcess: AnchorProcess? {
        guard let selectedProcessID else { return nil }
        return session.processes.first(where: { $0.id == selectedProcessID })
    }

    private var attentionCount: Int {
        session.processes.filter { $0.status == .needsDecision }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(L10n.liveProcesses)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AnchorPalette.deepSea)
                        .textCase(.uppercase)
                    Text(L10n.happeningNow)
                        .font(.title2.bold())
                        .foregroundStyle(AnchorPalette.ink)
                }
                Spacer()
                if attentionCount > 0 {
                    Label(
                        L10n.decisionCount(attentionCount),
                        systemImage: "exclamationmark.bubble.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AnchorPalette.sourceInk("sand"))
                    .padding(.horizontal, AnchorSpacing.small)
                    .padding(.vertical, AnchorSpacing.xSmall)
                    .background(AnchorPalette.sand.opacity(0.18), in: .capsule)
                } else {
                    Label(L10n.noAttentionNeeded, systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AnchorPalette.mintInk)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AnchorSpacing.large) {
                    processGrid
                        .frame(minWidth: 280, maxWidth: .infinity, alignment: .leading)
                    processInspector
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)
                }

                VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                    processGrid
                    processInspector
                }
            }
        }
    }

    private var processGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 220), spacing: AnchorSpacing.medium)],
            alignment: .leading,
            spacing: AnchorSpacing.medium
        ) {
            ForEach(session.processes) { process in
                MacProcessCard(
                    process: process,
                    isSelected: process.id == selectedProcess?.id
                ) {
                    selectedProcessID = process.id
                    selectedOptionID = nil
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var processInspector: some View {
        MacProcessInspector(
            process: selectedProcess,
            session: session,
            selectedOptionID: $selectedOptionID,
            onResolve: onResolve
        )
    }
}

private struct MacProcessCard: View {
    let process: AnchorProcess
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                HStack(alignment: .top, spacing: AnchorSpacing.small) {
                    SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(process.sourceName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        Text(process.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryInk.opacity(0.78))
                    }
                    Spacer(minLength: AnchorSpacing.small)
                    MacStatusChip(status: process.status)
                }

                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(process.title)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    Text(process.detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }

                HStack(alignment: .bottom) {
                    if let progress = process.progress {
                        VStack(alignment: .leading, spacing: 5) {
                            ProgressView(value: progress, total: 1)
                                .tint(AnchorPalette.source(process.sourceTone))
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                        }
                    } else {
                        Label(L10n.unknown, systemImage: "minus")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if !process.metric.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(process.metric)
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(AnchorPalette.ink)
                            Text(process.metricLabel)
                                .font(.caption)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .lineLimit(1)
                        }
                    }
                }

                if let latestEvent = process.events.last {
                    Label(latestEvent.title, systemImage: eventSymbol(latestEvent.kind))
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(1)
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize ? 248 : 194,
                alignment: .topLeading
            )
            .background(
                LinearGradient(
                    colors: AnchorPalette.sourceSurface(process.sourceTone, dark: colorScheme == .dark),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        isSelected
                            ? AnchorPalette.source(process.sourceTone)
                            : AnchorPalette.ink.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(process.sourceName), \(process.title)")
        .accessibilityValue("\(L10n.status(process.status)), \(progressDescription)")
        .accessibilityHint(L10n.openCurrentProcess)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("mac.current.process")
    }

    private var progressDescription: String {
        guard let progress = process.progress else { return L10n.unknown }
        return progress.formatted(.percent.precision(.fractionLength(0)))
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
}

private struct MacStatusChip: View {
    let status: ProcessStatus

    var body: some View {
        Label(L10n.compactStatus(status), systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tint.opacity(0.15), in: .capsule)
            .overlay {
                Capsule().stroke(tint.opacity(0.28), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch status {
        case .queued: "clock"
        case .running: "play.fill"
        case .needsDecision: "exclamationmark.bubble.fill"
        case .blocked: "pause.fill"
        case .completed: "checkmark"
        case .failed: "xmark"
        case .disconnected: "wifi.slash"
        }
    }

    private var tint: Color {
        switch status {
        case .needsDecision, .blocked: AnchorPalette.sourceInk("sand")
        case .completed: AnchorPalette.mintInk
        case .failed, .disconnected: AnchorPalette.sourceInk("coral")
        case .queued, .running: AnchorPalette.sourceInk("cyan")
        }
    }
}

private struct MacProcessInspector: View {
    let process: AnchorProcess?
    let session: AnchorSession
    @Binding var selectedOptionID: UUID?
    let onResolve: (Decision, DecisionOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            if let process {
                inspector(for: process)
            } else {
                MacClearInspector(session: session)
            }
        }
        .padding(AnchorSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: AnchorPalette.ink.opacity(0.08), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.current.inspector")
    }

    @ViewBuilder
    private func inspector(for process: AnchorProcess) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.selectedProcess)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.deepSea)
                    .textCase(.uppercase)
                Text(process.sourceName)
                    .font(.title3.bold())
                Text(process.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 42)
        }

        if let progress = process.progress {
            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                HStack {
                    Text(L10n.taskProgress)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.bold().monospacedDigit())
                }
                ProgressView(value: progress, total: 1)
                    .tint(AnchorPalette.source(process.sourceTone))
            }
        }

        Text(process.detail)
            .font(.callout)
            .foregroundStyle(AnchorPalette.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)

        if let decision = session.decisions.first(where: {
            $0.processID == process.id && $0.status == .open
        }) {
            MacDecisionPanel(
                decision: decision,
                selectedOptionID: $selectedOptionID,
                onResolve: onResolve
            )
        } else {
            MacAttentionClearState(status: process.status)
        }

        if let latestEvent = process.events.last {
            Divider()
            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                Text(L10n.recentEvent)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.deepSea)
                    .textCase(.uppercase)
                Label(latestEvent.title, systemImage: eventSymbol(latestEvent.kind))
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
}

private struct MacClearInspector: View {
    let session: AnchorSession

    private var runningCount: Int {
        session.processes.filter { $0.status == .running }.count
    }

    private var queuedCount: Int {
        session.processes.filter { $0.status == .queued }.count
    }

    var body: some View {
        VStack(spacing: AnchorSpacing.medium) {
            HarborCompanion(mood: .calm, size: 54)

            VStack(spacing: AnchorSpacing.xSmall) {
                Text(L10n.allProcessesRunning)
                    .font(.headline.bold())
                Text(L10n.ambientClearHeadline)
                    .font(.title3.bold())
                Text(
                    L10n.ambientClearSummary(
                        running: runningCount,
                        queued: queuedCount
                    )
                )
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 0) {
                clearMetric(
                    value: runningCount,
                    label: L10n.live,
                    symbol: "play.fill"
                )
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                clearMetric(
                    value: queuedCount,
                    label: L10n.status(.queued),
                    symbol: "clock"
                )
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                clearMetric(
                    value: session.notes.count,
                    label: L10n.notes,
                    symbol: "bookmark.fill"
                )
            }
        }
        .padding(AnchorSpacing.large)
        .frame(maxWidth: .infinity, minHeight: 300)
        .foregroundStyle(AnchorPalette.ink)
        .background(AnchorPalette.seafoam.opacity(0.18), in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AnchorPalette.seafoam.opacity(0.38), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.inspector.no-attention")
    }

    private func clearMetric(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: AnchorSpacing.xSmall) {
            HStack(spacing: AnchorSpacing.xSmall) {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
                Text(value, format: .number)
            }
            .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct MacDecisionPanel: View {
    let decision: Decision
    @Binding var selectedOptionID: UUID?
    let onResolve: (Decision, DecisionOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Label(L10n.attentionNeeded, systemImage: "exclamationmark.bubble.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(AnchorPalette.sourceInk("sand"))
                .textCase(.uppercase)
            Text(decision.prompt)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: AnchorSpacing.xSmall) {
                ForEach(decision.options) { option in
                    Button {
                        selectedOptionID = option.id
                    } label: {
                        HStack(alignment: .top, spacing: AnchorSpacing.small) {
                            Image(systemName: selectedOptionID == option.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    selectedOptionID == option.id
                                        ? AnchorPalette.deepSea
                                        : AnchorPalette.secondaryInk
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.callout.weight(.semibold))
                                if !option.detail.isEmpty {
                                    Text(option.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(AnchorSpacing.small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedOptionID == option.id
                                ? AnchorPalette.seafoam.opacity(0.20)
                                : AnchorPalette.paper.opacity(0.70),
                            in: .rect(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    selectedOptionID == option.id
                                        ? AnchorPalette.deepSea.opacity(0.45)
                                        : AnchorPalette.ink.opacity(0.08),
                                    lineWidth: selectedOptionID == option.id ? 1.5 : 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                    .accessibilityIdentifier("mac.decision.option")
                }
            }

            Button(L10n.confirmChoice) {
                guard let selectedOptionID,
                      let option = decision.options.first(where: { $0.id == selectedOptionID }) else {
                    return
                }
                onResolve(decision, option)
            }
            .buttonStyle(.borderedProminent)
            .tint(AnchorPalette.deepSea)
            .disabled(selectedOptionID == nil)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("mac.decision.confirm")
        }
        .padding(.top, AnchorSpacing.small)
    }
}

private struct MacAttentionClearState: View {
    let status: ProcessStatus

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.noAttentionNeeded)
                    .font(.callout.weight(.semibold))
                Text(L10n.status(status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: status == .completed ? "checkmark.circle.fill" : "bolt.horizontal.circle.fill")
                .foregroundStyle(status == .completed ? AnchorPalette.mintInk : AnchorPalette.cyan)
        }
        .padding(.top, AnchorSpacing.small)
        .accessibilityElement(children: .combine)
    }
}
#endif
