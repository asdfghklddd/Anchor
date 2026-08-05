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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedOptionID: UUID?
    @State private var feedbackTrigger = 0

    var body: some View {
        NavigationStack {
            ZStack {
                HarborBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        decisionHero
                        directionPanel
                        confirmButton
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.bottom, AnchorSpacing.xLarge)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(process?.sourceName ?? L10n.chooseDirection)
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
        .presentationCornerRadius(30)
        .onAppear { selectedOptionID = decision.options.dropFirst().first?.id ?? decision.options.first?.id }
    }

    private var decisionHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SourceMark(
                    symbol: process?.sourceSymbol ?? "?",
                    tone: process?.sourceTone ?? "periwinkle",
                    size: 48
                )
                VStack(alignment: .leading, spacing: 5) {
                    StatusBadge(status: .needsDecision, text: L10n.attentionNeeded)
                    Text(process?.title ?? decision.title)
                        .font(.title2.bold())
                        .foregroundStyle(AnchorPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 16) {
                StoryboardPreview(tint: AnchorPalette.source(process?.sourceTone ?? "periwinkle"))
                    .frame(width: 118, height: 86)
                VStack(alignment: .leading, spacing: 5) {
                    Text(process?.metric ?? "")
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.sourceInk(process?.sourceTone ?? "periwinkle"))
                    Text(process?.metricLabel ?? decision.prompt)
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Text(decision.prompt)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(
                LinearGradient(
                    colors: AnchorPalette.sourceSurface(process?.sourceTone ?? "periwinkle"),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: 24, style: .continuous)
            )
        }
        .padding(.top, 8)
    }

    private var directionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.attentionNeeded.uppercased())
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.link)
                        .accessibilityHidden(true)
                    Text(L10n.chooseVisualDirection)
                        .font(.title3.bold())
                        .foregroundStyle(AnchorPalette.ink)
                        .accessibilityIdentifier("decision.screen")
                }
                Spacer()
                Text("\((decision.options.firstIndex { $0.id == selectedOptionID } ?? 0) + 1) / \(decision.options.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            ForEach(Array(decision.options.enumerated()), id: \.element.id) { index, option in
                directionButton(option, index: index)
            }
        }
        .padding(14)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: AnchorPalette.deepSea.opacity(0.08), radius: 14, y: 8)
    }

    private func directionButton(_ option: DecisionOption, index: Int) -> some View {
        let selected = selectedOptionID == option.id
        return Button {
            selectedOptionID = option.id
        } label: {
            HStack(spacing: 12) {
                StoryboardPreview(
                    tint: index == 0 ? AnchorPalette.coral : index == 1 ? AnchorPalette.periwinkle : AnchorPalette.cyan,
                    compact: true
                )
                .frame(width: 72, height: 54)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(Character(UnicodeScalar(65 + index)!)) · \(option.title)")
                        .font(.subheadline.bold())
                        .foregroundStyle(AnchorPalette.ink)
                    Text(option.detail)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? AnchorPalette.deepSea : AnchorPalette.secondaryInk.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? AnchorPalette.warmYellow.opacity(0.72) : AnchorPalette.paper,
                in: .rect(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AnchorPalette.sand, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(option.detail)
    }

    private var confirmButton: some View {
        Button {
            guard let selectedOptionID,
                  let option = decision.options.first(where: { $0.id == selectedOptionID }) else { return }
            feedbackTrigger += 1
            Task {
                await model.resolve(decision: decision, option: option)
                dismiss()
            }
        } label: {
            HStack {
                Text(L10n.confirmChoice)
                Image(systemName: "chevron.right")
            }
            .accessibilityIdentifier("decision.confirm.label")
        }
        .buttonStyle(HarborPrimaryButtonStyle())
        .disabled(selectedOptionID == nil)
        .sensoryFeedback(.success, trigger: feedbackTrigger)
        .accessibilityIdentifier("decision.confirm.button")
    }

    private var process: AnchorProcess? {
        model.projection.session?.processes.first { $0.id == decision.processID }
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
            ZStack {
                HarborBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        HStack(spacing: 12) {
                            HarborBrandMark(size: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.currentWorkKicker)
                                    .font(.caption.bold())
                                    .foregroundStyle(AnchorPalette.link)
                                Text(L10n.anchorCaptureHeadline)
                                    .font(.title2.bold())
                                    .foregroundStyle(AnchorPalette.ink)
                            }
                        }

                        snapshotStrip

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.momentToRemember)
                                .font(.headline)
                                .foregroundStyle(AnchorPalette.ink)
                            ZStack(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text(L10n.notePlaceholder)
                                        .font(.body)
                                        .foregroundStyle(AnchorPalette.secondaryInk.opacity(0.62))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $note)
                                    .font(.body)
                                    .focused($isFocused)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 126)
                                    .accessibilityLabel(L10n.momentToRemember)
                                    .onChange(of: note) { _, newValue in
                                        if newValue.count > 140 { note = String(newValue.prefix(140)) }
                                    }
                            }
                            .padding(10)
                            .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
                            .shadow(color: AnchorPalette.deepSea.opacity(0.08), radius: 12, y: 7)

                            HStack {
                                Button {
                                    isFocused = true
                                } label: {
                                    Label(L10n.keyboardDictation, systemImage: "mic.fill")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 36)
                                        .background(AnchorPalette.cyan.opacity(0.14), in: .capsule)
                                }
                                .buttonStyle(.plain)
                                Spacer()
                                Text("\(note.count)/140")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                        }

                        if let recent = model.projection.session?.notes.first {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(L10n.recentAnchor, systemImage: "checkmark.circle.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(AnchorPalette.mintInk)
                                Text(recent.text)
                                    .font(.subheadline)
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AnchorPalette.seafoam.opacity(0.17), in: .rect(cornerRadius: 18, style: .continuous))
                        }

                        Button {
                            savedTrigger += 1
                            Task {
                                await model.addNote(note)
                                dismiss()
                            }
                        } label: {
                            Label(L10n.dropAnchor, systemImage: "scope")
                        }
                        .buttonStyle(HarborPrimaryButtonStyle())
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .sensoryFeedback(.success, trigger: savedTrigger)
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.bottom, AnchorSpacing.large)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.anchorNote)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) { Image(systemName: "xmark") }
                        .accessibilityLabel(L10n.cancel)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationCornerRadius(30)
    }

    private var snapshotStrip: some View {
        let session = model.projection.session
        let running = session?.processes.filter { $0.status == .running }.count ?? 0
        let attention = session?.processes.filter { $0.status == .needsDecision }.count ?? 0
        return HStack(spacing: 0) {
            snapshotCell(symbol: "mappin.and.ellipse", label: L10n.currentGoal, value: session?.goal.title ?? "")
            Divider().padding(.vertical, 10)
            snapshotCell(symbol: "waveform.path.ecg", label: L10n.currentSnapshot, value: L10n.runningAndWaiting(running: running, attention: attention))
        }
        .padding(.vertical, 5)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
        .shadow(color: AnchorPalette.deepSea.opacity(0.07), radius: 10, y: 6)
    }

    private func snapshotCell(symbol: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(AnchorPalette.link)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(AnchorPalette.secondaryInk)
                Text(value).font(.caption.bold()).foregroundStyle(AnchorPalette.ink).lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
