#if os(iOS)
  import AnchorCore
  import AnchorDesign
  import SwiftUI

  /// Dropping an anchor: a title, an optional plan, and a slide to let go.
  /// Saving never waits for the Mac; the anchor syncs once it connects.
  struct AnchorSetupView: View {
    let model: AnchorSessionModel
    @Bindable var draft: AnchorSetupDraft
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: AnchorSetupField?
    @State private var speechInput = SpeechInputController()
    @State private var speechField: AnchorSetupField?
    @State private var showsDiscardConfirmation = false
    @State private var saving = false
    @State private var saveError: String?
    @State private var titleMoved = false

    var body: some View {
      VStack(spacing: 0) {
        AnchorSetupHeader(close: dismiss.callAsFunction)
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            AnchorSetupInput(
              draft: draft, speech: speechInput, focus: $focus,
              titleMoved: titleMoved, beginSpeech: beginSpeech, endSpeech: speechInput.finish)
            AnchorDropSlider(
              enabled: draft.isValid && !draft.isImportingImages, saving: saving,
              stepCount: draft.steps.count, onDrop: saveTask)
              .padding(.top, 10)
            if let saveError {
              Text(saveError).font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
                .accessibilityIdentifier("setup.save.error")
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 6)
          .padding(.bottom, 24)
          .frame(maxWidth: 580)
          .frame(maxWidth: .infinity)
        }
        // The keyboard stays while text is corrected; "Done editing" puts it away.
        .scrollDismissesKeyboard(.never)
        bottomControls.fixedSize(horizontal: false, vertical: true)
      }
      .background {
        AnchorSetupStyle.background
          .overlay(alignment: .bottom) { AnchorSetupWave().frame(height: 100) }
          .ignoresSafeArea()
      }
      .toolbar(.hidden, for: .navigationBar)
      // A new anchor starts at its title, as a new reminder does.
      .task { if !draft.hasContent { focus = .title } }
      .onChange(of: speechInput.transcript) { _, transcript in
        switch speechField {
        case .title: draft.goalTitle = transcript
        case .plan: draft.actionPlan = transcript
        case nil: break
        }
      }
      .onChange(of: speechInput.isRecording) { _, isRecording in
        if !isRecording, speechField == .title { settleTitle() }
      }
      .onChange(of: draft.goalTitle) { _, title in
        // Return in the title moves on to the plan; pasted lines go with it.
        guard title.contains(where: \.isNewline) else { return }
        settleTitle()
        focus = .plan
      }
      .onChange(of: focus) { previous, current in
        if current != nil { speechInput.stop() }
        if current == .title { titleMoved = false }
        if previous == .title, current != .title { settleTitle() }
      }
      .onDisappear { speechInput.stop() }
      .interactiveDismissDisabled(focus != nil || saving || draft.isImportingImages)
      .disabled(saving)
      .confirmationDialog(SetupCopy.discardDraftQuestion, isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
        Button(SetupCopy.discardDraft, role: .destructive) {
          speechInput.stop()
          speechField = nil
          draft.isConsumed = true
          dismiss()
        }
        .accessibilityIdentifier("setup.draft.discard.confirm")
        Button(L10n.cancel, role: .cancel) { }
      }
    }

    @ViewBuilder private var bottomControls: some View {
      if focus != nil {
        HStack {
          Spacer(minLength: 0)
          Button(SetupCopy.doneEditing) { focus = nil }
            .buttonStyle(.glass)
            .tint(AnchorSetupStyle.accent)
            .accessibilityIdentifier("setup.keyboard.done")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      } else if draft.hasContent {
        HStack(spacing: 12) {
          Spacer(minLength: 0)
          Button(SetupCopy.discardDraft, role: .destructive) {
            showsDiscardConfirmation = true
          }
          .font(.caption).frame(minHeight: 44)
          .fixedSize(horizontal: true, vertical: false)
          .disabled(draft.isImportingImages)
          .accessibilityIdentifier("setup.draft.discard")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: 580)
        .frame(maxWidth: .infinity)
      }
    }

    private var canDrop: Bool { draft.isValid && !draft.isImportingImages && !saving }

    private func settleTitle() {
      if draft.settleTitle() { titleMoved = true }
    }

    /// Dictation goes to the title while there is none, then to the plan.
    private func beginSpeech() {
      focus = nil
      speechField = draft.isValid ? .plan : .title
      speechInput.start(initialText: speechField == .title ? draft.goalTitle : draft.actionPlan)
    }

    private func saveTask() {
      guard canDrop else { return }
      speechInput.stop()
      speechField = nil
      // A title that moved words into the plan is shown before it is saved.
      if draft.settleTitle() {
        titleMoved = true
        return
      }
      focus = nil
      saving = true
      saveError = nil
      Task {
        defer { saving = false }
        do {
          let images = draft.imageData
          let goalID = draft.goalID
          let names = try await Task.detached(priority: .userInitiated) {
            try AnchorPlanImages.save(images, goalID: goalID)
          }.value
          let goal = AnchorGoal(
            id: draft.goalID,
            title: draft.goalTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            completionCriteria: "",
            note: draft.originalText,
            userPlan: AnchorUserPlan(steps: draft.steps, localImageNames: names))
          // A personal plan can start without any linked computer process.
          if await model.hostTask(id: draft.hostedTaskID, goal: goal, processes: []) {
            draft.wasCreated = true
            draft.isConsumed = true
            dismiss()
          } else {
            saveError = SetupCopy.saveFailed
          }
        } catch { saveError = SetupCopy.saveFailed }
      }
    }
  }
#endif
