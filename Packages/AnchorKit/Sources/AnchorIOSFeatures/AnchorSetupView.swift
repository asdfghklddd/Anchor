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
    @Environment(\.anchorTour) private var tour
    @FocusState private var focus: AnchorSetupField?
    @State private var speechInput = SpeechInputController()
    @State private var speechField: AnchorSetupField?
    @State private var showsDiscardConfirmation = false
    @State private var saving = false
    @State private var saveError: String?
    @State private var titleMoved = false
    /// The tour's line being read aloud: the title, then the plan.
    @State private var reading: AnchorSetupField?
    @State private var heard = TourReadAlong(heard: "", line: "")
    /// The last try was not heard; the pet asks again.
    @State private var missed = false
    /// The tour reads the rest itself, for someone who cannot talk now.
    @State private var readsForPerson = false

    var body: some View {
      VStack(spacing: 0) {
        AnchorSetupHeader(close: dismiss.callAsFunction)
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            if tour != nil { tourLine }
            AnchorSetupInput(
              draft: draft, speech: speechInput, focus: $focus,
              titleMoved: titleMoved,
              readAlong: reading.map { ($0, Self.line(for: $0), heard.lit) },
              beginSpeech: beginSpeech, endSpeech: speechInput.finish)
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
      .task {
        guard !draft.hasContent else { return }
        if tour != nil { reading = .title } else { focus = .title }
      }
      .onChange(of: speechInput.transcript) { _, transcript in
        if let reading, !readsForPerson {
          hear(transcript, reading: reading)
          return
        }
        switch speechField {
        case .title: draft.goalTitle = transcript
        case .plan: draft.actionPlan = transcript
        case nil: break
        }
      }
      .onChange(of: speechInput.isRecording) { _, isRecording in
        if !isRecording, let reading, speechField == reading, !readsForPerson {
          // The person stopped: most of the line is enough; otherwise once more.
          speechField = nil
          if TourReadAlong(heard: speechInput.transcript, line: Self.line(for: reading)).isEnough {
            accept(reading)
          } else {
            missed = true
          }
          return
        }
        if !isRecording, speechField == .title { settleTitle() }
      }
      // Without a microphone or the permission for it, the tour reads for them.
      .onChange(of: speechInput.errorMessage) { _, error in
        if error != nil, reading != nil { readForPerson() }
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

    // MARK: Reading aloud in the tour

    /// The pet says what to do: read the title, then the plan, then slide.
    /// Under it, a way out for someone who cannot talk right now.
    private var tourLine: some View {
      VStack(alignment: .trailing, spacing: 4) {
        TourPetLine(text: tourText, act: reading == nil ? .happy : .idle)
          .frame(maxWidth: .infinity, alignment: .leading)
        if reading != nil, !readsForPerson {
          Button(TourCopy.readForMe, action: readForPerson)
            .font(.footnote.weight(.medium))
            .foregroundStyle(AnchorIOSStyle.action)
            .frame(minHeight: 44)
            .accessibilityIdentifier("tour.read.skip")
        }
      }
    }

    private var tourText: String {
      if readsForPerson, reading != nil { return TourCopy.readingForYou }
      return switch reading {
      case .title: missed ? TourCopy.readAgain : TourCopy.readTitle
      case .plan: missed ? TourCopy.readAgain : TourCopy.readPlan
      case nil: TourCopy.slide
      }
    }

    private static func line(for field: AnchorSetupField) -> String {
      field == .title ? TourCopy.spokenTitle : TourCopy.spokenPlan
    }

    /// The line lights as far as the voice has reached; most of it heard is enough.
    private func hear(_ transcript: String, reading: AnchorSetupField) {
      let heard = TourReadAlong(heard: transcript, line: Self.line(for: reading))
      withAnimation(AnchorMotion.micro) { self.heard = heard }
      if heard.isRead { accept(reading) }
    }

    /// The line goes in whole, a bell rings, and the next line is up.
    private func accept(_ field: AnchorSetupField) {
      guard reading == field else { return }
      speechField = nil
      speechInput.stop()
      missed = false
      withAnimation(AnchorMotion.micro) {
        if field == .title { draft.goalTitle = Self.line(for: .title) } else { draft.actionPlan = Self.line(for: .plan) }
        heard = TourReadAlong(heard: "", line: "")
        reading = field == .title ? .plan : nil
      }
      // After the microphone has let go of the audio session.
      Task {
        try? await Task.sleep(for: .seconds(0.3))
        TourSound.shared.play(.ding)
      }
    }

    /// The tour says the rest itself, as dictation would hear it.
    private func readForPerson() {
      guard let first = reading, !readsForPerson else { return }
      readsForPerson = true
      missed = false
      speechInput.stop()
      Task {
        for field in first == .title ? [AnchorSetupField.title, .plan] : [.plan] {
          speechField = field
          guard await speechInput.play(Self.line(for: field)) else { break }
          try? await Task.sleep(for: .seconds(0.4))
        }
        speechField = nil
        withAnimation(AnchorMotion.micro) { reading = nil }
      }
    }

    /// Dictation goes to the title while there is none, then to the plan;
    /// in the tour, to the line being read.
    private func beginSpeech() {
      focus = nil
      if tour != nil {
        guard let reading, !readsForPerson else { return }
        speechField = reading
        speechInput.start(initialText: "")
        return
      }
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
