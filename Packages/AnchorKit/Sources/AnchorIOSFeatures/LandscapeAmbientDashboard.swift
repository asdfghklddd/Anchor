#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    let onResolve: (Decision, DecisionOption) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProcessID: UUID?
    @State private var selectedOptionID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            progressLight
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: AnchorSpacing.medium) {
                        decisionPanel
                        ambientWorkspace
                            .padding(.top, AnchorSpacing.xLarge)
                        ticker
                    }
                    .padding(AnchorSpacing.medium)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AnchorSpacing.medium) {
                        ambientWorkspace
                            .frame(maxWidth: .infinity)
                        decisionPanel
                            .frame(width: 300)
                    }
                    VStack(spacing: AnchorSpacing.medium) {
                        ambientWorkspace
                        decisionPanel
                    }
                }
                .padding(AnchorSpacing.medium)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                ticker
            }
        }
        .background(AnchorPalette.paper)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.screen")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            selectedProcessID = openDecision?.processID ?? projection.session?.processes.first?.id
        }
        .onChange(of: projection.openDecisions) { _, _ in
            selectedOptionID = nil
            if let openDecision { selectedProcessID = openDecision.processID }
        }
    }

    private var ambientWorkspace: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.date, style: .time)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AnchorPalette.ink)
                            .accessibilityIdentifier("ambient.time")
                        Text(L10n.ambient)
                            .font(.caption.bold())
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(focusDuration(at: context.date))
                            .font(.title.bold())
                        Text(L10n.focusTime)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }
                Text(projection.session?.goal.title ?? "")
                    .font(.title2.bold())
                    .lineLimit(2)
                    .foregroundStyle(AnchorPalette.ink)

                processSelector
            }
        }
    }

    @ViewBuilder
    private var processSelector: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AnchorSpacing.small) {
                ForEach(projection.session?.processes ?? []) { process in
                    ambientProcessButton(process)
                        .frame(minWidth: 112)
                }
            }
            if let process = selectedProcess ?? projection.session?.processes.first {
                ambientProcessButton(process)
            }
        }
    }

    private func ambientProcessButton(_ process: AnchorProcess) -> some View {
        ZStack {
            AmbientProcessCard(
                process: process,
                isSelected: selectedProcessID == process.id
            )
            Button {
                selectedProcessID = process.id
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(process.sourceName), \(process.metric), \(process.metricLabel), \(L10n.status(process.status))"
            )
            .accessibilityValue(
                process.progress?.formatted(.percent.precision(.fractionLength(0)))
                    ?? L10n.status(process.status)
            )
            .accessibilityAddTraits(selectedProcessID == process.id ? .isSelected : [])
        }
    }

    @ViewBuilder
    private var decisionPanel: some View {
        if let decision = selectedDecision ?? openDecision,
           let process = projection.session?.processes.first(where: { $0.id == decision.processID }) {
            InlineDecisionPanel(
                process: process,
                decision: decision,
                selectedOptionID: $selectedOptionID,
                onResolve: onResolve
            )
        } else if let process = selectedProcess {
            AnchorCard(tint: AnchorPalette.source(process.sourceTone)) {
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    Label(L10n.selectedProcess, systemImage: "scope")
                        .font(.caption.bold())
                    Text(process.title).font(.title2.bold())
                    Text(process.detail)
                        .font(.body)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    StatusBadge(status: process.status, text: L10n.status(process.status))
                    Spacer(minLength: 0)
                    Label(L10n.noAttentionNeeded, systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                        .accessibilityIdentifier("ambient.no-attention")
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            ContentUnavailableView(L10n.emptyTitle, systemImage: "scope")
        }
    }

    private var ticker: some View {
        HStack(spacing: AnchorSpacing.small) {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(AnchorPalette.coral)
                .accessibilityHidden(true)
            Text(projection.session?.timeline.first?.title ?? L10n.noEvents)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if let progress = projection.overallProgress {
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.headline)
            }
        }
        .padding(.horizontal, AnchorSpacing.medium)
        .frame(minHeight: 46)
        .background(AnchorPalette.surface)
        .accessibilityElement(children: .combine)
    }

    private var progressLight: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(projection.session?.processes ?? []) { process in
                    AnchorPalette.source(process.sourceTone)
                        .frame(width: proxy.size.width / CGFloat(max(projection.session?.processes.count ?? 1, 1)))
                }
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var openDecision: Decision? { projection.openDecisions.first }
    private var selectedDecision: Decision? {
        projection.openDecisions.first { $0.processID == selectedProcessID }
    }
    private var selectedProcess: AnchorProcess? {
        projection.session?.processes.first { $0.id == selectedProcessID }
    }
    private func focusDuration(at date: Date) -> String {
        guard let startedAt = projection.session?.startedAt else { return "—" }
        let minutes = max(0, Int(date.timeIntervalSince(startedAt) / 60))
        return L10n.minuteCount(minutes)
    }
}

