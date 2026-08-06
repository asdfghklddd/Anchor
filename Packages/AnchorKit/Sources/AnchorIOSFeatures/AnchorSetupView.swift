#if os(iOS)
import AnchorCore
import AnchorDesign
import Foundation
import SwiftUI

struct AnchorSetupView: View {
    let model: AnchorSessionModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var goalTitle = ""
    @State private var completionCriteria = ""
    @State private var processNames = [""]
    @FocusState private var focusedField: Field?

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
                .accessibilityIdentifier("setup.screen")
            Spacer()
            Text("01")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.link)
                .frame(width: 44, height: 44, alignment: .trailing)
        }
        .frame(minHeight: 54)
    }

    private var setupHero: some View {
        HarborHeroSurface {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        heroCopy
                        Divider().overlay(.white.opacity(0.14))
                        heroStats
                    }
                } else {
                    HStack(alignment: .center, spacing: AnchorSpacing.small) {
                        heroCopy
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(.white.opacity(0.14))
                        heroStats
                            .frame(width: 100)
                    }
                }
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
                .font(.title.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroStats: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: AnchorSpacing.large) {
                    setupStat(value: "\(processCount)", label: L10n.parallelProcesses)
                    setupStat(value: completionCriteria.isEmpty ? "—" : "✓", label: L10n.completionReady)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    setupStat(value: "\(processCount)", label: L10n.parallelProcesses)
                        .padding(.bottom, AnchorSpacing.small)
                    Divider().overlay(.white.opacity(0.14))
                    setupStat(value: completionCriteria.isEmpty ? "—" : "✓", label: L10n.completionReady)
                        .padding(.top, AnchorSpacing.small)
                }
            }
        }
    }

    private func setupStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.seafoam)
            Text(label)
                .font(.caption2)
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
                    .lineLimit(1 ... 3)
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
                    Button {
                        focusedField = .criteria
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(AnchorPalette.link)
                            .frame(width: 44, height: 44)
                            .background(AnchorPalette.cyan.opacity(0.16), in: .circle)
                    }
                    .accessibilityLabel(L10n.keyboardDictation)
                }
                .frame(minHeight: 44)

                TextField(L10n.completionCriteria, text: $completionCriteria, axis: .vertical)
                    .font(.body)
                    .lineLimit(4 ... 7)
                    .focused($focusedField, equals: .criteria)
                    .accessibilityIdentifier("setup.criteria.field")
                    .harborInputSurface()
            }
        }
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
                Text("\(processCount)/6")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
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
}
#endif
