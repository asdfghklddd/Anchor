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
                        if let progress = projection.overallProgress {
                            AnchorProgress(value: progress, tint: AnchorPalette.periwinkle)
                        }
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
    }

    private var identityCard: some View {
        HarborHeroSurface(cornerRadius: 26) {
            HStack(spacing: 13) {
                HarborBrandMark(size: 54)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.personalAnchor)
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.oceanHighlight)
                    Text(L10n.profile)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Label(L10n.contextSyncStable, systemImage: "wifi")
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.oceanHighlight)
                }
                Spacer()
                VStack(spacing: 1) {
                    Text(projection.connection == .connected ? "1" : "0")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.warmYellow)
                    Text(L10n.macOnline)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            .padding(18)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var metricStrip: some View {
        HStack(spacing: 9) {
            profileMetric(value: L10n.minuteCount(focusMinutes), label: L10n.guardedFocus, tint: AnchorPalette.coral, progress: min(1, Double(focusMinutes) / 60))
            profileMetric(value: "\(savedContextCount)", label: L10n.savedContexts, tint: AnchorPalette.periwinkle, progress: min(1, Double(savedContextCount) / 10))
            profileMetric(value: "\(completedCount)", label: L10n.completedAnchors, tint: AnchorPalette.seafoam, progress: min(1, Double(completedCount) / 4))
        }
    }

    private func profileMetric(value: String, label: String, tint: Color, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(AnchorPalette.secondaryInk)
            }
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(2)
            GeometryReader { proxy in
                Capsule()
                    .fill(tint.opacity(0.16))
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint).frame(width: proxy.size.width * progress)
                    }
            }
            .frame(height: 5)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(tint.opacity(0.16), in: .rect(cornerRadius: 20, style: .continuous))
        .shadow(color: tint.opacity(0.09), radius: 8, y: 5)
        .accessibilityElement(children: .combine)
    }

    private var sessionCard: some View {
        Button { onRoute(.insights) } label: {
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
                    sessionMetric(projection.overallProgress?.formatted(.percent.precision(.fractionLength(0))) ?? "—", label: L10n.overallProgress)
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
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 24, style: .continuous))
            .shadow(color: AnchorPalette.deepSea.opacity(0.08), radius: 12, y: 7)
        }
        .buttonStyle(.plain)
    }

    private func sessionMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(AnchorPalette.ink).lineLimit(1)
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
            }

            VStack(spacing: 0) {
                ForEach(Array((projection.session?.timeline ?? []).prefix(3).enumerated()), id: \.element.id) { index, event in
                    Button { onRoute(.history) } label: {
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
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
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
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private func routeRow(_ title: String, symbol: String, route: AnchorRoute) -> some View {
        Button { onRoute(route) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(AnchorPalette.link)
                    .frame(width: 32, height: 32)
                    .background(AnchorPalette.cyan.opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))
                Text(title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
                Spacer()
                Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(AnchorPalette.secondaryInk)
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
            if let session = projection.session {
                Button { onOpen(session.id) } label: {
                    HistoryRow(
                        title: session.goal.title,
                        date: session.startedAt,
                        status: session.status
                    )
                }
                .buttonStyle(.plain)
                ForEach(session.snapshots) { snapshot in
                    Button { onOpen(snapshot.id) } label: {
                        HistoryRow(title: snapshot.goalTitle, date: snapshot.createdAt, status: .active)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay {
            if projection.session == nil {
                ContentUnavailableView(L10n.emptyTitle, systemImage: "clock")
            }
        }
        .navigationTitle(L10n.history)
    }
}

private struct HistoryRow: View {
    let title: String
    let date: Date
    let status: SessionStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(date, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: status == .completed ? "checkmark.seal.fill" : "scope")
                .foregroundStyle(status == .completed ? AnchorPalette.seafoam : AnchorPalette.coral)
                .accessibilityLabel(status == .completed ? L10n.completed : L10n.workspace)
        }
        .padding(.vertical, AnchorSpacing.xSmall)
    }
}

struct HistoryDetailView: View {
    let projection: SessionProjection
    let snapshotID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                AnchorCard(tint: AnchorPalette.seafoam) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        Text(L10n.currentGoal).font(.caption.bold())
                        Text(title).font(.title.bold())
                        if let date {
                            Text(date, format: .dateTime.year().month().day().hour().minute())
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                    }
                }
                Text(L10n.processes).font(.title2.bold())
                ForEach(displayedProcesses) { process in
                    ProcessCard(process: process, isRemote: false)
                }
                if !displayedNotes.isEmpty {
                    Text(L10n.notes).font(.title2.bold())
                    ForEach(displayedNotes, id: \.self) { note in
                        Text(note)
                            .padding(AnchorSpacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AnchorPalette.surface, in: .rect(cornerRadius: 18))
                    }
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .navigationTitle(L10n.sessionSummary)
    }

    private var snapshot: ContextSnapshot? {
        projection.session?.snapshots.first { $0.id == snapshotID }
    }
    private var title: String {
        snapshot?.goalTitle ?? projection.session?.goal.title ?? L10n.emptyTitle
    }
    private var date: Date? {
        snapshot?.createdAt ?? projection.session?.startedAt
    }
    private var displayedProcesses: [AnchorProcess] {
        snapshot?.processes ?? projection.session?.processes ?? []
    }
    private var displayedNotes: [String] {
        if let snapshot {
            return snapshot.latestNote.map { [$0] } ?? []
        }
        return projection.session?.notes.map(\.text) ?? []
    }
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
                    if model.projection.session?.status == .completed {
                        Label(L10n.completed, systemImage: "checkmark.seal.fill")
                            .font(.title2.bold())
                            .foregroundStyle(AnchorPalette.ink)
                        Button(L10n.resume) {
                            Task {
                                await model.send(.resumeSession)
                                dismiss()
                            }
                        }
                        .buttonStyle(AnchorPrimaryButtonStyle())
                    } else {
                        Button(L10n.completeSession) {
                            Task {
                                await model.send(.completeSession)
                                dismiss()
                            }
                        }
                        .buttonStyle(AnchorPrimaryButtonStyle())
                    }
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
    }
}
#endif
