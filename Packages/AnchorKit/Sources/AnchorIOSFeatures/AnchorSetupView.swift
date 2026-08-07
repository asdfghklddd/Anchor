#if os(iOS)
import AnchorCore
import AnchorDesign
import Foundation
import SwiftUI

struct AnchorSetupView: View {
    let model: AnchorSessionModel
    let currentProcessProvider: (any CurrentProcessProviding)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var goalTitle = ""
    @State private var completionCriteria = ""
    @State private var processNames = [""]
    @State private var speechInput = SpeechInputController()
    @State private var isFetchingCurrentProcesses = false
    @State private var didLoadCurrentProcesses = false
    @State private var currentProcessStatus: CurrentProcessStatus = .idle
    @FocusState private var focusedField: Field?

    init(
        model: AnchorSessionModel,
        currentProcessProvider: (any CurrentProcessProviding)? = nil
    ) {
        self.model = model
        self.currentProcessProvider = currentProcessProvider
    }

    private enum CurrentProcessStatus {
        case idle
        case synced(Int)
        case unavailable
    }

    private enum Field: Hashable {
        case goal
        case criteria
        case process(Int)
    }

    var body: some View {
        ZStack {
            HarborBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    setupNavigation
                    setupHero
                        .padding(.bottom, AnchorSpacing.large)
                    goalForm
                    processForm
                }
                .padding(.horizontal, AnchorSpacing.medium)
                .padding(.bottom, AnchorSpacing.xLarge)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            startDock
        }
        .navigationBarHidden(true)
        .onChange(of: speechInput.transcript) { _, transcript in
            guard !transcript.isEmpty else { return }
            completionCriteria = transcript
        }
        .onDisappear {
            speechInput.stop()
        }
        .task {
            await loadCurrentProcesses()
        }
    }

    private var setupNavigation: some View {
        HStack {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(AnchorPalette.surface, in: .circle)
            }
            // [VERIFY] Confirm “Close” matches the intended setup dismissal wording.
            .accessibilityLabel(L10n.close)
            .accessibilityIdentifier("setup.close.button")
            Spacer()
            Text(L10n.setupNewWork)
                .font(.subheadline.bold())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("setup.screen")
            Spacer()
            Text("01")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.link)
                .frame(width: 44, height: 44, alignment: .trailing)
        }
        .frame(minHeight: 54)
        // Navigation chrome stays compact at accessibility sizes. The close
        // button itself remains a 44pt target and is still VoiceOver-visible.
        .dynamicTypeSize(.xSmall ... .xxxLarge)
    }

    private var setupHero: some View {
        HarborHeroSurface {
            HStack(alignment: .center, spacing: AnchorSpacing.small) {
                heroCopy
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(.white.opacity(0.14))
                heroStats
                    .frame(width: 100)
            }
            .padding(AnchorSpacing.medium)
        }
        .accessibilityElement(children: .combine)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 5) {
            HarborBrandMark()
                .padding(.bottom, 3)
            Text(L10n.establishAnchor)
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.oceanHighlight)
            Text(L10n.setupMantra)
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? Font.title2.bold()
                        : Font.title.bold()
                )
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }

    private var heroStats: some View {
        VStack(alignment: .leading, spacing: 0) {
            setupStat(value: "\(processCount)", label: L10n.parallelProcesses)
                .padding(.bottom, AnchorSpacing.small)
            Divider().overlay(.white.opacity(0.14))
            setupStat(value: completionCriteria.isEmpty ? "—" : "✓", label: L10n.completionReady)
                .padding(.top, AnchorSpacing.small)
        }
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }

    private func setupStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? Font.title3.bold().monospacedDigit()
                        : Font.title2.bold().monospacedDigit()
                )
                .foregroundStyle(AnchorPalette.seafoam)
            Text(label)
                .font(dynamicTypeSize.isAccessibilitySize ? .caption : .caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(2)
        }
    }

    private var goalForm: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.large) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.setupGoalLabel)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.secondaryInk)
                TextField(L10n.goalTitle, text: $goalTitle, axis: .vertical)
                    .font(.body.bold())
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 1 ... 2 : 1 ... 3)
                    .focused($focusedField, equals: .goal)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .criteria }
                    .accessibilityIdentifier("setup.goal.field")
                    .harborInputSurface()
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(L10n.setupCriteriaLabel)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Spacer()
                }
                .frame(minHeight: 44)

                TextField(L10n.completionCriteria, text: $completionCriteria, axis: .vertical)
                    .font(.body)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 ... 4 : 4 ... 7)
                    .focused($focusedField, equals: .criteria)
                    .accessibilityIdentifier("setup.criteria.field")
                    .harborInputSurface()

                voiceInputControl
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility2)
    }

    @ViewBuilder
    private var voiceInputControl: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        voiceInputButton
                        Text(L10n.voiceInputEditHint)
                            .font(.body)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    HStack(spacing: AnchorSpacing.small) {
                        voiceInputButton
                        Text(L10n.voiceInputEditHint)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 132, alignment: .leading)
                    }
                }
            }
            if let errorMessage = speechInput.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.sourceInk("coral"))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setup.voice.input.error")
            }
        }
        .padding(.top, AnchorSpacing.xSmall)
    }

    private var voiceInputButton: some View {
        Button(action: toggleSpeechInput) {
            Label(
                speechInput.isRecording ? L10n.voiceInputStop : L10n.voiceInput,
                systemImage: speechInput.isRecording ? "stop.fill" : "mic.fill"
            )
            .font(
                dynamicTypeSize.isAccessibilitySize
                    ? Font.body.bold()
                    : Font.subheadline.bold()
            )
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(speechInput.isRecording ? AnchorPalette.coral : AnchorPalette.link)
        .accessibilityValue(speechInput.isRecording ? L10n.voiceInputListening : L10n.voiceInputReady)
        .accessibilityHint(L10n.voiceInputHint)
        .accessibilityIdentifier("setup.voice.input.button")
    }

    private var processForm: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.parallelProcesses)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.link)
                    Text(L10n.readyProcesses)
                        .font(.title3.bold())
                        .foregroundStyle(AnchorPalette.ink)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(processCount)/6")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    if isFetchingCurrentProcesses {
                        Label(L10n.syncingProcesses, systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    } else if case let .synced(count) = currentProcessStatus, count > 0 {
                        Label(L10n.syncedProcesses(count), systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AnchorPalette.mintInk)
                    }
                }
            }
            .padding(.top, AnchorSpacing.xLarge)

            VStack(spacing: 7) {
                ForEach(processNames.indices, id: \.self) { index in
                    processRow(index: index)
                }
            }

            if processNames.count < 6 {
                Button {
                    processNames.append("")
                    focusedField = .process(processNames.endIndex - 1)
                } label: {
                    Label(L10n.addAnotherProcess, systemImage: "plus")
                        .font(.subheadline.bold())
                        .foregroundStyle(AnchorPalette.link)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, AnchorSpacing.medium)
                        .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .dynamicTypeSize(.xSmall ... .accessibility2)
    }

    private func processRow(index: Int) -> some View {
        let tone = tone(at: index)

        return HStack(spacing: AnchorSpacing.small) {
            Text(String(format: "%02d", index + 1))
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.source(tone))
                .frame(width: 30, height: 30)
                .background(AnchorPalette.source(tone).opacity(0.12), in: .rect(cornerRadius: 10, style: .continuous))

            TextField(L10n.processName, text: $processNames[index])
                .font(.subheadline.bold())
                .focused($focusedField, equals: .process(index))
                .textFieldStyle(.plain)
                .frame(minHeight: 44)
                .accessibilityIdentifier("setup.process.field.\(index)")

            if processNames.count > 1 {
                Button(role: .destructive) {
                    processNames.remove(at: index)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("\(L10n.delete) \(index + 1)")
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            Capsule()
                .fill(AnchorPalette.source(tone))
                .frame(width: 4)
                .padding(.vertical, 12)
        }
        .shadow(color: AnchorPalette.ink.opacity(0.07), radius: 10, y: 6)
    }

    private var startDock: some View {
        VStack(spacing: 0) {
            Divider().overlay(AnchorPalette.ink.opacity(0.08))
            Button(action: establishSession) {
                Label(L10n.startAnchoring, systemImage: "play.fill")
            }
            .buttonStyle(HarborPrimaryButtonStyle())
            .disabled(!isValid)
            .accessibilityIdentifier("setup.start.button")
            .padding(.horizontal, AnchorSpacing.medium)
            .padding(.vertical, AnchorSpacing.small)
        }
        .background(AnchorPalette.paper.opacity(0.97))
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }

    private var processCount: Int {
        processNames.lazy.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var isValid: Bool {
        !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        processCount > 0
    }

    private func tone(at index: Int) -> String {
        ["coral", "periwinkle", "cyan", "ink", "seafoam", "sand"][index % 6]
    }

    private func establishSession() {
        let processes = processNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, name in
                AnchorProcess(
                    sourceName: name,
                    sourceSymbol: name.first.map(String.init) ?? "•",
                    sourceTone: tone(at: index),
                    title: name,
                    status: .queued,
                    metric: "—",
                    metricLabel: L10n.lastUpdated,
                    detail: L10n.noEvents
                )
            }
        let criteria = completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = AnchorGoal(
            title: goalTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            completionCriteria: criteria,
            note: criteria
        )
        Task {
            if await model.createSession(goal: goal, processes: processes) {
                dismiss()
            }
        }
    }

    private func toggleSpeechInput() {
        focusedField = .criteria
        speechInput.toggle(initialText: completionCriteria)
    }

    private func loadCurrentProcesses() async {
        guard !didLoadCurrentProcesses, let currentProcessProvider else { return }
        didLoadCurrentProcesses = true
        isFetchingCurrentProcesses = true
        defer { isFetchingCurrentProcesses = false }

        do {
            let snapshot = try await currentProcessProvider.currentProcessSnapshot()
            let names = Array(snapshot.processNames.prefix(6))
            guard !names.isEmpty else {
                currentProcessStatus = .unavailable
                return
            }
            processNames = names
            currentProcessStatus = .synced(names.count)
        } catch {
            currentProcessStatus = .unavailable
        }
    }
}
#endif
