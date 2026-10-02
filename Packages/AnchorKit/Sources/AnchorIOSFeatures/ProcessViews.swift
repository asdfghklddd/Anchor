#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProcessDetailView: View {
    let process: AnchorProcess

    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                AnchorCard(tint: AnchorPalette.aiBlue) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        HStack {
                            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 48)
                            VStack(alignment: .leading) {
                                Text(process.sourceName).font(.headline)
                                StatusBadge(status: process.isInterrupted ? .blocked : process.status,
                                            text: L10n.processStatus(process))
                            }
                        }
                        Text(process.title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AnchorPalette.brandDeep)
                        Text(process.detail)
                            .font(.title3)
                            .foregroundStyle(AnchorPalette.secondaryText)
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading) {
                                Text(process.metric)
                                    .font(.title.bold().monospacedDigit())
                                    .foregroundStyle(AnchorPalette.brandDeep)
                                    .contentTransition(reduceMotion ? .opacity : .numericText())
                                    .animation(liveValueAnimation, value: process.metric)
                                Text(process.metricLabel)
                                    .font(.caption)
                                    .foregroundStyle(AnchorPalette.secondaryText)
                            }
                            Spacer()
                            if !process.estimatedCompletion.isEmpty, process.estimatedCompletion != "—" {
                                VStack(alignment: .trailing) {
                                    Text(L10n.estimated).font(.caption)
                                    Text(process.estimatedCompletion)
                                        .font(.subheadline.bold())
                                }
                            }
                        }
                        if let progress = process.progress {
                            AnchorProgress(value: progress, tint: AnchorPalette.interaction)
                                .animation(liveValueAnimation, value: progress)
                        }
                    }
                }

                Text(L10n.activity)
                    .font(.title2.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
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
        .background { HarborBackground() }
        .anchorIOSListSurface()
        .navigationTitle(process.sourceName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var liveValueAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.micro
    }
}

struct AnchorNoteView: View {
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
    @State private var submission = AnchorNoteSubmission()
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
                                if submission.text.isEmpty {
                                    Text(L10n.notePlaceholder)
                                        .font(.body)
                                        .foregroundStyle(AnchorPalette.secondaryInk.opacity(0.62))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $submission.text)
                                    .font(.body)
                                    .disabled(submission.isSaving)
                                    .accessibilityIdentifier("note.text.field")
                                    .focused($isFocused)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 126)
                                    .accessibilityLabel(L10n.momentToRemember)
                                    .onChange(of: submission.text) { _, newValue in
                                        if newValue.count > 140 { submission.text = String(newValue.prefix(140)) }
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
                                Text("\(submission.text.count)/140")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                        }

                        if let recent = session?.notes.first {
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

                        if submission.hasFailed {
                            Text(AnchorStrings.value("note.save.failed", default: "Could not save this note. Your text is still here. Please try again."))
                                .font(.caption).foregroundStyle(.red)
                                .accessibilityIdentifier("note.save.error")
                        }
                        Button {
                            Task {
                                let saved = await submission.save { text in
                                    guard let taskID else { return false }
                                    return await model.send(.forSession(taskID, .addNote(text)))
                                }
                                if saved { dismiss() }
                            }
                        } label: {
                            if submission.isSaving {
                                HStack {
                                    ProgressView()
                                    Text(SetupCopy.saving)
                                }
                            } else {
                                Label(L10n.dropAnchor, systemImage: "scope")
                            }
                        }
                        .buttonStyle(HarborPrimaryButtonStyle())
                        .disabled(!submission.canSave)
                        .accessibilityIdentifier("note.save.button")
                        .sensoryFeedback(.success, trigger: submission.successCount)
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.bottom, AnchorSpacing.large)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .anchorIOSListSurface()
            .navigationTitle(L10n.anchorNote)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) { Image(systemName: "xmark") }
                        .accessibilityLabel(L10n.cancel)
                        .disabled(submission.isSaving)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationCornerRadius(24)
        .interactiveDismissDisabled(submission.isSaving)
    }

    private var snapshotStrip: some View {
        let session = model.projection.session
        let running = session?.taskProcesses.filter { $0.status == .running }.count ?? 0
        let attention = session?.taskProcesses.filter { $0.status == .needsDecision }.count ?? 0
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
    private let taskID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var criteria: String
    @State private var note: String

    init(model: AnchorSessionModel, goal: AnchorGoal) {
        self.model = model
        self.goal = goal
        taskID = model.projection.hostedSessions.first { $0.goal.id == goal.id }?.id
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
            .listRowBackground(AnchorIOSStyle.surface)
                if goal.userPlan != nil {
                    Section { AnchorSavedPlan(goal: goal) }
                        .listRowBackground(AnchorIOSStyle.surface)
                }
                Section {
                    Label(L10n.setupHint, systemImage: "mic.fill")
                }
            .listRowBackground(AnchorIOSStyle.surface)
            }
            .anchorIOSListSurface()
            .navigationTitle(L10n.editGoal)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        Task {
                            guard let taskID, await model.send(.forSession(taskID, .updateGoal(title: title, completionCriteria: criteria, note: note))) else { return }
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
                .listRowBackground(AnchorIOSStyle.surface)
            }
            .overlay {
                if projection.session?.timeline.isEmpty != false {
                    ContentUnavailableView(L10n.noEvents, systemImage: "bell.slash")
                }
            }
            .anchorIOSListSurface()
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
