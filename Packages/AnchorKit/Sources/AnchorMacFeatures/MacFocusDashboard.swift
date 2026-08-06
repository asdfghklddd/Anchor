#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacFocusDashboard: View {
    let model: AnchorSessionModel
    let onOpenTimeline: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        if let session = model.projection.session {
            MacActiveWorkView(
                model: model,
                session: session,
                onOpenTimeline: onOpenTimeline
            )
        } else {
            MacEmptyWorkView(
                projection: model.projection,
                onOpenTimeline: onOpenTimeline,
                onOpenSettings: onOpenSettings
            )
        }
    }
}

private struct MacActiveWorkView: View {
    let model: AnchorSessionModel
    let session: AnchorSession
    let onOpenTimeline: () -> Void

    @State private var selectedProcessID: UUID?
    @State private var selectedOptionID: UUID?
    @State private var note = ""
    @State private var showingNoteComposer = false
    @State private var showingSessionSummary = false
    @State private var showingGoalEditor = false
    @State private var showingProcessManagement = false
    @State private var shouldScrollToProcessWorkspace = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.xLarge) {
                    MacFocusHeader(session: session, projection: model.projection)

                    if session.status == .completed {
                        MacCompletionBanner(
                            session: session,
                            onResume: resumeSession
                        )
                    }

                    if session.presence == .away || session.presence == .returning {
                        MacReturnMemoryView(
                            session: session,
                            projection: model.projection,
                            onOpenProcess: openProcess,
                            onContinue: continueWorking
                        )
                    } else if session.presence != .atDesk {
                        MacPresenceBanner(
                            presence: session.presence,
                            summary: session.returnSummary,
                            onContinue: continueWorking
                        )
                    }

                    if session.status != .completed, showsPriorityAction {
                        MacPriorityCard(session: session) { processID in
                            openProcess(processID)
                        }
                    }

                    MacGoalHero(session: session, progress: model.projection.overallProgress)

                    MacProcessWorkspace(
                        session: session,
                        selectedProcessID: $selectedProcessID,
                        selectedOptionID: $selectedOptionID,
                        onResolve: resolve
                    )
                    .id("mac.process.workspace")

                    MacEventStrip(
                        events: Array(session.timeline.prefix(5)),
                        processes: session.processes,
                        onOpenTimeline: onOpenTimeline
                    )
                }
                .frame(maxWidth: 1360, alignment: .leading)
                .padding(.horizontal, AnchorSpacing.xLarge)
                .padding(.vertical, AnchorSpacing.large)
            }
            .onChange(of: shouldScrollToProcessWorkspace) { _, shouldScroll in
                guard shouldScroll else { return }
                shouldScrollToProcessWorkspace = false
                withAnimation(reduceMotion ? nil : .snappy) {
                    proxy.scrollTo("mac.process.workspace", anchor: .top)
                }
            }
        }
        .background(HarborBackground())
        .navigationTitle(L10n.currentWork)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingGoalEditor = true
                } label: {
                    Label(L10n.editGoal, systemImage: "pencil")
                }
                .accessibilityIdentifier("mac.goal.edit.button")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingProcessManagement = true
                } label: {
                    Label(L10n.taskManagement, systemImage: "square.grid.2x2")
                }
                .accessibilityIdentifier("mac.process.management.button")
            }
            ToolbarItem {
                Button {
                    showingSessionSummary = true
                } label: {
                    Label(
                        session.status == .completed ? L10n.sessionSummary : L10n.finish,
                        systemImage: "checkmark.seal"
                    )
                }
            }
            ToolbarItem {
                Button {
                    showingNoteComposer = true
                } label: {
                    Label(L10n.anchorNote, systemImage: "scope")
                }
                .keyboardShortcut("n")
            }
        }
        .sheet(isPresented: $showingNoteComposer) {
            MacNoteComposer(note: $note, onSave: saveNote)
        }
        .sheet(isPresented: $showingGoalEditor) {
            MacGoalEditorView(model: model, goal: session.goal)
        }
        .sheet(isPresented: $showingProcessManagement) {
            MacProcessManagementView(model: model)
        }
        .sheet(isPresented: $showingSessionSummary) {
            MacSessionSummaryView(model: model)
        }
        .onAppear {
            selectInitialProcess()
        }
        .onChange(of: session.id) { _, _ in
            selectInitialProcess()
        }
        .onChange(of: model.projection.openDecisions) { oldDecisions, newDecisions in
            updateSelection(for: oldDecisions, and: newDecisions)
        }
        .accessibilityIdentifier("mac.current.screen")
    }

    private func selectInitialProcess() {
        guard !session.processes.isEmpty else {
            selectedProcessID = nil
            return
        }

        let decisionProcessID = session.decisions.first(where: { $0.status == .open })?.processID
        selectedProcessID = selectedProcessID.flatMap { id in
            session.processes.contains(where: { $0.id == id }) ? id : nil
        } ?? decisionProcessID
    }

    private func openProcess(_ processID: UUID) {
        selectedProcessID = processID
        selectedOptionID = nil
        shouldScrollToProcessWorkspace = true
    }

    private func resolve(_ decision: Decision, option: DecisionOption) {
        selectedOptionID = nil
        Task {
            await model.resolve(decision: decision, option: option)
        }
    }

    private func continueWorking() {
        Task {
            await model.continueWorking()
        }
    }

    private func saveNote() {
        let captured = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !captured.isEmpty else { return }
        note = ""
        showingNoteComposer = false
        Task {
            await model.addNote(captured)
        }
    }

    private func resumeSession() {
        Task {
            await model.send(.resumeSession)
        }
    }

    private func updateSelection(for oldDecisions: [Decision], and newDecisions: [Decision]) {
        if let decision = newDecisions.first {
            selectedProcessID = decision.processID
            selectedOptionID = nil
        } else if !oldDecisions.isEmpty {
            selectedProcessID = nil
            selectedOptionID = nil
        }
    }

    private var showsPriorityAction: Bool {
        !model.projection.openDecisions.isEmpty || session.processes.contains { process in
            process.status == .needsDecision || process.status == .blocked || process.status == .failed
        }
    }
}

