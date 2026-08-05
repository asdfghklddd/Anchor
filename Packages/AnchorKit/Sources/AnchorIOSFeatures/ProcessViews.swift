#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProcessDetailView: View {
    let process: AnchorProcess
    let decision: Decision?
    let onDecision: (UUID) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                AnchorCard(tint: AnchorPalette.source(process.sourceTone)) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        HStack {
                            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 48)
                            VStack(alignment: .leading) {
                                Text(process.sourceName).font(.headline)
                                StatusBadge(status: process.status, text: L10n.status(process.status))
                            }
                        }
                        Text(process.title)
                            .font(.largeTitle.bold())
                        Text(process.detail)
                            .font(.title3)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading) {
                                Text(process.metric)
                                    .font(.title.bold().monospacedDigit())
                                Text(process.metricLabel)
                                    .font(.caption)
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(L10n.estimated).font(.caption)
                                Text(process.estimatedCompletion)
                                    .font(.subheadline.bold())
                            }
                        }
                        if let progress = process.progress {
                            AnchorProgress(value: progress, tint: AnchorPalette.source(process.sourceTone))
                        }
                    }
                }

                if let decision {
                    Button {
                        onDecision(decision.id)
                    } label: {
                        Label(L10n.attentionNeeded, systemImage: "exclamationmark.bubble.fill")
                    }
                    .buttonStyle(AnchorPrimaryButtonStyle())
                }

                Text(L10n.activity)
                    .font(.title2.bold())
                if process.events.isEmpty {
                    ContentUnavailableView(L10n.noEvents, systemImage: "waveform.path.ecg")
                } else {
                    ForEach(process.events.sorted { $0.occurredAt > $1.occurredAt }) { event in
                        EventRow(event: event)
                    }
                }
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .navigationTitle(process.sourceName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DecisionView: View {
    let model: AnchorSessionModel
    let decision: Decision

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOptionID: UUID?
    @State private var feedbackTrigger = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        StatusBadge(status: .needsDecision, text: L10n.attentionNeeded)
                        Text(decision.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AnchorPalette.ink)
                        Text(decision.prompt)
                            .font(.title3)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                    ForEach(decision.options) { option in
                        Button {
                            selectedOptionID = option.id
                        } label: {
                            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                                Image(systemName: selectedOptionID == option.id ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selectedOptionID == option.id ? AnchorPalette.deepSea : AnchorPalette.secondaryInk)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(option.title)
                                        .font(.headline)
                                    Text(option.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(AnchorPalette.secondaryInk)
                                }
                                Spacer()
                            }
                            .foregroundStyle(AnchorPalette.ink)
                            .padding(AnchorSpacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedOptionID == option.id
                                    ? AnchorPalette.sand.opacity(0.34)
                                    : AnchorPalette.surface,
                                in: .rect(cornerRadius: 20, style: .continuous)
                            )
                            .overlay {
                                if selectedOptionID == option.id {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(AnchorPalette.sand, lineWidth: 3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                    }
                    Button(L10n.confirmChoice) {
                        guard let selectedOptionID,
                              let option = decision.options.first(where: { $0.id == selectedOptionID }) else { return }
                        feedbackTrigger += 1
                        Task {
                            await model.resolve(decision: decision, option: option)
                            dismiss()
                        }
                    }
                    .buttonStyle(AnchorPrimaryButtonStyle())
                    .disabled(selectedOptionID == nil)
                    .sensoryFeedback(.success, trigger: feedbackTrigger)
                    .accessibilityIdentifier("decision.confirm.button")
                }
                .padding(AnchorSpacing.large)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .background(AnchorPalette.paper)
            .navigationTitle(L10n.chooseDirection)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(L10n.cancel)
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("decision.screen")
    }
}

struct AnchorNoteView: View {
    let model: AnchorSessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var savedTrigger = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                HStack(spacing: AnchorSpacing.medium) {
                    AnchorMark(size: 52)
                    VStack(alignment: .leading) {
                        Text(L10n.anchorNote).font(.title2.bold())
                        Text(L10n.anchorNotePrompt)
                            .font(.subheadline)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }
                TextEditor(text: $note)
                    .font(.body)
                    .focused($isFocused)
                    .padding(AnchorSpacing.small)
                    .scrollContentBackground(.hidden)
                    .background(AnchorPalette.surface, in: .rect(cornerRadius: 18))
                    .accessibilityLabel(L10n.anchorNotePrompt)
                Label(L10n.setupHint, systemImage: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                Button(L10n.save) {
                    savedTrigger += 1
                    Task {
                        await model.addNote(note)
                        dismiss()
                    }
                }
                .buttonStyle(AnchorPrimaryButtonStyle())
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .sensoryFeedback(.success, trigger: savedTrigger)
            }
            .padding(AnchorSpacing.large)
            .background(AnchorPalette.paper)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

struct GoalEditorView: View {
    let model: AnchorSessionModel
    let goal: AnchorGoal

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var criteria: String
    @State private var note: String

    init(model: AnchorSessionModel, goal: AnchorGoal) {
        self.model = model
        self.goal = goal
        _title = State(initialValue: goal.title)
        _criteria = State(initialValue: goal.completionCriteria)
        _note = State(initialValue: goal.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.currentGoal) {
                    TextField(L10n.goalTitle, text: $title, axis: .vertical)
                    TextField(L10n.completionCriteria, text: $criteria, axis: .vertical)
                    TextField(L10n.contextNote, text: $note, axis: .vertical)
                }
                Section {
                    Label(L10n.setupHint, systemImage: "mic.fill")
                }
            }
            .navigationTitle(L10n.editGoal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        Task {
                            await model.send(.updateGoal(title: title, completionCriteria: criteria, note: note))
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct NotificationsView: View {
    let projection: SessionProjection
    let onOpenProcess: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(projection.session?.timeline ?? []) { event in
                Button {
                    if let processID = event.processID { onOpenProcess(processID) }
                } label: {
                    EventRow(event: event)
                }
                .buttonStyle(.plain)
                .disabled(event.processID == nil)
            }
            .overlay {
                if projection.session?.timeline.isEmpty != false {
                    ContentUnavailableView(L10n.noEvents, systemImage: "bell.slash")
                }
            }
            .navigationTitle(L10n.notifications)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
}

struct EventRow: View {
    let event: ProcessEvent

    var body: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            Image(systemName: eventSymbol(event.kind))
                .foregroundStyle(AnchorPalette.coral)
                .frame(width: 34, height: 34)
                .background(AnchorPalette.coral.opacity(0.15), in: .rect(cornerRadius: 11))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
                Text(event.occurredAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AnchorSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}
#endif
