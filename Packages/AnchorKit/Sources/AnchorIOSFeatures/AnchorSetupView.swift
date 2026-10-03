#if os(iOS)
  import AnchorCore
  import AnchorDesign
  import SwiftUI

  struct AnchorSetupView: View {
    let model: AnchorSessionModel
    @Bindable var draft: AnchorSetupDraft
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editing: Bool
    @State private var speechInput = SpeechInputController()
    @State private var speechSegment: AnchorSetupSegment?
    @State private var showsDiscardConfirmation = false
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
      GeometryReader { geometry in
        VStack(spacing: 0) {
        ScrollViewReader { scroll in
          ScrollView {
            VStack(spacing: 0) {
              AnchorSetupHeader(
                reviewing: draft.isReviewing,
                canGoBack: draft.isReviewing || draft.segment != .goal,
                back: goBack, close: dismiss.callAsFunction
              )
              .id("top")
              if draft.isReviewing {
                AnchorSetupReview(draft: draft, edit: edit)
              } else {
                AnchorSetupInput(
                  draft: draft, speech: speechInput,
                  height: draft.isKeyboardEditing
                    ? max(210, min(240, geometry.size.height - 210)) : AnchorSetupStyle.inputHeight,
                  changeSegment: changeSegment, toggleSpeech: toggleSpeech, editing: $editing)
              }
              if let saveError {
                Text(saveError).font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
                  .padding(.top, 12).accessibilityIdentifier("setup.save.error")
              }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: 580)
            .frame(maxWidth: .infinity)
          }
          .scrollDismissesKeyboard(.never)
          .onChange(of: draft.segment) { scroll.scrollTo("top", anchor: .top) }
          .onChange(of: draft.isReviewing) { scroll.scrollTo("top", anchor: .top) }
        }
        .frame(maxHeight: .infinity)
        .clipped()
        bottomControls.fixedSize(horizontal: false, vertical: true)
        }
      }
      .background {
        (draft.isReviewing ? AnchorSetupStyle.reviewBackground : AnchorSetupStyle.background)
          .overlay(alignment: .bottom) {
            if !draft.isReviewing { AnchorSetupWave().frame(height: 100) }
          }
          .ignoresSafeArea()
      }
      .toolbar(.hidden, for: .navigationBar)
      .onChange(of: speechInput.transcript) { _, transcript in
        guard let speechSegment else { return }
        draft.setText(transcript, for: speechSegment)
      }
      .onChange(of: editing) { _, isEditing in
        draft.isKeyboardEditing = isEditing
        if isEditing { speechInput.stop() }
      }
      .onDisappear { speechInput.stop() }
      .interactiveDismissDisabled(editing || saving || draft.isImportingImages)
      .disabled(saving)
      .confirmationDialog(SetupCopy.discardDraftQuestion, isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
        Button(SetupCopy.discardDraft, role: .destructive) {
          speechInput.stop()
          speechSegment = nil
          draft.isConsumed = true
          dismiss()
        }
        .accessibilityIdentifier("setup.draft.discard.confirm")
        Button(L10n.cancel, role: .cancel) { }
      }
    }

    @ViewBuilder private var bottomControls: some View {
        if editing {
          keyboardControls
        } else if draft.isReviewing || !draft.isKeyboardEditing {
          VStack(spacing: 8) {
            Button(action: advance) {
              HStack {
                if saving {
                  ProgressView()
                } else if draft.isReviewing {
                  Image(systemName: "play.fill")
                }
                Text(buttonTitle).font(.subheadline.bold())
              }
              .frame(maxWidth: .infinity, minHeight: 44)
              .foregroundStyle(canAdvance ? AnchorIOSStyle.onAccent : AnchorSetupStyle.secondary)
              .tint(AnchorIOSStyle.onAccent)
              .background(AnchorSetupStyle.accent.opacity(canAdvance ? 1 : 0.15), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance || saving)
            .accessibilityIdentifier(draft.isReviewing ? "setup.start.button" : "setup.next.button")
            .padding(.horizontal, 20)
            .frame(maxWidth: draft.isReviewing ? 580 : 190)
            if draft.hasContent {
              HStack(spacing: 12) {
                Text(SetupCopy.draftKept).font(.caption)
                  .foregroundStyle(AnchorIOSStyle.secondaryText)
                  .fixedSize(horizontal: false, vertical: true)
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
              .frame(maxWidth: 580)
            }
          }
          .padding(.top, 8)
          .padding(.bottom, draft.isReviewing ? 12 : 70)
          .frame(maxWidth: .infinity)
          .background { if draft.isReviewing { AnchorSetupStyle.reviewBottom } }
        }
    }

    // Keep these controls in the sheet's safe area so every focus path shows
    // them, including tapping recognized text and reopening a review segment.
    private var keyboardControls: some View {
      GlassEffectContainer(spacing: 12) {
        HStack(spacing: 12) {
          Button(SetupCopy.newLine) {
            draft.setText(draft.text(for: draft.segment) + "\n", for: draft.segment)
          }
          .accessibilityIdentifier("setup.keyboard.newline")
          Spacer(minLength: 0)
          Button(SetupCopy.doneEditing) { editing = false }
            .accessibilityIdentifier("setup.keyboard.done")
          Button(draft.segment == .steps ? SetupCopy.review : SetupCopy.next) {
            editing = false
            advance()
          }
          .disabled(!canAdvance)
          .accessibilityIdentifier("setup.keyboard.next")
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .tint(AnchorSetupStyle.accent)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }

    private var canAdvance: Bool {
      !draft.isImportingImages
        && (draft.isReviewing
          ? draft.isValid
          : !draft.text(for: draft.segment).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var buttonTitle: String {
      if saving { return SetupCopy.saving }
      if draft.isReviewing { return SetupCopy.start }
      return draft.editingReview
        ? SetupCopy.doneEditing : (draft.segment == .steps ? SetupCopy.review : SetupCopy.next)
    }

    private func changeSegment(_ segment: AnchorSetupSegment) {
      editing = false
      speechInput.stop()
      speechSegment = nil
      draft.segment = segment
    }

    private func edit(_ segment: AnchorSetupSegment) {
      changeSegment(segment)
      draft.editingReview = true
      draft.isReviewing = false
    }

    private func goBack() {
      if draft.isReviewing {
        edit(.steps)
      } else if let previous = AnchorSetupSegment(rawValue: draft.segment.rawValue - 1) {
        changeSegment(previous)
      }
    }

    private func toggleSpeech() {
      speechSegment = draft.segment
      speechInput.toggle(initialText: draft.text(for: draft.segment))
    }

    private func advance() {
      guard canAdvance, !saving else { return }
      speechInput.stop()
      speechSegment = nil
      if draft.isReviewing {
        saveTask()
        return
      }
      if draft.editingReview || draft.segment == .steps {
        draft.isReviewing = true
        draft.editingReview = false
      } else if let next = AnchorSetupSegment(rawValue: draft.segment.rawValue + 1) {
        draft.segment = next
      }
    }

    private func saveTask() {
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
            completionCriteria: draft.criteria.joined(separator: "\n"),
            note: draft.originalText,
            userPlan: AnchorUserPlan(steps: draft.steps, localImageNames: names))
          // A personal plan can start without any linked computer process.
          if await model.hostTask(id: draft.hostedTaskID, goal: goal, processes: []) {
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
