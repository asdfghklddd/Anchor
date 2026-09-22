#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct InsightsView: View {
    let projection: SessionProjection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                HStack(spacing: AnchorSpacing.small) {
                    MetricTile(value: "\(projection.session?.processes.count ?? 0)", label: L10n.processes, tint: AnchorPalette.cyan)
                    MetricTile(value: "\(projection.openDecisions.count)", label: L10n.decisions, tint: AnchorPalette.sand)
                    MetricTile(value: "\(completedCount)", label: L10n.completedWork, tint: AnchorPalette.seafoam)
                }
                AnchorCard(tint: AnchorPalette.periwinkle) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        Text(L10n.currentGoal).font(.caption.bold())
                        Text(projection.session?.goal.title ?? "")
                            .font(.title2.bold())
                        Text(projection.session?.goal.note ?? "")
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        Label(
                            TaskStatusPresentation.text(for: projection.session),
                            systemImage: "waveform.path.ecg"
                        )
                        .font(.subheadline.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }
                Text(L10n.activity).font(.title2.bold())
                ForEach(projection.session?.timeline ?? []) { event in
                    EventRow(event: event)
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .navigationTitle(L10n.insights)
    }

    private var completedCount: Int {
        projection.session?.processes.filter { $0.status == .completed }.count ?? 0
    }
}

