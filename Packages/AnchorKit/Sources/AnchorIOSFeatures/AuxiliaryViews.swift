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
                    MetricTile(value: "\(projection.session?.taskProcesses.count ?? 0)", label: L10n.processes, tint: AnchorPalette.cyan)
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
                ForEach(projection.session?.records ?? []) { event in
                    EventRow(event: event)
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { HarborBackground() }
        .anchorIOSListSurface()
        .navigationTitle(L10n.insights)
    }

    private var completedCount: Int {
        projection.session?.taskProcesses.filter { $0.status == .completed }.count ?? 0
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

struct HistoryView: View {
    let projection: SessionProjection
    let onOpen: (UUID) -> Void
    @State private var log = AnchoringLog.shared

    var body: some View {
        let days = log.history(now: .now)
        List {
            if !days.isEmpty {
                Section(AnchorStrings.value("home.anchoring.history", default: "Anchoring")) {
                    ForEach(days, id: \.day) { day in
                        LabeledContent {
                            Text(Duration.seconds(day.seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                                .monospacedDigit()
                        } label: {
                            Text(day.day, format: .dateTime.month().day().weekday())
                        }
                        .listRowBackground(AnchorIOSStyle.surface)
                    }
                }
            }
            ForEach(projection.archivedSessions) { session in
                Button { onOpen(session.id) } label: {
                    HistoryRow(session: session)
                }
                .buttonStyle(AnchorPressButtonStyle())
                .accessibilityIdentifier("history.row.\(session.id.uuidString)")
                .listRowBackground(AnchorIOSStyle.surface)
            }
        }
        .overlay {
            if projection.archivedSessions.isEmpty, days.isEmpty {
                ContentUnavailableView(
                    L10n.history,
                    systemImage: "clock",
                    description: Text(L10n.historyEmptyDetail)
                )
            }
        }
        .anchorIOSListSurface()
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
                if let session { AnchorSavedPlan(goal: session.goal) }
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
                if let recaps = session?.returnRecaps, !recaps.isEmpty {
                    Text(ReturnHistoryCopy.title).font(.title2.bold())
                    ForEach(recaps.reversed()) { ReturnRecapHistoryCard(recap: $0) }
                }
                if let session, !session.records.isEmpty {
                    Text(L10n.activity).font(.title2.bold())
                    ForEach(session.records) { event in
                        EventRow(event: event)
                    }
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background { HarborBackground() }
        .anchorIOSListSurface()
        .navigationTitle(L10n.sessionSummary)
        .accessibilityIdentifier("history.detail.screen")
    }

    private var session: AnchorSession? { projection.archivedSession(id: sessionID) }
}

/// One return's conversation recaps, as the return page showed them.
private struct ReturnRecapHistoryCard: View {
    let recap: ReturnRecap

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(recap.returnedAt, format: .dateTime.month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
            if recap.conversations.isEmpty {
                Text(ReturnCopy.noConversations)
                    .font(.subheadline)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            ForEach(recap.conversations) { conversation in
                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.name).font(.subheadline.weight(.semibold))
                    Text(conversation.text)
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(AnchorSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 18))
    }
}

enum ReturnHistoryCopy {
    static let title = AnchorStrings.value("history.return.recaps", default: "When you came back")
}

struct TaskManagementView: View {
    let model: AnchorSessionModel
    private let taskID: UUID?
    @State private var processes: [AnchorProcess]

    init(model: AnchorSessionModel) {
        self.model = model
        taskID = model.projection.session?.id
        _processes = State(initialValue: model.projection.session?.taskProcesses ?? [])
    }

    var body: some View {
        List {
            Section {
                Text(L10n.moveHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(AnchorIOSStyle.surface)
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
                    Task { await sendOwned(.reorderProcesses(processes.map(\.id))) }
                }
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.taskManagement)
        .toolbar { EditButton() }
    }

    private func updateSize(_ processID: UUID, size: ProcessTileSize) {
        guard let index = processes.firstIndex(where: { $0.id == processID }) else { return }
        processes[index].tileSize = size
        Task { await sendOwned(.updateTileSize(processID: processID, size: size)) }
    }
    private func sendOwned(_ command: SessionCommand) async -> Bool {
        guard let taskID else { return false }
        return await model.send(.forSession(taskID, command))
    }

}

struct FinishSessionView: View {
    let model: AnchorSessionModel
    private let taskID: UUID?

    init(model: AnchorSessionModel) {
        self.model = model
        taskID = model.projection.session?.id
    }

    private var session: AnchorSession? {
        model.projection.hostedSessions.first { $0.id == taskID }
    }
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
                            Text(session?.goal.title ?? "")
                                .font(.title2.bold())
                            Label(L10n.processCount(session?.taskProcesses.count ?? 0), systemImage: "square.grid.2x2")
                            Label(L10n.noteCount(session?.notes.count ?? 0), systemImage: "bookmark")
                            Label(L10n.decisionCount(session?.decisions.filter { $0.status == .resolved }.count ?? 0), systemImage: "checkmark.bubble")
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
            .background { HarborBackground() }
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
                    guard let taskID, await model.send(.forSession(taskID, .completeSession)) else { return }
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
