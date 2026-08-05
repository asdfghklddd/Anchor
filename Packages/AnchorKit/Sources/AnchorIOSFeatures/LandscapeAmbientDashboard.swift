#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    let onResolve: (Decision, DecisionOption) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var inspectedProcessID: UUID?
    @State private var selectedOptionID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            progressEdge
            ambientHeader

            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 12) {
                        goalLine
                        processGrid
                        inspector
                    }
                    .padding(12)
                }
            } else {
                HStack(spacing: 10) {
                    VStack(spacing: 9) {
                        goalLine
                        processGrid
                    }
                    .frame(maxWidth: .infinity)

                    inspector
                        .frame(width: 310)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 9)
            }

            ticker
        }
        .background(AnchorPalette.paper)
        .overlay(alignment: .trailing) {
            if openDecision != nil {
                Capsule()
                    .fill(AnchorPalette.sand)
                    .frame(width: 3, height: 78)
                    .shadow(color: AnchorPalette.sand.opacity(0.5), radius: 8)
                    .accessibilityHidden(true)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .onAppear {
            inspectedProcessID = openDecision?.processID ?? projection.session?.processes.first?.id
            selectedOptionID = openDecision?.options.dropFirst().first?.id ?? openDecision?.options.first?.id
        }
        .onChange(of: projection.openDecisions) { _, _ in
            inspectedProcessID = openDecision?.processID ?? inspectedProcessID
            selectedOptionID = openDecision?.options.dropFirst().first?.id ?? openDecision?.options.first?.id
        }
    }

    private var ambientHeader: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(context.date, style: .time)
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.ink)
                        .accessibilityLabel(context.date.formatted(date: .omitted, time: .shortened))
                        .accessibilityValue(L10n.ambientActive)
                        .accessibilityIdentifier("ambient.time")
                    if !dynamicTypeSize.isAccessibilitySize {
                        Label(L10n.ambientActive, systemImage: "circle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(AnchorPalette.mintInk)
                            .accessibilityHidden(true)
                    }
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(L10n.focusTime)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Text(focusDuration(at: context.date))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.ink)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
        }
    }

    private var goalLine: some View {
        HStack(spacing: 10) {
            HarborBrandMark(size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(L10n.currentGoal) · \(L10n.anchoredCount((projection.session?.notes.count ?? 0) + 1))")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.68))
                Text(projection.session?.goal.title ?? "")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .accessibilityIdentifier("ambient.screen")
            }
            Spacer(minLength: 8)
            if let progress = projection.overallProgress {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.warmYellow)
                    Text(L10n.overallProgress)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.45))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: 60)
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.31, blue: 0.40), AnchorPalette.deepSea],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 19, style: .continuous)
        )
        .shadow(color: AnchorPalette.deepSea.opacity(0.18), radius: 10, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var processGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(projection.session?.processes ?? []) { process in
                Button {
                    inspectedProcessID = process.id
                    if let decision = projection.openDecisions.first(where: { $0.processID == process.id }) {
                        selectedOptionID = decision.options.dropFirst().first?.id ?? decision.options.first?.id
                    }
                } label: {
                    AmbientProcessTile(process: process, selected: inspectedProcessID == process.id)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(process.sourceName), \(process.title), \(L10n.status(process.status))")
                .accessibilityValue(process.progress?.formatted(.percent.precision(.fractionLength(0))) ?? L10n.status(process.status))
                .accessibilityAddTraits(inspectedProcessID == process.id ? .isSelected : [])
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.45), value: inspectedProcessID)
    }

    @ViewBuilder
    private var inspector: some View {
        if let decision = selectedDecision ?? openDecision,
           let process = projection.session?.processes.first(where: { $0.id == decision.processID }) {
            AmbientDecisionInspector(
                process: process,
                decision: decision,
                selectedOptionID: $selectedOptionID,
                onResolve: onResolve
            )
        } else if let process = inspectedProcess {
            AmbientProcessInspector(process: process)
        } else {
            VStack(spacing: 8) {
                HarborBrandMark(size: 52)
                Text(L10n.allProcessesRunning).font(.headline.bold())
                Text(L10n.noAttentionNeeded).font(.caption).foregroundStyle(AnchorPalette.secondaryInk)
            }
            .foregroundStyle(AnchorPalette.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AnchorPalette.seafoam.opacity(0.18), in: .rect(cornerRadius: 20, style: .continuous))
            .accessibilityIdentifier("ambient.no-attention")
        }
    }

    private var ticker: some View {
        HStack(spacing: 10) {
            if !dynamicTypeSize.isAccessibilitySize {
                Label(L10n.latestProgress, systemImage: "waveform.path.ecg")
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.link)
                Divider().frame(height: 18)
            }
            Text(tickerText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.interpolate)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(AnchorPalette.surface)
        .accessibilityElement(children: .combine)
    }

    private var progressEdge: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(projection.session?.processes ?? []) { process in
                    ZStack(alignment: .leading) {
                        AnchorPalette.source(process.sourceTone).opacity(0.18)
                        AnchorPalette.source(process.sourceTone)
                            .frame(width: proxy.size.width / CGFloat(max(processCount, 1)) * (process.progress ?? 0))
                    }
                    .frame(width: proxy.size.width / CGFloat(max(processCount, 1)))
                }
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var openDecision: Decision? { projection.openDecisions.first }
    private var selectedDecision: Decision? {
        projection.openDecisions.first { $0.processID == inspectedProcessID }
    }
    private var inspectedProcess: AnchorProcess? {
        projection.session?.processes.first { $0.id == inspectedProcessID }
    }
    private var processCount: Int { projection.session?.processes.count ?? 0 }
    private var tickerText: String {
        let text = projection.session?.timeline.prefix(3).map(\.title).joined(separator: "  ·  ") ?? ""
        return text.isEmpty ? L10n.noEvents : text
    }
    private func focusDuration(at date: Date) -> String {
        guard let startedAt = projection.session?.startedAt else { return "—" }
        return L10n.minuteCount(max(0, Int(date.timeIntervalSince(startedAt) / 60)))
    }
}

