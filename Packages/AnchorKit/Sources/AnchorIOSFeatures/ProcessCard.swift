#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProcessCard: View {
    let process: AnchorProcess
    let isRemote: Bool
    var decorative = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(process.sourceName)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    .lineLimit(1)
                Spacer(minLength: 4)
                statusPill
            }

            Text(process.title)
                .font(.footnote.bold())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .accessibilityIdentifier("process.card.title")

            if process.status == .needsDecision {
                decisionContent
            } else {
                metricContent
            }

            if process.status != .needsDecision, let progress = process.progress {
                HStack(spacing: 7) {
                    AnchorProgress(value: progress, tint: tint, isRemote: isRemote)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(width: 30, alignment: .trailing)
                        .accessibilityIdentifier("process.card.progress")
                }
            }
        }
        .padding(8)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 190 : 122,
            alignment: .topLeading
        )
        .background(
            LinearGradient(
                colors: AnchorPalette.sourceSurface(process.sourceTone, dark: colorScheme == .dark),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(colorScheme == .dark ? 0.14 : 0.66))
                .frame(height: 2)
                .padding(.horizontal, 20)
        }
        .overlay(alignment: .topTrailing) {
            if process.status == .needsDecision {
                Circle()
                    .fill(AnchorPalette.sand)
                    .frame(width: 7, height: 7)
                    .shadow(color: AnchorPalette.sand.opacity(0.42), radius: 6)
                    .padding(15)
            }
        }
        .shadow(
            color: process.status == .needsDecision ? AnchorPalette.sand.opacity(0.20) : tint.opacity(0.17),
            radius: process.status == .needsDecision ? 15 : 12,
            y: 8
        )
        .overlay {
            if process.status == .needsDecision {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(AnchorPalette.sand.opacity(0.14), lineWidth: 4)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.96)
        .offset(y: hasAppeared ? 0 : 12)
        .animation(reduceMotion ? nil : .spring(duration: 0.55), value: hasAppeared)
        .task { hasAppeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(process.sourceName), \(process.title), \(statusText)")
        .accessibilityValue(process.progress?.formatted(.percent.precision(.fractionLength(0))) ?? statusText)
        .accessibilityHidden(decorative)
    }

    private var statusPill: some View {
        Label(statusText, systemImage: statusSymbol)
            .font(.caption2.bold())
            .foregroundStyle(
                process.status == .needsDecision
                    ? Color(red: 0.47, green: 0.32, blue: 0)
                    : AnchorPalette.sourceInk(process.sourceTone)
            )
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(
                process.status == .needsDecision ? AnchorPalette.warmYellow : .white.opacity(0.55),
                in: .capsule
            )
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("process.card.status")
    }

    private var metricContent: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ProcessMiniVisual(tone: process.sourceTone, tint: tint, progress: process.progress ?? 0)
                .frame(maxWidth: 58, alignment: .leading)
            VStack(alignment: .trailing, spacing: 0) {
                Text(process.metric)
                    .font(.title.bold().monospacedDigit())
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    .accessibilityIdentifier("process.card.metric")
                Text(process.metricLabel)
                    .font(.caption2)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .accessibilityIdentifier("process.card.metric.label")
            }
        }
        .frame(minHeight: 34)
    }

    private var decisionContent: some View {
        HStack(spacing: 7) {
            ZStack(alignment: .leading) {
                ForEach(0 ..< 3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.72))
                        .frame(width: 34, height: 26)
                        .offset(x: CGFloat(index) * 7)
                }
            }
            .frame(width: 50, height: 30)

            Text(process.metric)
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(tint)
                .accessibilityIdentifier("process.card.metric")
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Label(L10n.goChooseDirection, systemImage: "arrow.right.circle")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(AnchorPalette.deepSea, in: .capsule)
                .offset(y: 24)
                .accessibilityIdentifier("process.card.action")
        }
        .padding(.bottom, 22)
    }

    private var tint: Color {
        AnchorPalette.source(process.sourceTone)
    }

    private var statusText: String {
        switch process.status {
        case .running: process.sourceTone == "cyan" ? L10n.rendering : L10n.generating
        case .needsDecision: L10n.waitingConfirmation
        case .queued: L10n.preparing
        default: L10n.compactStatus(process.status)
        }
    }

    private var statusSymbol: String {
        switch process.status {
        case .running: "waveform.path.ecg"
        case .needsDecision: "exclamationmark.circle"
        case .queued: "timer"
        case .blocked: "pause.fill"
        case .completed: "checkmark"
        case .failed: "xmark"
        case .disconnected: "wifi.slash"
        }
    }
}
#endif
