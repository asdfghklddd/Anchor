#if os(iOS)
  import AnchorCore
  import AnchorDesign
  import SwiftUI

  struct AnchorSetupView: View {
    let model: AnchorSessionModel
    @Bindable var draft: AnchorSetupDraft
    @Environment(\.dismiss) private var dismiss
    @State private var speechInput = SpeechInputController()
    @State private var speechSegment: AnchorSetupSegment?
    @State private var editingReview = false
    @State private var saving = false
    @State private var saveError: String?

    var body: some View {
      GeometryReader { geometry in
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
                  changeSegment: changeSegment, toggleSpeech: toggleSpeech, advance: advance)
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
          .scrollDismissesKeyboard(.interactively)
          .onChange(of: draft.segment) { scroll.scrollTo("top", anchor: .top) }
          .onChange(of: draft.isReviewing) { scroll.scrollTo("top", anchor: .top) }
        }
      }
      .background {
        (draft.isReviewing ? AnchorSetupStyle.reviewBackground : AnchorSetupStyle.background)
          .overlay(alignment: .bottom) {
            if !draft.isReviewing { AnchorSetupWave().frame(height: 100) }
          }
          .ignoresSafeArea()
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if draft.isReviewing || !draft.isKeyboardEditing {
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
              .foregroundStyle(canAdvance ? Color.white : AnchorSetupStyle.secondary)
              .background(AnchorSetupStyle.accent.opacity(canAdvance ? 1 : 0.15), in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance || saving)
            .accessibilityIdentifier(draft.isReviewing ? "setup.start.button" : "setup.next.button")
            .padding(.horizontal, 20)
            .frame(maxWidth: draft.isReviewing ? 580 : 190)
          }
          .padding(.top, 8)
          .padding(.bottom, draft.isReviewing ? 12 : 70)
          .frame(maxWidth: .infinity)
          .background { if draft.isReviewing { AnchorSetupStyle.reviewBottom } }
        }
      }
      .toolbar(.hidden, for: .navigationBar)
      .onChange(of: speechInput.transcript) { _, transcript in
        guard let speechSegment else { return }
        draft.setText(transcript, for: speechSegment)
      }
      .onDisappear { speechInput.stop() }
      .interactiveDismissDisabled(saving || draft.isImportingImages)
      .disabled(saving)
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
      return editingReview
        ? SetupCopy.doneEditing : (draft.segment == .steps ? SetupCopy.review : SetupCopy.next)
    }

    private func changeSegment(_ segment: AnchorSetupSegment) {
      speechInput.stop()
      speechSegment = nil
      draft.segment = segment
    }

    private func edit(_ segment: AnchorSetupSegment) {
      changeSegment(segment)
      editingReview = true
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
      if editingReview || draft.segment == .steps {
        draft.isReviewing = true
        editingReview = false
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
          let names = try AnchorPlanImages.save(draft.imageData, goalID: draft.goalID)
          let goal = AnchorGoal(
            id: draft.goalID,
            title: draft.goalTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            completionCriteria: draft.criteria.joined(separator: "\n"),
            note: draft.originalText,
            userPlan: AnchorUserPlan(steps: draft.steps, localImageNames: names))
          // A personal plan can start without any linked computer process.
          if await model.hostTask(id: draft.hostedTaskID, goal: goal, processes: []) {
            dismiss()
          } else {
            saveError = SetupCopy.saveFailed
          }
        } catch { saveError = SetupCopy.saveFailed }
      }
    }
  }
#endif
