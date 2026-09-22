#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProcessCard: View {
    let process: AnchorProcess
    let isRemote: Bool
    var decorative = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)
                Spacer(minLength: 4)
                statusPill
            }

            Text(process.title)
                .font(.subheadline.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .accessibilityIdentifier("process.card.title")

            if process.status == .needsDecision {
                decisionContent
            } else {
                metricContent
            }

            if process.status != .needsDecision, let progress = process.progress {
                HStack(spacing: 7) {
                    AnchorProgress(value: progress, tint: AnchorPalette.interaction, isRemote: isRemote)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.secondaryText)
                        .contentTransition(reduceMotion ? .opacity : .numericText(value: progress))
                        .frame(width: 34, alignment: .trailing)
                        .accessibilityIdentifier("process.card.progress")
                }
                .animation(liveValueAnimation, value: progress)
            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 190 : 142,
            alignment: .topLeading
        )
        .fluoriteSurface(
            fill: process.status == .needsDecision
                ? AnchorPalette.attention.opacity(0.12)
                : AnchorPalette.fluoriteSurface,
            border: process.status == .needsDecision
                ? AnchorPalette.attention.opacity(0.72)
                : AnchorPalette.fluoriteBorder,
            cornerRadius: 14,
            elevated: process.status == .needsDecision
        )
        .animation(liveValueAnimation, value: process.status)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(process.sourceName), \(process.title), \(statusText)")
        .accessibilityValue(process.progress?.formatted(.percent.precision(.fractionLength(0))) ?? statusText)
        .accessibilityHidden(decorative)
    }

    private var statusPill: some View {
        Label(statusText, systemImage: statusSymbol)
            .font(.caption2.bold())
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 8)
            .frame(minHeight: 24)
            .background(statusBackground, in: .capsule)
            .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
            .accessibilityIdentifier("process.card.status")
    }

    private var metricContent: some View {
        HStack(alignment: .bottom, spacing: 7) {
            if let progress = process.progress {
                ProcessMiniVisual(tone: process.sourceTone, tint: tint, progress: progress)
                    .frame(maxWidth: 58, alignment: .leading)
            }
            VStack(alignment: .trailing, spacing: 0) {
                Text(process.metric)
                    .font(.title2.bold().monospacedDigit())
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .contentTransition(reduceMotion ? .opacity : .numericText())
                    .animation(liveValueAnimation, value: process.metric)
                    .accessibilityIdentifier("process.card.metric")
                Text(process.metricLabel)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryText)
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
                        .fill(AnchorPalette.softBlue.opacity(0.76))
                        .frame(width: 34, height: 26)
                        .offset(x: CGFloat(index) * 7)
                }
            }
            .frame(width: 50, height: 30)

            Text(process.metric)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.brandDeep)
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .animation(liveValueAnimation, value: process.metric)
                .accessibilityIdentifier("process.card.metric")
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottom) {
            Label(L10n.goChooseDirection, systemImage: "arrow.right.circle")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 30)
                .background(AnchorPalette.interaction, in: .rect(cornerRadius: 10))
                .offset(y: 24)
                .accessibilityIdentifier("process.card.action")
        }
        .padding(.bottom, 22)
    }

    private var tint: Color {
        process.status == .needsDecision ? AnchorPalette.attention : AnchorPalette.aiBlue
    }

    private var liveValueAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.micro
    }

    private var statusForeground: Color {
        switch process.status {
        case .needsDecision, .blocked:
            AnchorPalette.brandDeep
        case .failed, .disconnected:
            .red
        default:
            AnchorPalette.interaction
        }
    }

    private var statusBackground: Color {
        switch process.status {
        case .needsDecision, .blocked:
            AnchorPalette.attention.opacity(0.24)
        case .failed, .disconnected:
            Color.red.opacity(0.10)
        default:
            AnchorPalette.softBlue.opacity(0.52)
        }
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