private struct MacFocusHeader: View {
    let session: AnchorSession
    let projection: SessionProjection

    private var runningCount: Int {
        session.processes.filter { $0.status == .running }.count
    }

    private var attentionCount: Int {
        session.processes.filter { $0.status == .needsDecision }.count
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 0..<11: L10n.greetingMorning
        case 11..<18: L10n.greetingAfternoon
        default: L10n.greetingEvening
        }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AnchorSpacing.large) {
                focusCopy
                Spacer(minLength: AnchorSpacing.large)
                focusMetrics
            }

            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                focusCopy
                focusMetrics
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var focusCopy: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text("\(greeting) · \(L10n.focusSession)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AnchorPalette.deepSea)
                .textCase(.uppercase)
            Text(L10n.focusHeadline)
                .font(.largeTitle.bold())
                .foregroundStyle(AnchorPalette.ink)
            Text(L10n.focusSummary(running: runningCount, attention: attentionCount))
                .font(.title3)
                .foregroundStyle(AnchorPalette.secondaryInk)
        }
    }

    private var focusMetrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AnchorSpacing.small) {
                progressMetric
                processesMetric
                attentionMetric
            }

            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                progressMetric
                processesMetric
                attentionMetric
            }
        }
    }

    private var progressMetric: some View {
        MacFocusMetric(
            value: progressText,
            label: L10n.overallProgress,
            tint: AnchorPalette.seafoam
        )
    }

    private var processesMetric: some View {
        MacFocusMetric(
            value: Text("\(session.processes.count)"),
            label: L10n.processes,
            tint: AnchorPalette.cyan
        )
    }

    private var attentionMetric: some View {
        MacFocusMetric(
            value: Text("\(attentionCount)"),
            label: L10n.attentionNeeded,
            tint: attentionCount > 0 ? AnchorPalette.sand : AnchorPalette.seafoam
        )
    }

    private var progressText: Text {
        guard let progress = projection.overallProgress else {
            return Text(L10n.unknown)
        }
        return Text(progress, format: .percent.precision(.fractionLength(0)))
    }
}

private struct MacFocusMetric: View {
    let value: Text
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            value
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(2)
        }
        .frame(minWidth: 92, alignment: .leading)
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.vertical, AnchorSpacing.small)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct MacPresenceBanner: View {
    let presence: PresenceStatus
    let summary: ReturnSummary?
    let onContinue: () -> Void

    private var title: String {
        switch presence {
        case .handingOff: L10n.handoff
        case .away: L10n.away
        case .returning: L10n.returning
        case .unknown, .atDesk: L10n.connectionUnknown
        }
    }

    private var detail: String {
        switch presence {
        case .handingOff: L10n.handoffDetail
        case .away: L10n.awayDetail
        case .returning: summary?.changes.first?.detail ?? L10n.returnDetail
        case .unknown, .atDesk: L10n.connectionUnknownDetail
        }
    }

    private var tint: Color {
        switch presence {
        case .returning: AnchorPalette.seafoam
        case .away, .handingOff: AnchorPalette.cyan
        case .unknown, .atDesk: AnchorPalette.sand
        }
    }

    private var symbol: String {
        switch presence {
        case .returning: "arrow.counterclockwise"
        case .away: "moon.stars.fill"
        case .handingOff: "arrow.triangle.branch"
        case .unknown, .atDesk: "questionmark.circle"
        }
    }

    var body: some View {
        HStack(spacing: AnchorSpacing.medium) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: AnchorSpacing.medium)

            if presence == .away || presence == .returning {
                Button(L10n.continueWorking, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.deepSea)
            }
        }
        .padding(AnchorSpacing.medium)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

#endif
