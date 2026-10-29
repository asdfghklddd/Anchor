#if os(iOS)
  import AnchorCore
  import AnchorDesign
  import SwiftUI

  enum AnchorSetupField: Hashable {
    case title, plan
  }

  /// A title and an optional plan on one page, as in Reminders. The plan's lines
  /// become steps; the grey hint shows the format and leaves once typing starts.
  struct AnchorSetupInput: View {
    @Bindable var draft: AnchorSetupDraft
    let speech: SpeechInputController
    @FocusState.Binding var focus: AnchorSetupField?
    /// Words past the title limit just moved to the top of the plan.
    let titleMoved: Bool
    /// The tour's line to read aloud into a field, lit as far as it was heard.
    var readAlong: (field: AnchorSetupField, line: String, lit: Int)?
    let beginSpeech: () -> Void
    let endSpeech: () -> Void
    @State private var showsSteps = false
    @State private var holdingVoice = false
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var planSize: CGFloat = 16

    private var recording: Bool { speech.isRecording }

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        titleCard
        planCard
        if let error = speech.errorMessage {
          Text(error).font(.caption).foregroundStyle(AnchorSetupStyle.secondary)
            .accessibilityIdentifier("setup.input.error")
        }
        if speech.isRecording {
          Text(holdingVoice ? SetupCopy.voiceRelease : SetupCopy.voiceTapStop)
            .font(.caption).foregroundStyle(AnchorIOSStyle.action)
            .frame(maxWidth: .infinity)
            .contentTransition(.opacity)
            .animation(AnchorMotion.micro, value: holdingVoice)
        }
      }
    }

    // MARK: Title

    private var titleCard: some View {
      VStack(alignment: .leading, spacing: 8) {
        ZStack(alignment: .topLeading) {
          if let readAlong, readAlong.field == .title, draft.goalTitle.isEmpty {
            ghost(readAlong).font(.system(size: titleSize, weight: .semibold))
          }
          titleField
        }
        // The room left shows only once it starts to matter.
        if draft.titleUnits * 4 >= AnchorTitleLength.limit * 3 {
          TitleMeter(units: draft.titleUnits)
            .transition(.opacity)
        }
        if draft.titleIsTooLong {
          Text(SetupCopy.titleTooLong)
            .font(.caption)
            .foregroundStyle(AnchorIOSStyle.attentionInk)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("setup.title.over")
        }
      }
      .animation(AnchorMotion.micro, value: draft.titleIsTooLong)
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(card)
    }

    private var titleField: some View {
      TextField(
        SetupCopy.titleLabel, text: $draft.goalTitle,
        prompt: readAlong?.field == .title ? Text(verbatim: "")
          : Text(SetupCopy.titlePlaceholder).foregroundStyle(AnchorSetupStyle.secondary.opacity(0.6)),
        axis: .vertical
      )
      .font(.system(size: titleSize, weight: .semibold))
      .foregroundStyle(AnchorSetupStyle.ink)
      .tint(AnchorIOSStyle.action)
      .lineLimit(1...3)
      .submitLabel(.next)
      .focused($focus, equals: .title)
      .accessibilityIdentifier("setup.goal.field")
    }

    /// The line to read, in grey, lighting up from its start as it is heard.
    private func ghost(_ readAlong: (field: AnchorSetupField, line: String, lit: Int)) -> some View {
      var line = AttributedString(readAlong.line)
      let split = line.index(line.startIndex, offsetByCharacters: min(readAlong.lit, readAlong.line.count))
      line[line.startIndex..<split].foregroundColor = AnchorIOSStyle.action
      line[split..<line.endIndex].foregroundColor = AnchorSetupStyle.secondary.opacity(0.5)
      return Text(line)
        .fixedSize(horizontal: false, vertical: true)
        .allowsHitTesting(false)
    }

    // MARK: Plan

    private var planCard: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(SetupCopy.planLabel)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(AnchorSetupStyle.heading)
        if titleMoved {
          Label(SetupCopy.titleMoved, systemImage: "arrow.turn.down.right")
            .font(.caption)
            .foregroundStyle(AnchorSetupStyle.secondary)
            .accessibilityIdentifier("setup.title.moved")
        }
        ZStack(alignment: .topLeading) {
          if let readAlong, readAlong.field == .plan, draft.actionPlan.isEmpty {
            ghost(readAlong).font(.system(size: planSize))
          } else if draft.actionPlan.isEmpty, focus != .plan {
            Text(SetupCopy.planExample)
              .font(.system(size: planSize))
              .foregroundStyle(AnchorSetupStyle.secondary.opacity(0.6))
              .allowsHitTesting(false)
              .accessibilityHidden(true)
          }
          TextField(SetupCopy.planLabel, text: $draft.actionPlan, prompt: Text(verbatim: ""), axis: .vertical)
            .font(.system(size: planSize))
            .foregroundStyle(AnchorSetupStyle.ink)
            .tint(AnchorIOSStyle.action)
            .lineLimit(4...)
            .focused($focus, equals: .plan)
            .accessibilityHint(SetupCopy.planExampleHint)
            .accessibilityIdentifier("setup.steps.field")
        }
        if !draft.steps.isEmpty { stepsPreview }
        tools
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(card)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("setup.input.card")
    }

    /// What the splitter made of the plan, before anything is saved.
    private var stepsPreview: some View {
      VStack(alignment: .leading, spacing: 6) {
        Button {
          withAnimation(AnchorMotion.micro) { showsSteps.toggle() }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "list.bullet").font(.caption)
            Text(SetupCopy.split(draft.steps.count))
              .font(.caption.weight(.semibold))
              .contentTransition(.numericText())
            Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
              .rotationEffect(.degrees(showsSteps ? 180 : 0))
          }
          .frame(minHeight: 44).contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AnchorIOSStyle.action)
        .accessibilityHint(SetupCopy.splitHint)
        .accessibilityIdentifier("setup.steps.preview")
        if showsSteps {
          ForEach(Array(draft.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
              Text(String(format: "%02d", index + 1))
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(AnchorSetupStyle.controlSurface, in: .capsule)
              Text(step).font(.footnote).foregroundStyle(AnchorSetupStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
            }
            .transition(.opacity)
          }
        }
      }
      .animation(AnchorMotion.micro, value: draft.steps.count)
    }

    /// The microphone sits in the middle; while it listens, the voice shows on both sides.
    private var tools: some View {
      HStack(spacing: 6) {
        if recording { AnchorSetupWaveform(level: speech.audioLevel) } else { Spacer(minLength: 0) }
        AnchorSetupVoiceButton(
          recording: recording, requesting: speech.isRequestingPermission,
          level: speech.audioLevel, holding: $holdingVoice,
          begin: beginSpeech, end: endSpeech)
        if recording { AnchorSetupWaveform(level: speech.audioLevel) } else { Spacer(minLength: 0) }
      }
      .padding(.top, 4)
    }

    private var card: some View {
      RoundedRectangle(cornerRadius: AnchorSetupStyle.inputRadius)
        .fill(AnchorSetupStyle.card)
        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 4)
    }
  }

  /// A thin line under the title that fills as the title takes up its room,
  /// and turns to the attention color once it no longer fits.
  private struct TitleMeter: View {
    let units: Int

    private var fraction: Double { min(1, Double(units) / Double(AnchorTitleLength.limit)) }
    private var over: Bool { units > AnchorTitleLength.limit }

    var body: some View {
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(AnchorSetupStyle.controlSurface)
          Capsule().fill(over ? AnchorIOSStyle.yellow : AnchorSetupStyle.accent)
            .frame(width: geometry.size.width * fraction)
        }
      }
      .frame(height: 3)
      .animation(AnchorMotion.micro, value: units)
      .accessibilityElement()
      .accessibilityLabel(SetupCopy.titleMeter)
      .accessibilityValue(Text(fraction, format: .percent.precision(.fractionLength(0))))
      .accessibilityIdentifier("setup.title.meter")
    }
  }
#endif
