#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct AnchorSetupView: View {
    let model: AnchorSessionModel

    @State private var goalTitle = ""
    @State private var completionCriteria = ""
    @State private var context = ""
    @State private var processNames = [""]
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case goal
        case criteria
        case context
        case process(Int)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                    AnchorMark(size: 64)
                    Text(L10n.establishAnchor)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AnchorPalette.ink)
                    Text(L10n.setupIntro)
                        .font(.title3)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
                .accessibilityElement(children: .combine)

                AnchorCard(tint: AnchorPalette.seafoam) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        TextField(L10n.goalTitle, text: $goalTitle, axis: .vertical)
                            .font(.title2.bold())
                            .focused($focusedField, equals: .goal)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .criteria }
                        Divider()
                        TextField(L10n.completionCriteria, text: $completionCriteria, axis: .vertical)
                            .focused($focusedField, equals: .criteria)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .context }
                        Divider()
                        TextField(L10n.contextNote, text: $context, axis: .vertical)
                            .focused($focusedField, equals: .context)
                    }
                    .textFieldStyle(.plain)
                }

                VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                    Text(L10n.processes)
                        .font(.headline)
                    ForEach(processNames.indices, id: \.self) { index in
                        HStack {
                            TextField(L10n.processName, text: $processNames[index])
                                .focused($focusedField, equals: .process(index))
                                .textFieldStyle(.roundedBorder)
                                .frame(minHeight: 44)
                            if processNames.count > 1 {
                                Button(role: .destructive) {
                                    processNames.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel(L10n.delete)
                            }
                        }
                    }
                    Button {
                        processNames.append("")
                        focusedField = .process(processNames.endIndex - 1)
                    } label: {
                        Label(L10n.addProcess, systemImage: "plus.circle.fill")
                    }
                    .disabled(processNames.count >= 6)
                    .frame(minHeight: 44)
                }

                Label(L10n.setupHint, systemImage: "mic.fill")
                    .font(.footnote)
                    .foregroundStyle(AnchorPalette.secondaryInk)

                Button(L10n.beginSession) {
                    establishSession()
                }
                .buttonStyle(AnchorPrimaryButtonStyle())
                .disabled(!isValid)
            }
            .padding(AnchorSpacing.large)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .navigationBarHidden(true)
        .accessibilityIdentifier("setup.screen")
    }

    private var isValid: Bool {
        !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        processNames.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func establishSession() {
        let tones = ["coral", "periwinkle", "cyan", "ink", "seafoam", "sand"]
        let processes = processNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, name in
                AnchorProcess(
                    sourceName: name,
                    sourceSymbol: name.first.map(String.init) ?? "•",
                    sourceTone: tones[index % tones.count],
                    title: name,
                    status: .queued,
                    metric: "—",
                    metricLabel: L10n.lastUpdated,
                    detail: L10n.noEvents
                )
            }
        let goal = AnchorGoal(
            title: goalTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            completionCriteria: completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines),
            note: context.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        Task { await model.createSession(goal: goal, processes: processes) }
    }
}
#endif
