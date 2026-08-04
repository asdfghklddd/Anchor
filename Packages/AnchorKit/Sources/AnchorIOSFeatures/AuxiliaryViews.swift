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
    let onRoute: (AnchorRoute) -> Void

    var body: some View {
        List {
            Section {
                HStack(spacing: AnchorSpacing.medium) {
                    AnchorMark(size: 62)
                    VStack(alignment: .leading) {
                        Text(L10n.profile).font(.title2.bold())
                        Text(L10n.localOnly)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, AnchorSpacing.small)
            }
            Section {
                routeRow(L10n.history, symbol: "clock.arrow.circlepath", route: .history)
                routeRow(L10n.taskManagement, symbol: "square.grid.2x2", route: .taskManagement)
            }
            Section(L10n.settings) {
                routeRow(L10n.connections, symbol: "macbook.and.iphone", route: .connections)
                routeRow(L10n.sources, symbol: "point.3.filled.connected.trianglepath.dotted", route: .sources)
                routeRow(L10n.notificationsSettings, symbol: "bell", route: .notificationSettings)
                routeRow(L10n.privacy, symbol: "hand.raised", route: .privacy)
                routeRow(L10n.accessibility, symbol: "accessibility", route: .accessibility)
            }
        }
        .navigationTitle(L10n.profile)
    }

    private func routeRow(_ title: String, symbol: String, route: AnchorRoute) -> some View {
        Button { onRoute(route) } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
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
                ForEach(projection.session?.processes ?? []) { process in
                    ProcessCard(process: process, isRemote: false)
                }
                if let notes = projection.session?.notes, !notes.isEmpty {
                    Text(L10n.notes).font(.title2.bold())
                    ForEach(notes) { note in
                        Text(note.text)
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