private struct AmbientProcessCard: View {
    let process: AnchorProcess
    let isSelected: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let tint = AnchorPalette.source(process.sourceTone)
        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
            HStack(spacing: AnchorSpacing.xSmall) {
                Text(process.sourceName)
                    .font(.caption.bold())
                    .lineLimit(1)
                Spacer(minLength: AnchorSpacing.xSmall)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                }
                Image(systemName: statusSymbol)
            }
            .foregroundStyle(AnchorPalette.ink)

            Text(process.metric)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(process.metricLabel)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(2)
            Spacer(minLength: 2)
            if let progress = process.progress {
                AnchorProgress(value: progress, tint: tint)
            }
        }
        .padding(AnchorSpacing.small)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 160 : 112,
            alignment: .topLeading
        )
        .background(tint.opacity(0.23), in: .rect(cornerRadius: 18))
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tint, lineWidth: 3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    private var statusSymbol: String {
        switch process.status {
        case .needsDecision: "exclamationmark.bubble.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .disconnected: "wifi.slash"
        case .queued: "clock"
        case .running: "play.fill"
        case .blocked: "pause.fill"
        }
    }

}

private struct InlineDecisionPanel: View {
    let process: AnchorProcess
    let decision: Decision
    @Binding var selectedOptionID: UUID?
    let onResolve: (Decision, DecisionOption) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AnchorCard(tint: AnchorPalette.sand) {
            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                if dynamicTypeSize.isAccessibilitySize {
                    Text(decision.title)
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AnchorPalette.sand, in: .rect(cornerRadius: 10))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityHint(decision.prompt)
                } else {
                    HStack(spacing: AnchorSpacing.small) {
                        StatusBadge(
                            status: .needsDecision,
                            text: L10n.attentionNeeded,
                            decorative: true
                        )
                        Text(decision.title)
                            .font(.headline.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(AnchorPalette.sand, in: .rect(cornerRadius: 10))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityHint(decision.prompt)
                    }
                }

                ForEach(decision.options) { option in
                    Button {
                        selectedOptionID = option.id
                    } label: {
                        HStack {
                            Image(systemName: selectedOptionID == option.id ? "checkmark.circle.fill" : "circle")
                                .accessibilityHidden(true)
                            Text(option.title)
                                .font(.subheadline.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .foregroundStyle(
                            selectedOptionID == option.id
                                ? Color.black
                                : AnchorPalette.ink
                        )
                        .padding(.horizontal, AnchorSpacing.small)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            selectedOptionID == option.id
                                ? AnchorPalette.sand
                                : AnchorPalette.paper,
                            in: .rect(cornerRadius: 14)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(option.detail)
                    .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                    .accessibilityIdentifier(
                        option.id == decision.options.first?.id
                            ? "ambient.decision.option.first"
                            : "ambient.decision.option.\(option.id.uuidString)"
                    )
                }
                Button {
                    guard let selectedOptionID,
                          let option = decision.options.first(where: { $0.id == selectedOptionID }) else { return }
                    onResolve(decision, option)
                    self.selectedOptionID = nil
                } label: {
                    Text(L10n.confirmChoice)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AnchorPalette.deepSea, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(AmbientConfirmButtonStyle())
                .disabled(selectedOptionID == nil)
                .accessibilityIdentifier("ambient.decision.confirm")
            }
        }
    }
}

private struct AmbientConfirmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
#endif