private struct MetricTile: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.title.bold().monospacedDigit())
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
        }
        .foregroundStyle(AnchorPalette.ink)
        .padding(AnchorSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(tint.opacity(0.25), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

struct ProfileView: View {
    let projection: SessionProjection
    let onRoute: (AnchorRoute) -> Void
    let onSheet: (AnchorSheet) -> Void

    var body: some View {
        ZStack {
            HarborBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    identityCard
                    metricStrip
                    sessionCard
                    memorySection
                    workStyleSection
                }
                .padding(.horizontal, AnchorSpacing.medium)
                .padding(.bottom, AnchorSpacing.xLarge)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L10n.profile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onSheet(.account)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel(L10n.settings)
                .accessibilityIdentifier("profile.account.button")
            }
        }
    }

    private var identityCard: some View {
        HStack(spacing: 14) {
            HarborBrandMark(size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.personalAnchor)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                Text(L10n.profile)
                    .font(.title.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                Label(L10n.contextSyncStable, systemImage: "wifi")
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.secondaryText)
            }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                Text(projection.connection == .connected ? "1" : "0")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.brandDeep)
                Text(L10n.macOnline)
                    .font(.caption2)
                    .foregroundStyle(AnchorPalette.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(AnchorPalette.fluoriteSurface.opacity(0.78), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
            }
        }
        .padding(18)
        .fluoriteSurface(
            fill: AnchorPalette.softBlue.opacity(0.42),
            border: AnchorPalette.aiBlue.opacity(0.36),
            cornerRadius: 22,
            elevated: true
        )
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var metricStrip: some View {
        HStack(spacing: 9) {
            profileMetric(
                value: L10n.minuteCount(focusMinutes),
                label: L10n.guardedFocus,
                symbol: "timer",
                tint: AnchorPalette.coral,
                progress: min(1, Double(focusMinutes) / 60)
            ) {
                onSheet(.profileDetail(.focus))
            }
            profileMetric(
                value: "\(savedContextCount)",
                label: L10n.savedContexts,
                symbol: "square.stack.3d.up",
                tint: AnchorPalette.periwinkle,
                progress: min(1, Double(savedContextCount) / 10)
            ) {
                onSheet(.profileDetail(.contexts))
            }
            profileMetric(
                value: "\(completedCount)",
                label: L10n.completedAnchors,
                symbol: "scope",
                tint: AnchorPalette.seafoam,
                progress: min(1, Double(completedCount) / 4)
            ) {
                onSheet(.profileDetail(.anchors))
            }
        }
    }

    private func profileMetric(
        value: String,
        label: String,
        symbol: String,
        tint: Color,
        progress: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: symbol)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.brandDeep)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.18), in: .rect(cornerRadius: 8))
                    Spacer(minLength: 2)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.secondaryText)
                }
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .lineLimit(2)
                AnchorProgress(value: progress, tint: tint)
                .frame(height: 5)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .fluoriteSurface(cornerRadius: 16)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityElement(children: .combine)
    }

    private var sessionCard: some View {
        Button { onSheet(.profileDetail(.session)) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.thisSessionData)
                            .font(.caption2.bold())
                            .foregroundStyle(AnchorPalette.link)
                        Text(L10n.runningWork)
                            .font(.title3.bold())
                            .foregroundStyle(AnchorPalette.ink)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text(L10n.runningAndWaiting(running: runningCount, attention: projection.openDecisions.count))
                            .font(.caption2.bold())
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        Image(systemName: "chevron.right").font(.caption2.bold())
                    }
                }

                HStack(spacing: 0) {
                    sessionMetric(L10n.minuteCount(focusMinutes), label: L10n.focusTime)
                    Divider().padding(.vertical, 6)
                    sessionMetric(TaskStatusPresentation.text(for: projection.session), label: L10n.currentStatus)
                    Divider().padding(.vertical, 6)
                    sessionMetric("\(completedCount)/\(processCount)", label: L10n.completedWork)
                }

                HStack(spacing: 12) {
                    Label(L10n.parallelEfficiency, systemImage: "gauge.with.dots.needle.67percent")
                    Label(L10n.anchoredCount((projection.session?.notes.count ?? 0) + 1), systemImage: "mappin.and.ellipse")
                }
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.secondaryInk)
            }
            .padding(15)
            .fluoriteSurface(cornerRadius: 20, elevated: true)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityIdentifier("profile.session.card")
    }

    private func sessionMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label).font(.caption2).foregroundStyle(AnchorPalette.secondaryInk).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.memoryTrace)
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.link)
                    Text(L10n.recentlyHeld)
                        .font(.title3.bold())
                        .foregroundStyle(AnchorPalette.ink)
                }
                Spacer()
                Button(L10n.history) { onRoute(.history) }
                    .font(.caption.bold())
                    .accessibilityIdentifier("profile.history.button")
            }

            VStack(spacing: 0) {
                ForEach(Array((projection.session?.timeline ?? []).prefix(3).enumerated()), id: \.element.id) { index, event in
                    Button {
                        let detail: ProfileDetailKind = switch index {
                        case 0: .returnMemory
                        case 1: .decisionTrace
                        default: .contextSnapshot
                        }
                        onSheet(.profileDetail(detail))
                    } label: {
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: eventSymbol(event.kind))
                                .font(.subheadline.bold())
                                .foregroundStyle(memoryTint(index))
                                .frame(width: 34, height: 34)
                                .background(memoryTint(index).opacity(0.14), in: .circle)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.occurredAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                                Text(event.title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
                                if !event.detail.isEmpty {
                                    Text(event.detail).font(.caption).foregroundStyle(AnchorPalette.secondaryInk).lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(AnchorPalette.secondaryInk)
                        }
                        .padding(.vertical, 11)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if index < min(2, (projection.session?.timeline.count ?? 1) - 1) {
                        Divider().padding(.leading, 45)
                    }
                }
            }
            .padding(.horizontal, 13)
            .fluoriteSurface(cornerRadius: 18)
        }
    }

    private var workStyleSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.workStyle)
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.link)

            VStack(spacing: 0) {
                routeRow(L10n.taskManagement, symbol: "square.grid.2x2", route: .taskManagement)
                Divider().padding(.leading, 48)
                sheetRow(
                    AnchorStrings.value("settings.icloud", default: "iCloud Sync"),
                    symbol: "icloud",
                    sheet: .icloud
                )
                Divider().padding(.leading, 48)
                routeRow(L10n.connections, symbol: "macbook.and.iphone", route: .connections)
                Divider().padding(.leading, 48)
                routeRow(L10n.sources, symbol: "point.3.connected.trianglepath.dotted", route: .sources)
                Divider().padding(.leading, 48)
                routeRow(L10n.notificationsSettings, symbol: "bell", route: .notificationSettings)
                Divider().padding(.leading, 48)
                routeRow(L10n.privacy, symbol: "hand.raised", route: .privacy)
                Divider().padding(.leading, 48)
                routeRow(L10n.accessibility, symbol: "accessibility", route: .accessibility)
            }
            .padding(.horizontal, 12)
            .fluoriteSurface(cornerRadius: 18)
        }
    }

    private func routeRow(_ title: String, symbol: String, route: AnchorRoute) -> some View {
        Button { onRoute(route) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(AnchorPalette.interaction)
                    .frame(width: 32, height: 32)
                    .background(AnchorPalette.softBlue.opacity(0.62), in: .rect(cornerRadius: 9))
                Text(title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(AnchorPalette.secondaryText)
            }
            .frame(minHeight: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func sheetRow(_ title: String, symbol: String, sheet: AnchorSheet) -> some View {
        Button { onSheet(sheet) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(AnchorPalette.interaction)
                    .frame(width: 32, height: 32)
                    .background(AnchorPalette.softBlue.opacity(0.62), in: .rect(cornerRadius: 9))
                Text(title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(AnchorPalette.secondaryText)
            }
            .frame(minHeight: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private func memoryTint(_ index: Int) -> Color {
        switch index {
        case 0: AnchorPalette.seafoam
        case 1: AnchorPalette.coral
        default: AnchorPalette.periwinkle
        }
    }

    private var processCount: Int { projection.session?.processes.count ?? 0 }
    private var runningCount: Int { projection.session?.processes.filter { $0.status == .running }.count ?? 0 }
    private var completedCount: Int { projection.session?.processes.filter { $0.status == .completed }.count ?? 0 }
    private var savedContextCount: Int { (projection.session?.notes.count ?? 0) + (projection.session?.snapshots.count ?? 0) }
    private var focusMinutes: Int {
        guard let startedAt = projection.session?.startedAt else { return 0 }
        return max(0, Int(Date.now.timeIntervalSince(startedAt) / 60))
    }
}

struct HistoryView: View {
    let projection: SessionProjection
    let onOpen: (UUID) -> Void

    var body: some View {
        List {
            ForEach(projection.archivedSessions) { session in
                Button { onOpen(session.id) } label: {
                    HistoryRow(session: session)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("history.row.\(session.id.uuidString)")
            }
        }
        .overlay {
            if projection.archivedSessions.isEmpty {
                ContentUnavailableView(
                    L10n.history,
                    systemImage: "clock",
                    description: Text(L10n.historyEmptyDetail)
                )
            }
        }
        .navigationTitle(L10n.history)
        .accessibilityIdentifier("history.screen")
    }
}

private struct HistoryRow: View {
    let session: AnchorSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.goal.title).font(.headline)
                Text(session.goal.completionCriteria)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(session.completedAt ?? session.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(AnchorPalette.seafoam)
                .accessibilityLabel(L10n.completed)
        }
        .padding(.vertical, AnchorSpacing.xSmall)
    }
}

struct HistoryDetailView: View {
    let projection: SessionProjection
    let sessionID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                AnchorCard(tint: AnchorPalette.seafoam) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        Text(L10n.currentGoal).font(.caption.bold())
                        Text(session?.goal.title ?? L10n.emptyTitle).font(.title.bold())
                        if let session {
                            Text(session.goal.completionCriteria)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                            Text(session.completedAt ?? session.startedAt, format: .dateTime.year().month().day().hour().minute())
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                    }
                }
                if let session, !session.processes.isEmpty {
                    Text(L10n.processes).font(.title2.bold())
                    ForEach(session.processes) { process in
                        ProcessCard(process: process, isRemote: false)
                    }
                }
                if let session, !session.notes.isEmpty {
                    Text(L10n.notes).font(.title2.bold())
                    ForEach(session.notes) { note in
                        Text(note.text)
                            .padding(AnchorSpacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AnchorPalette.surface, in: .rect(cornerRadius: 18))
                    }
                }
                if let session, !session.timeline.isEmpty {
                    Text(L10n.activity).font(.title2.bold())
                    ForEach(session.timeline) { event in
                        EventRow(event: event)
                    }
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .navigationTitle(L10n.sessionSummary)
        .accessibilityIdentifier("history.detail.screen")
    }

    private var session: AnchorSession? { projection.archivedSession(id: sessionID) }
}

struct TaskManagementView: View {
    let model: AnchorSessionModel
    @State private var processes: [AnchorProcess]

    init(model: AnchorSessionModel) {
        self.model = model
        _processes = State(initialValue: model.projection.session?.processes ?? [])
    }

    var body: some View {
        List {
            Section {
                Text(L10n.moveHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section(L10n.processes) {
                ForEach(processes) { process in
                    HStack {
                        Text(process.sourceSymbol)
                            .font(.headline.bold())
                            .frame(width: 38, height: 38)
                            .background(
                                AnchorPalette.source(process.sourceTone).opacity(0.5),
                                in: .rect(cornerRadius: 11)
                            )
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(process.title).font(.headline)
                            Text(L10n.status(process.status)).font(.caption)
                        }
                        Spacer()
                        Menu {
                            ForEach(ProcessTileSize.allCases, id: \.self) { size in
                                Button(L10n.tileSize(size)) {
                                    updateSize(process.id, size: size)
                                }
                            }
                        } label: {
                            Label(L10n.tileSize(process.tileSize), systemImage: "rectangle.resize")
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L10n.layout)
                    }
                }
                .onMove { source, destination in
                    processes.move(fromOffsets: source, toOffset: destination)
                    Task { await model.send(.reorderProcesses(processes.map(\.id))) }
                }
            }
        }
        .navigationTitle(L10n.taskManagement)
        .toolbar { EditButton() }
    }

    private func updateSize(_ processID: UUID, size: ProcessTileSize) {
        guard let index = processes.firstIndex(where: { $0.id == processID }) else { return }
        processes[index].tileSize = size
        Task { await model.send(.updateTileSize(processID: processID, size: size)) }
    }
}

struct FinishSessionView: View {
    let model: AnchorSessionModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletionConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                    AnchorMark(size: 72)
                    Text(L10n.sessionSummary).font(.largeTitle.bold())
                    AnchorCard(tint: AnchorPalette.seafoam) {
                        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                            Text(model.projection.session?.goal.title ?? "")
                                .font(.title2.bold())
                            Label(L10n.processCount(model.projection.session?.processes.count ?? 0), systemImage: "square.grid.2x2")
                            Label(L10n.noteCount(model.projection.session?.notes.count ?? 0), systemImage: "bookmark")
                            Label(L10n.decisionCount(model.projection.session?.decisions.filter { $0.status == .resolved }.count ?? 0), systemImage: "checkmark.bubble")
                        }
                    }
                    Text(L10n.finishConfirmDetail)
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.completeSession) {
                        showingCompletionConfirmation = true
                    }
                    .buttonStyle(AnchorPrimaryButtonStyle())
                    .accessibilityIdentifier("session.finish.button")
                }
                .padding(AnchorSpacing.large)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(AnchorPalette.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .confirmationDialog(
            L10n.finishConfirmTitle,
            isPresented: $showingCompletionConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.completeSession) {
                Task {
                    guard await model.send(.completeSession) else { return }
                    dismiss()
                }
            }
            .accessibilityIdentifier("session.finish.confirm")
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.finishConfirmDetail)
        }
    }
}
#endif
