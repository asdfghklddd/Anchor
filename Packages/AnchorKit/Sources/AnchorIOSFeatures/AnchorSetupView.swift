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
    /// The tour's line the microphone says next: the title, then the plan.
    @State private var reading: AnchorSetupField?
    @State private var heard = TourReadAlong(heard: "", line: "")
    /// The tour's first drop: the water rises and takes the anchor before the page goes.
    @State private var sinking = false
    @State private var sliderFrame: CGRect?
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
      VStack(spacing: 0) {
        AnchorSetupHeader(close: close, confirmsDiscard: $showsDiscardConfirmation, discard: discard)
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            // Held in place here; drawn over the frost, where it answers.
            if tour != nil {
              tourLine(live: false)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .tourSpot(.setupLine)
            }
            AnchorSetupInput(
              draft: draft, speech: speechInput, focus: $focus,
              titleMoved: titleMoved,
              readAlong: reading.map { ($0, Self.line(for: $0), heard.lit) },
              guidesVoice: reading != nil,
              // In the tour a tap says the whole line; letting go doesn't cut it short.
              beginSpeech: beginSpeech, endSpeech: tour != nil ? {} : speechInput.finish)
            .tourSpot(.setupInput)
            AnchorDropSlider(
              enabled: draft.isValid && !draft.isImportingImages, saving: saving,
              stepCount: draft.steps.count, onDrop: saveTask,
              guides: tour != nil && reading == nil, releases: sinking)
              .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.space)) } action: { sliderFrame = $0 }
              .tourSpot(.setupSlider)
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
          .overlay(alignment: .bottom) {
            AnchorSetupWave()
              .frame(height: sinking ? 250 : 100)
              .animation(.easeIn(duration: 0.5), value: sinking)
          }
          .ignoresSafeArea()
      }
      .overlayPreferenceValue(TourSpotKey.self) { anchors in
        if tour != nil, !sinking {
          GeometryReader { proxy in
            tourLayer(anchors.mapValues { proxy[$0] })
          }
          .ignoresSafeArea()
          .transition(.opacity)
        }
      }
      .animation(.easeOut(duration: 0.4), value: sinking)
      .overlay(alignment: .topLeading) {
        if sinking, let sliderFrame {
          SetupSink(from: CGPoint(x: sliderFrame.maxX - 32, y: sliderFrame.midY))
        }
      }
      .coordinateSpace(.named(Self.space))
      .sensoryFeedback(.impact(weight: .medium), trigger: sinking) { _, now in now }
      .toolbar(.hidden, for: .navigationBar)
      // A new anchor starts at its title, as a new reminder does.
      .task {
        guard !draft.hasContent else { return }
        if tour != nil { reading = .title } else { focus = .title }
      }
      .onChange(of: speechInput.transcript) { _, transcript in
        if let reading, tour != nil {
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
        if !isRecording, speechField == .title, tour == nil { settleTitle() }
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
      // With something written, a swipe down asks first, from the close button.
      .interactiveDismissDisabled(draft.hasContent || focus != nil || saving || draft.isImportingImages)
      .background {
        SheetDismissAttempt {
          if draft.hasContent, !saving, !draft.isImportingImages { close() }
        }
      }
      .disabled(saving)
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
      }
    }

    private static let space = "setup"

    private var canDrop: Bool { draft.isValid && !draft.isImportingImages && !saving }

    /// Nothing written closes at once; a draft asks whether to throw it away.
    private func close() {
      if draft.hasContent {
        focus = nil
        showsDiscardConfirmation = true
      } else {
        dismiss()
      }
    }

    private func discard() {
      speechInput.stop()
      speechField = nil
      draft.isConsumed = true
      dismiss()
    }

    private func settleTitle() {
      if draft.settleTitle() { titleMoved = true }
    }

    // MARK: Reading aloud in the tour

    /// The page under frost, clear where the voice goes (both fields for the
    /// title, the plan's for the plan) and then on the slider; the line sits
    /// sharp on the glass above them.
    private func tourLayer(_ spots: [TourSpot: CGRect]) -> some View {
      let clear: (CGRect, CGFloat)? = switch reading {
      case .title: spots[.setupInput].map { ($0.insetBy(dx: -6, dy: -6), AnchorSetupStyle.inputRadius + 6) }
      case .plan: spots[.setupPlan].map { ($0.insetBy(dx: -6, dy: -6), AnchorSetupStyle.inputRadius + 6) }
      case nil: spots[.setupSlider].map { ($0.insetBy(dx: -6, dy: -6), $0.height / 2 + 6) }
      }
      return ZStack(alignment: .topLeading) {
        TourFrost(hole: clear?.0, radius: clear?.1 ?? 0)
        if let line = spots[.setupLine] {
          tourLine(live: true)
            .frame(width: line.width, alignment: .leading)
            .offset(x: line.minX, y: line.minY)
        }
      }
    }

    /// The line says what to do: tap the microphone for the title, again
    /// for the plan, then slide. `live` is the one drawn over the frost; the
    /// other only holds its place.
    private func tourLine(live: Bool) -> some View {
      HStack(spacing: 10) {
        TourCaption(text: tourText)
        Spacer(minLength: 0)
      }
      .frame(minHeight: 44)
      .padding(.top, 6)
    }

    private var tourText: String {
      switch reading {
      case .title: TourCopy.readTitle
      case .plan: TourCopy.readPlan
      case nil: TourCopy.slide
      }
    }

    private static func line(for field: AnchorSetupField) -> String {
      field == .title ? TourCopy.spokenTitle : TourCopy.spokenPlan
    }

    /// The line lights as far as the voice has reached.
    private func hear(_ transcript: String, reading: AnchorSetupField) {
      let heard = TourReadAlong(heard: transcript, line: Self.line(for: reading))
      withAnimation(AnchorMotion.micro) { self.heard = heard }
    }

    /// The line goes in whole, a bell rings, and the next line is up.
    private func accept(_ field: AnchorSetupField) {
      guard reading == field else { return }
      speechField = nil
      speechInput.stop()
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

    /// The tour's microphone: a tap says the waiting line at a quick
    /// speaking pace, lighting it as it goes, without a microphone,
    /// recognizer or permission. Said through, it goes in whole.
    private func say(_ field: AnchorSetupField) {
      guard speechField == nil else { return }
      speechField = field
      Task {
        let said = await speechInput.play(Self.line(for: field))
        if said { accept(field) } else { speechField = nil }
      }
    }

    /// Dictation goes to the title while there is none, then to the plan;
    /// in the tour, to the line being read.
    private func beginSpeech() {
      focus = nil
      if tour != nil {
        if let reading { say(reading) }
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
            if tour != nil, !reduceMotion {
              sinking = true
              try? await Task.sleep(for: .seconds(0.85))
            }
            dismiss()
          } else {
            saveError = SetupCopy.saveFailed
          }
        } catch { saveError = SetupCopy.saveFailed }
      }
    }
  }

  /// The tour's first drop on the setup page: the anchor leaves the end of
  /// the slider, falls into the risen water and sinks out of sight, a few
  /// bubbles coming up behind it.
  private struct SetupSink: View {
    let from: CGPoint
    @State private var start = Date.now

    var body: some View {
      GeometryReader { geometry in
        let water = geometry.size.height - 150
        TimelineView(.animation) { context in
          let t = context.date.timeIntervalSince(start)
          let fall = min(1, t / 0.6)
          let y = from.y + (geometry.size.height + 80 - from.y) * fall * fall
          ZStack(alignment: .topLeading) {
            AnchorFigure(color: AnchorSetupStyle.accent, depth: true)
              .frame(width: 34, height: 34)
              .rotationEffect(.degrees(14 * fall))
              .position(x: from.x, y: y)
              .opacity(y > water ? max(0, 1 - (y - water) / 140) : 1)
            ForEach(0..<6, id: \.self) { index in
              let rise = t - 0.32 - Double(index) * 0.08
              if rise > 0 {
                let size = 5 + CGFloat(index % 3) * 3
                Circle()
                  .stroke(Color.white.opacity(0.85 * max(0, 1 - rise / 0.8)), lineWidth: 1.3)
                  .frame(width: size, height: size)
                  .position(x: from.x + sin(Double(index) * 1.7 + rise * 7) * 9,
                            y: water + 50 - CGFloat(rise) * 110)
              }
            }
          }
        }
      }
      .allowsHitTesting(false)
      .accessibilityHidden(true)
    }
  }
#endif