private struct AmbientProcessTile: View {
    let process: AnchorProcess
    let selected: Bool

    var body: some View {
        let tint = AnchorPalette.source(process.sourceTone)
        HStack(spacing: 8) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 31)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(process.sourceName)
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .accessibilityIdentifier("ambient.tile.source")
                    Spacer(minLength: 0)
                    Image(systemName: statusSymbol).font(.caption2.bold()).foregroundStyle(tint)
                }
                Text(process.title)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
                    .accessibilityIdentifier("ambient.tile.title")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(process.metric).font(.headline.bold().monospacedDigit()).foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    Spacer(minLength: 0)
                    Text(process.progress ?? 0, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.bold().monospacedDigit())
                }
                if let progress = process.progress {
                    AnchorProgress(value: progress, tint: tint)
                }
            }
        }
        .foregroundStyle(AnchorPalette.ink)
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            if selected || process.status == .needsDecision {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(process.status == .needsDecision ? AnchorPalette.sand : tint, lineWidth: selected ? 2.5 : 1.5)
            }
        }
        .shadow(color: tint.opacity(0.12), radius: 7, y: 4)
        .accessibilityHidden(true)
    }

    private var statusSymbol: String {
        switch process.status {
        case .running: "waveform.path.ecg"
        case .needsDecision: "exclamationmark.circle.fill"
        case .queued: "timer"
        case .blocked: "pause.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .disconnected: "wifi.slash"
        }
    }
}

private struct AmbientDecisionInspector: View {
    let process: AnchorProcess
    let decision: Decision
    @Binding var selectedOptionID: UUID?
    let onResolve: (Decision, DecisionOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspectorHeader

            HStack(spacing: 9) {
                StoryboardPreview(tint: AnchorPalette.source(process.sourceTone), compact: true)
                    .frame(width: 94, height: 64)
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.metric + " " + process.metricLabel)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                        .accessibilityIdentifier("ambient.inspector.metric")
                    Text(process.title)
                        .font(.headline.bold())
                        .lineLimit(2)
                        .accessibilityIdentifier("ambient.inspector.title")
                    Text(process.detail).font(.caption2).foregroundStyle(AnchorPalette.secondaryInk).lineLimit(2)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(decision.options.enumerated()), id: \.element.id) { index, option in
                    Button { selectedOptionID = option.id } label: {
                        VStack(spacing: 4) {
                            StoryboardPreview(
                                tint: index == 0 ? AnchorPalette.coral : index == 1 ? AnchorPalette.periwinkle : AnchorPalette.cyan,
                                compact: true
                            )
                            .frame(height: 34)
                            Text(String(Character(UnicodeScalar(65 + index)!)))
                                .font(.caption2.bold())
                        }
                        .foregroundStyle(AnchorPalette.ink)
                        .padding(5)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedOptionID == option.id ? AnchorPalette.warmYellow : AnchorPalette.paper,
                            in: .rect(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            if selectedOptionID == option.id {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AnchorPalette.sand, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.title)
                    .accessibilityHint(option.detail)
                    .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                    .accessibilityIdentifier(index == 0 ? "ambient.decision.option.first" : "ambient.decision.option.\(option.id.uuidString)")
                }
            }

            Button {
                guard let selectedOptionID,
                      let option = decision.options.first(where: { $0.id == selectedOptionID }) else { return }
                onResolve(decision, option)
                self.selectedOptionID = nil
            } label: {
                HStack {
                    Text(L10n.confirmChoice)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .accessibilityIdentifier("ambient.decision.confirm.label")
            }
            .buttonStyle(HarborPrimaryButtonStyle())
            .disabled(selectedOptionID == nil)
            .accessibilityIdentifier("ambient.decision.confirm")
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AnchorPalette.sand.opacity(0.72), lineWidth: 2)
        }
        .shadow(color: AnchorPalette.sand.opacity(0.16), radius: 12, y: 7)
    }

    private var inspectorHeader: some View {
        HStack(spacing: 8) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(process.sourceName).font(.caption.bold())
                Label(L10n.attentionNeeded, systemImage: "exclamationmark.circle.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 0))
            }
            Spacer()
        }
    }
}

private struct AmbientProcessInspector: View {
    let process: AnchorProcess

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.sourceName).font(.caption.bold())
                    Text(L10n.status(process.status)).font(.caption2).foregroundStyle(AnchorPalette.secondaryInk)
                }
            }
            Text(process.title).font(.title3.bold()).foregroundStyle(AnchorPalette.ink)
            Text(process.detail).font(.caption).foregroundStyle(AnchorPalette.secondaryInk)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text(process.metric).font(.title.bold().monospacedDigit()).foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                Text(process.metricLabel).font(.caption).foregroundStyle(AnchorPalette.secondaryInk)
            }
            if let progress = process.progress {
                AnchorProgress(value: progress, tint: AnchorPalette.source(process.sourceTone))
            }
            Label(L10n.noAttentionNeeded, systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.mintInk)
                .accessibilityIdentifier("ambient.no-attention")
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20, style: .continuous)
        )
    }
}
#endif
