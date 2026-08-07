#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    let onGoal: () -> Void
    let onAnchor: () -> Void
    let onResolve: (Decision, DecisionOption) -> Void
    let onProcessAction: (AnchorProcess) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var inspectedProcessID: UUID?
    @State private var selectedOptionID: UUID?
    @State private var attentionEdgePulse = false

    var body: some View {
        AnyView(
            dashboardContent
            .background(AnchorPalette.paper)
            // The ticker is a non-interactive status rail. Let its background
            // occupy the bottom home-indicator inset while keeping controls
            // above it in the workspace grid.
            .ignoresSafeArea(.container, edges: .bottom)
            .overlay(alignment: .trailing) {
                attentionEdge
            }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityElement(children: .contain)
            .onAppear(perform: initializeSelection)
            .onChange(of: projection.openDecisions) { oldDecisions, newDecisions in
                updateSelection(for: oldDecisions, and: newDecisions)
            }
            .onChange(of: projection.session?.id) { _, _ in
                resetSelectionForSession()
            }
        )
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            progressEdge

            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
    }

    private var accessibilityLayout: some View {
        ScrollView {
            VStack(spacing: 12) {
                ambientHeader
                goalLine
                processGrid
                inspector
                ticker
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var standardLayout: some View {
        VStack(spacing: 0) {
            ambientHeader
            HStack(spacing: 10) {
                VStack(spacing: 9) {
                    goalLine
                    processGrid
                }
                .frame(maxWidth: .infinity)

                inspector
                    .frame(width: 248)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 9)

            ticker
        }
    }

    @ViewBuilder
    private var attentionEdge: some View {
            if openDecision != nil {
                Rectangle()
                    .fill(AnchorPalette.sand)
                    .frame(minWidth: 3, idealWidth: 3, maxWidth: 3, maxHeight: .infinity)
                    .opacity(reduceMotion || attentionEdgePulse ? 1 : 0.78)
                    .shadow(color: AnchorPalette.sand.opacity(0.5), radius: 8)
                    .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
                    .accessibilityHidden(true)
            }
    }

    private func initializeSelection() {
        // Match the prototype's default: an open decision owns the inspector;
        // otherwise the workspace starts on the clear panel instead of silently
        // selecting the first process.
        resetSelectionForSession()
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            attentionEdgePulse = true
        }
    }

    private func resetSelectionForSession() {
        inspectedProcessID = openDecision?.processID
        selectedOptionID = openDecision?.options.dropFirst().first?.id ?? openDecision?.options.first?.id
    }

    private func updateSelection(for oldDecisions: [Decision], and newDecisions: [Decision]) {
        // Keep an explicitly inspected process selected. If the decision being
        // inspected resolves, return to the clear workspace just as the JSX
        // prototype clears its selectedTaskId after an action.
        if let inspectedProcessID,
           oldDecisions.contains(where: { $0.processID == inspectedProcessID }),
           !newDecisions.contains(where: { $0.processID == inspectedProcessID }) {
            self.inspectedProcessID = nil
        }

        let selectedDecision = newDecisions.first { $0.processID == self.inspectedProcessID }
        let defaultDecision = self.inspectedProcessID == nil ? newDecisions.first : nil
        let decision = selectedDecision ?? defaultDecision
        selectedOptionID = decision?.options.dropFirst().first?.id ?? decision?.options.first?.id
    }

    private var ambientHeader: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.date, style: .time)
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.ink)
                        .accessibilityLabel(context.date.formatted(date: .omitted, time: .shortened))
                        .accessibilityValue(L10n.ambientActive)
                        .accessibilityIdentifier("ambient.time")

                    Label(L10n.ambientActive, systemImage: "circle.fill")
                        .font(.headline.bold())
                        .foregroundStyle(ambientActiveColor)

                    Divider()

                    Text(L10n.focusActive)
                        .font(.headline.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Text(focusDuration(at: context.date))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.ink)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
            } else {
                HStack {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(context.date, style: .time)
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(AnchorPalette.ink)
                            .accessibilityLabel(context.date.formatted(date: .omitted, time: .shortened))
                            .accessibilityValue(L10n.ambientActive)
                            .accessibilityIdentifier("ambient.time")
                        Label(L10n.ambientActive, systemImage: "circle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(ambientActiveColor)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(L10n.focusActive)
                            .font(.caption.bold())
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        Text(focusDuration(at: context.date))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(AnchorPalette.ink)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .padding(.bottom, 24)
            }
        }
    }

    private var goalLine: some View {
        Button(action: onGoal) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HarborBrandMark(size: 44)
                    Text("\(L10n.currentGoal) · \(L10n.anchoredCount(anchorCount))")
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.68))
                    Text(projection.session?.goal.title ?? L10n.emptyTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("ambient.screen")

                    Divider()
                        .overlay(.white.opacity(0.3))

                    Text(projection.overallProgress ?? 0, format: .percent.precision(.fractionLength(0)))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.oceanHighlight)
                    Text(L10n.overallProgress)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.62))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "chevron.right")
                        .font(.headline.bold())
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(16)
                        .accessibilityHidden(true)
                }
            } else {
                HStack(spacing: 10) {
                    HarborBrandMark(size: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(L10n.currentGoal) · \(L10n.anchoredCount(anchorCount))")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.68))
                        Text(projection.session?.goal.title ?? L10n.emptyTitle)
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .accessibilityIdentifier("ambient.screen")
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(projection.overallProgress ?? 0, format: .percent.precision(.fractionLength(0)))
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(AnchorPalette.oceanHighlight)
                        Text(L10n.overallProgress)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.45))
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .frame(height: 54)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.31, blue: 0.40), AnchorPalette.deepSea],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: AnchorPalette.deepSea.opacity(0.18), radius: 10, y: 6)
        .contentShape(.rect)
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(projection.session?.goal.title ?? L10n.dropAnchor)
        .accessibilityHint(projection.session == nil ? L10n.emptyDetail : L10n.currentGoal)
        .accessibilityIdentifier("ambient.goal.button")
    }

    @ViewBuilder
    private var processGrid: some View {
        if let processes = projection.session?.processes, !processes.isEmpty {
            AmbientProcessGrid(
                processes: processes,
                inspectedProcessID: inspectedProcessID,
                onSelect: { process in
                    inspectedProcessID = process.id
                    if let decision = projection.openDecisions.first(where: { $0.processID == process.id }) {
                        selectedOptionID = decision.options.dropFirst().first?.id ?? decision.options.first?.id
                    }
                }
            )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.title2.bold())
                    .accessibilityHidden(true)
                Text(L10n.noEvents)
                    .font(.headline.bold())
                Text(L10n.emptyDetail)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(AnchorPalette.ink)
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.noEvents)
            .accessibilityValue(L10n.emptyDetail)
            .accessibilityIdentifier("ambient.empty.processes")
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if projection.session == nil {
            AmbientEmptyWorkspaceInspector(onAnchor: onAnchor)
        } else if let decision = activeDecision,
           let process = projection.session?.processes.first(where: { $0.id == decision.processID }) {
            AmbientDecisionInspector(
                process: process,
                decision: decision,
                selectedOptionID: $selectedOptionID,
                onResolve: onResolve
            )
        } else if let process = inspectedProcess {
            AmbientProcessInspector(
                process: process,
                pendingDecision: openDecision,
                onClose: { inspectedProcessID = nil },
                onReturnToDecision: {
                    inspectedProcessID = openDecision?.processID
                },
                onAction: {
                    onProcessAction(process)
                }
            )
        } else {
            VStack(spacing: 8) {
                HarborCompanion(mood: .calm, size: 46)
                Text(L10n.allProcessesRunning).font(.headline.bold())
                Text(L10n.ambientClearHeadline)
                    .font(.title3.bold())
                Text(
                    L10n.ambientClearSummary(
                        running: runningProcessCount,
                        queued: queuedProcessCount
                    )
                )
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
            }
            .foregroundStyle(AnchorPalette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AnchorPalette.seafoam.opacity(0.18), in: .rect(cornerRadius: 24, style: .continuous))
            .accessibilityIdentifier("ambient.no-attention")
        }
    }

    private var ticker: some View {
        HStack(spacing: 10) {
            if !dynamicTypeSize.isAccessibilitySize {
                Label(L10n.latestProgress, systemImage: "waveform.path.ecg")
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.seafoam)
                    .accessibilityIdentifier("ambient.ticker.label")
                Divider()
                    .overlay(.white.opacity(0.34))
                    .frame(height: 18)
            }
            AmbientTickerMarquee(text: tickerText)
                .accessibilityIdentifier("ambient.ticker.text")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(
            minHeight: dynamicTypeSize.isAccessibilitySize ? 44 : 40,
            maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : 40
        )
        .background(
            LinearGradient(
                colors: [AnchorPalette.deepSea, Color(red: 0.09, green: 0.30, blue: 0.39)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ambient.ticker")
    }

    private var progressEdge: some View {
        GeometryReader { proxy in
            if processCount == 0 {
                AnchorPalette.secondaryInk.opacity(0.16)
            } else {
                HStack(spacing: 0) {
                    ForEach(projection.session?.processes ?? []) { process in
                        ZStack(alignment: .leading) {
                            AnchorPalette.source(process.sourceTone).opacity(0.18)
                            AnchorPalette.source(process.sourceTone)
                                .frame(width: proxy.size.width / CGFloat(processCount) * (process.progress ?? 0))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 3)
        .ignoresSafeArea(.container, edges: .horizontal)
        .accessibilityHidden(true)
    }

    private var openDecision: Decision? { projection.openDecisions.first }
    private var selectedDecision: Decision? {
        projection.openDecisions.first { $0.processID == inspectedProcessID }
    }
    private var activeDecision: Decision? {
        selectedDecision ?? (inspectedProcessID == nil ? openDecision : nil)
    }
    private var inspectedProcess: AnchorProcess? {
        projection.session?.processes.first { $0.id == inspectedProcessID }
    }
    private var processCount: Int { projection.session?.processes.count ?? 0 }
    private var runningProcessCount: Int {
        projection.session?.processes.filter { $0.status == .running }.count ?? 0
    }
    private var queuedProcessCount: Int {
        projection.session?.processes.filter { $0.status == .queued }.count ?? 0
    }
    private var ambientActiveColor: Color {
        colorScheme == .dark ? AnchorPalette.seafoam : AnchorPalette.mintInk
    }
    private var anchorCount: Int {
        guard let session = projection.session else { return 0 }
        return session.notes.count + 1
    }
    private var tickerText: String {
        projection.session?.processes
            .prefix(4)
            .map(tickerItem(for:))
            .joined(separator: "   ·   ") ?? ""
    }

    private func tickerItem(for process: AnchorProcess) -> String {
        switch process.status {
        case .needsDecision:
            return L10n.latestDecisionProgress(
                source: process.sourceName,
                metric: process.metric,
                metricLabel: process.metricLabel
            )
        case .completed:
            return L10n.latestCompletedProgress(source: process.sourceName, title: process.title)
        default:
            let latestEvent = process.events.max { $0.occurredAt < $1.occurredAt }
            return "\(process.sourceName) · \(latestEvent?.title ?? process.title)"
        }
    }
    private func focusDuration(at date: Date) -> String {
        guard let startedAt = projection.session?.startedAt else { return L10n.focusDuration(0) }
        return L10n.focusDuration(max(0, Int(date.timeIntervalSince(startedAt) / 60)))
    }
}

private struct AmbientTickerMarquee: View {
    let text: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var copyWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isPaused = false

    var body: some View {
        Group {
            if text.isEmpty {
                Text(L10n.noEvents)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            } else if dynamicTypeSize.isAccessibilitySize || reduceMotion {
                Text(text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                GeometryReader { _ in
                    HStack(spacing: 34) {
                        tickerCopy
                        tickerCopy
                    }
                    .offset(x: offset)
                }
                .clipped()
                .frame(minHeight: 24)
                .contentShape(.rect)
                .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 30, pressing: { pressing in
                    isPaused = pressing
                    if !pressing { beginMarquee() }
                }, perform: {})
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 24)
        .onAppear { beginMarquee() }
        .onChange(of: copyWidth) { _, _ in beginMarquee() }
    }

    private var tickerCopy: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .lineLimit(1)
            .fixedSize()
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: TickerCopyWidthKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(TickerCopyWidthKey.self) { width in
                if width > 0, abs(copyWidth - width) > 0.5 {
                    copyWidth = width
                }
            }
    }

    private func beginMarquee() {
        guard !reduceMotion, !dynamicTypeSize.isAccessibilitySize, !isPaused, copyWidth > 0 else { return }
        withAnimation(.linear(duration: 28).repeatForever(autoreverses: false)) {
            offset = -(copyWidth + 34)
        }
    }
}

private struct TickerCopyWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct AmbientEmptyWorkspaceInspector: View {
    let onAnchor: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HarborCompanion(mood: .calm, size: 46)
            Text(L10n.emptyTitle)
                .font(.headline.bold())
                .foregroundStyle(AnchorPalette.ink)
                .accessibilityIdentifier("ambient.empty.workspace")
            Text(L10n.emptyDetail)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAnchor) {
                Label(L10n.dropAnchor, systemImage: "scope")
                    .accessibilityIdentifier("ambient.anchor.button.label")
            }
            .buttonStyle(HarborPrimaryButtonStyle())
            // Treat the icon and title as one control so VoiceOver does not
            // announce the title as a separate child of the button.
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.dropAnchor)
            .accessibilityIdentifier("ambient.anchor.button")
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AnchorPalette.seafoam.opacity(0.18), in: .rect(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

private struct AmbientProcessGrid: View {
    let processes: [AnchorProcess]
    let inspectedProcessID: UUID?
    let onSelect: (AnchorProcess) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(Array(processRows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { process in
                        AmbientProcessGridCell(
                            process: process,
                            selected: inspectedProcessID == process.id,
                            onSelect: onSelect
                        )
                        .gridCellColumns(gridSpan(for: process.tileSize))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: inspectedProcessID)
    }

    private var processRows: [[AnchorProcess]] {
        var rows: [[AnchorProcess]] = []
        var current: [AnchorProcess] = []
        var occupied = 0

        for process in processes {
            let span = gridSpan(for: process.tileSize)
            if !current.isEmpty, occupied + span > 4 {
                rows.append(current)
                current = []
                occupied = 0
            }
            current.append(process)
            occupied += span
        }

        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private func gridSpan(for size: ProcessTileSize) -> Int {
        switch size {
        case .compact, .standard: 2
        case .wide, .large: 4
        }
    }
}

private struct AmbientProcessGridCell: View {
    let process: AnchorProcess
    let selected: Bool
    let onSelect: (AnchorProcess) -> Void

    var body: some View {
        Button {
            onSelect(process)
        } label: {
            AmbientProcessTile(process: process, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(process.sourceName), \(process.title), \(L10n.status(process.status))")
        .accessibilityValue(
            process.progress?.formatted(.percent.precision(.fractionLength(0)))
                ?? L10n.status(process.status)
        )
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct AmbientProcessTile: View {
    let process: AnchorProcess
    let selected: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let tint = AnchorPalette.source(process.sourceTone)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(process.sourceName)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    .lineLimit(1)
                Spacer(minLength: 4)
                statusPill
            }

            Text(process.title)
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .accessibilityIdentifier("ambient.tile.title")

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(process.metric)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Text(process.metricLabel)
                    .font(.caption2)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)

            if let progress = process.progress {
                HStack(spacing: 7) {
                    AnchorProgress(value: progress, tint: tint)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(width: 31, alignment: .trailing)
                }
            }
        }
        .foregroundStyle(AnchorPalette.ink)
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone, dark: colorScheme == .dark),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .shadow(
            color: process.status == .needsDecision ? AnchorPalette.sand.opacity(0.20) : tint.opacity(0.12),
            radius: process.status == .needsDecision ? 10 : 7,
            y: 4
        )
        .accessibilityHidden(true)
    }

    private var statusPill: some View {
        Label(ambientStatusText, systemImage: statusSymbol)
            .font(.caption2.bold())
            .foregroundStyle(
                process.status == .needsDecision
                    ? Color(red: 0.47, green: 0.32, blue: 0)
                    : AnchorPalette.sourceInk(process.sourceTone)
            )
            .padding(.horizontal, 7)
            .frame(minHeight: 23)
            .background(
                process.status == .needsDecision ? AnchorPalette.warmYellow : .white.opacity(0.56),
                in: .capsule
            )
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("ambient.tile.status")
    }

    private var ambientStatusText: String {
        switch process.status {
        case .running:
            if process.events.contains(where: { $0.kind == .decisionResolved }) {
                L10n.confirmed
            } else {
                process.sourceTone == "cyan" ? L10n.rendering : L10n.generating
            }
        case .needsDecision:
            L10n.waitingConfirmation
        case .queued:
            L10n.preparing
        default:
            L10n.compactStatus(process.status)
        }
    }

    private var statusSymbol: String {
        switch process.status {
        case .running: "waveform.path.ecg"
        case .needsDecision: "exclamationmark.circle.fill"
        case .queued: "timer"
        case .blocked: "pause.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .disconnected: "wifi.slash"
        }
    }
}

private struct AmbientDecisionInspector: View {
    let process: AnchorProcess
    let decision: Decision
    @Binding var selectedOptionID: UUID?
    let onResolve: (Decision, DecisionOption) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspectorHeader

            HStack(spacing: 9) {
                StoryboardPreview(
                    tint: AnchorPalette.source(process.sourceTone),
                    compact: true,
                    direction: directionID(for: selectedOptionIndex)
                )
                    .frame(width: 94, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.metric + " " + process.metricLabel)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                        .accessibilityIdentifier("ambient.inspector.metric")
                    Text(process.title)
                        .font(.headline.bold())
                        .lineLimit(2)
                        .accessibilityIdentifier("ambient.inspector.title")
                    Text(process.detail)
                        .font(.caption2)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(decision.options.enumerated()), id: \.element.id) { index, option in
                    Button { selectedOptionID = option.id } label: {
                        VStack(spacing: 4) {
                            StoryboardPreview(
                                tint: decisionTint(for: index),
                                compact: true,
                                direction: directionID(for: index)
                            )
                            .frame(height: 34)
                            Text("\(directionID(for: index)) · \(option.title)")
                                .font(.caption2.bold())
                                .lineLimit(1)
                                .minimumScaleFactor(0.70)
                        }
                        .foregroundStyle(AnchorPalette.ink)
                        .padding(5)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedOptionID == option.id ? AnchorPalette.seafoam.opacity(0.28) : AnchorPalette.paper,
                            in: .rect(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            if selectedOptionID == option.id {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AnchorPalette.mintInk, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityHint(option.detail)
                    .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                    .accessibilityIdentifier(index == 0 ? "ambient.decision.option.first" : "ambient.decision.option.\(option.id.uuidString)")
                }
            }

            Button {
                guard let selectedOptionID,
                      let option = decision.options.first(where: { $0.id == selectedOptionID }) else { return }
                onResolve(decision, option)
                self.selectedOptionID = nil
            } label: {
                HStack {
                    Text("\(L10n.confirmDirection) \(directionID(for: selectedOptionIndex))")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .accessibilityIdentifier("ambient.decision.confirm.label")
            }
            .buttonStyle(HarborPrimaryButtonStyle())
            .disabled(selectedOptionID == nil)
            .accessibilityIdentifier("ambient.decision.confirm")
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone, dark: colorScheme == .dark),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: AnchorPalette.sand.opacity(0.16), radius: 12, y: 7)
    }

    private var selectedOptionIndex: Int {
        guard let selectedOptionID,
              let index = decision.options.firstIndex(where: { $0.id == selectedOptionID }) else { return 1 }
        return index
    }

    private func directionID(for index: Int) -> String {
        String(Character(UnicodeScalar(65 + min(max(index, 0), 25))!))
    }

    private func decisionTint(for index: Int) -> Color {
        switch index {
        case 0: AnchorPalette.coral
        case 1: AnchorPalette.periwinkle
        default: AnchorPalette.cyan
        }
    }

    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(process.sourceName)
                    .font(.caption.bold())
                    .foregroundStyle(colorScheme == .dark ? AnchorPalette.harborWhite : AnchorPalette.deepSea)
                Label(L10n.attentionNeeded, systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 0))
            }
            Spacer()
        }
    }
}

private struct AmbientProcessInspector: View {
    let process: AnchorProcess
    let pendingDecision: Decision?
    let onClose: () -> Void
    let onReturnToDecision: () -> Void
    let onAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            inspectorHeader

            if let pendingDecision, pendingDecision.processID != process.id {
                Button(action: onReturnToDecision) {
                    Label(
                        "\(L10n.attentionNeeded) · \(pendingDecision.title)",
                        systemImage: "exclamationmark.circle.fill"
                    )
                    .font(.caption2.bold())
                    .lineLimit(1)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 0))
                .padding(.horizontal, 9)
                .frame(minHeight: 28)
                .background(AnchorPalette.warmYellow, in: .capsule)
                .accessibilityIdentifier("ambient.return-decision")
            }

            HStack(spacing: 9) {
                VStack(spacing: 2) {
                    Text(process.metric)
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    Text(process.metricLabel)
                        .font(.caption2)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(width: 74, height: 60)
                .background(.white.opacity(0.52), in: .rect(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(process.title)
                        .font(.headline.bold())
                        .lineLimit(2)
                    Text(process.detail)
                        .font(.caption2)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let progress = process.progress {
                HStack(spacing: 8) {
                    Text(L10n.taskProgress)
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    AnchorProgress(value: progress, tint: AnchorPalette.source(process.sourceTone))
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.bold().monospacedDigit())
                        .frame(width: 31, alignment: .trailing)
                }
            }

            if !process.events.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.activity)
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    ForEach(Array(process.events.suffix(2))) { event in
                        Label(event.title, systemImage: eventSymbol(event.kind))
                            .font(.caption2)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: onAction) {
                HStack {
                    Text(actionTitle)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(HarborPrimaryButtonStyle())
            .accessibilityIdentifier("ambient.process.action")
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone, dark: colorScheme == .dark),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20, style: .continuous)
        )
    }

    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(process.sourceName)
                    .font(.caption.bold())
                Text(L10n.status(process.status))
                    .font(.caption2)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            Spacer(minLength: 4)
            Button(action: onClose) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.55))
                        .frame(width: 25, height: 25)
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.close)
            .accessibilityIdentifier("ambient.process.close")
        }
    }

    private var actionTitle: String {
        switch process.status {
        case .queued:
            L10n.runNow
        case .completed:
            L10n.viewOutput
        default:
            L10n.openCurrentProcess
        }
    }
}
#endif
