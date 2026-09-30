#if os(iOS)
  import AnchorDesign
  import PhotosUI
  import SwiftUI

  struct AnchorSetupInput: View {
    @Bindable var draft: AnchorSetupDraft
    let speech: SpeechInputController
    let height: CGFloat
    let changeSegment: (AnchorSetupSegment) -> Void
    let toggleSpeech: () -> Void
    @State private var selection: [PhotosPickerItem] = []
    @State private var photoError: String?
    @FocusState.Binding var editing: Bool
    @ScaledMetric(relativeTo: .subheadline) private var textSize: CGFloat = 16
    @ScaledMetric(relativeTo: .footnote) private var hintSize: CGFloat = 14

    private var recording: Bool { speech.isRecording }

    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        VStack(alignment: .leading, spacing: 12) {
          if draft.text(for: draft.segment).isEmpty {
            Text(draft.segment.prompt)
              .font(.system(size: textSize, weight: .medium))
              .foregroundStyle(AnchorSetupStyle.secondary)
              .padding(.leading, 5)
          }
          inputField
            .font(.system(size: textSize))
            .foregroundStyle(AnchorSetupStyle.ink)
            .tint(AnchorIOSStyle.action)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: editorHeight)
            .layoutPriority(1)
          if !draft.imageData.isEmpty {
            AnchorSetupPhotos(images: draft.imageData, remove: removePhoto)
          }
          if !editing {
            HStack {
              PhotosPicker(
                selection: $selection, maxSelectionCount: max(1, 6 - draft.imageData.count),
                matching: .images
              ) {
                Image(systemName: "plus")
                  .frame(width: 28, height: 28)
                  .background(AnchorSetupStyle.controlSurface, in: .circle)
                  .frame(width: 44, height: 44).contentShape(.rect)
              }
              .accessibilityLabel(SetupCopy.photos)
              .accessibilityIdentifier("setup.photos.button")
              .disabled(draft.isImportingImages || draft.imageData.count >= 6)
              if recording {
                AnchorSetupWaveform(level: speech.audioLevel)
                  .padding(.trailing, 6)
              } else {
                Spacer(minLength: 4)
              }
              AnchorSetupVoiceButton(recording: recording, action: voiceAction)
                .disabled(speech.isRequestingPermission)
              if recording {
                AnchorSetupWaveform(level: speech.audioLevel)
                  .padding(.leading, 6)
              } else {
                Spacer(minLength: 4)
              }
              Button(action: showKeyboard) {
                Image(systemName: "keyboard").font(.body)
                  .frame(width: 44, height: 44).contentShape(.rect)
              }
              .accessibilityLabel(SetupCopy.keyboard)
              .accessibilityIdentifier("setup.keyboard.button")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AnchorSetupStyle.secondary)
          }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 20)
        .frame(minHeight: height)
        .background {
          RoundedRectangle(cornerRadius: AnchorSetupStyle.inputRadius)
            .fill(AnchorSetupStyle.card)
            .shadow(color: Color.black.opacity(0.12), radius: 4, y: 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup.input.card")

        if draft.isImportingImages { ProgressView().accessibilityLabel(SetupCopy.photos) }
        if let error = photoError ?? speech.errorMessage {
          Text(error).font(.caption).foregroundStyle(AnchorSetupStyle.secondary)
            .accessibilityIdentifier("setup.input.error")
        }
        if speech.isRecording {
          Text(L10n.voiceInputListening).font(.caption).foregroundStyle(AnchorIOSStyle.action)
        }
        if !editing {
          Text(SetupCopy.hintTitle).font(.caption).foregroundStyle(AnchorSetupStyle.secondary)
          Text(draft.segment.hint)
            .font(.caption)
            .foregroundStyle(AnchorSetupStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
          ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { segmentButtons }
            VStack(alignment: .leading, spacing: 4) { segmentButtons }
          }
        }
      }
      .onDisappear { draft.isKeyboardEditing = false }
      .onChange(of: selection) { _, items in
        guard !items.isEmpty else { return }
        Task { await importPhotos(items) }
      }
    }

    private var editorHeight: CGFloat {
      let empty = draft.text(for: draft.segment).isEmpty
      let chrome: CGFloat = editing ? (empty ? 73 : 40) : (empty ? 132 : 100)
      return max(editing ? 100 : 170, height - chrome - (draft.imageData.isEmpty ? 0 : 120))
    }

    @ViewBuilder private var inputField: some View {
      switch draft.segment {
      case .goal: editor(text: $draft.goalTitle, segment: .goal)
      case .criteria: editor(text: $draft.completionCriteria, segment: .criteria)
      case .steps: editor(text: $draft.actionPlan, segment: .steps)
      }
    }

    private func editor(text: Binding<String>, segment: AnchorSetupSegment) -> some View {
      TextEditor(text: text)
        .accessibilityLabel(segment.title)
        .accessibilityIdentifier(segment.fieldID)
        .scrollContentBackground(.hidden)
        .focused($editing)
        .frame(minHeight: editing ? 100 : 170)
        .overlay(alignment: .topLeading) {
          if text.wrappedValue.isEmpty {
            Text(segment.placeholder).font(.system(size: hintSize))
              .foregroundStyle(AnchorSetupStyle.secondary.opacity(0.6))
              .padding(.top, 8).padding(.horizontal, 5)
              .allowsHitTesting(false)
              .accessibilityHidden(true)
          }
        }
    }

    @ViewBuilder private var segmentButtons: some View {
      ForEach(AnchorSetupSegment.allCases) { segment in
        Button {
          editing = false
          changeSegment(segment)
        } label: {
          Text("\(segment.rawValue + 1)  \(segment.title)")
            .font(.caption)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
              AnchorSetupStyle.card.opacity(draft.segment == segment ? 1 : 0.45), in: .capsule
            )
            .fontWeight(draft.segment == segment ? .semibold : .regular)
            .frame(minHeight: 44).contentShape(.rect)
        }
        .foregroundStyle(AnchorIOSStyle.action)
        .buttonStyle(.plain)
        .accessibilityAddTraits(draft.segment == segment ? [.isSelected] : [])
        .accessibilityIdentifier("setup.segment.\(segment.rawValue)")
      }
    }

    private func voiceAction() {
      editing = false
      toggleSpeech()
    }
    private func showKeyboard() {
      speech.stop()
      editing = true
    }
    private func removePhoto(_ index: Int) { draft.imageData.remove(at: index) }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
      draft.isImportingImages = true
      photoError = nil
      defer {
        draft.isImportingImages = false
        selection = []
      }
      for item in items {
        do {
          guard let data = try await item.loadTransferable(type: Data.self) else {
            throw CocoaError(.fileReadUnknown)
          }
          guard draft.imageData.count < 6 else { break }
          let prepared = try await Task.detached(priority: .userInitiated) {
            try AnchorPlanImages.preparedData(data)
          }.value
          draft.imageData.append(prepared)
        } catch { photoError = SetupCopy.photoFailed }
      }
    }
  }
#endif
