#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HostedTaskCard: View {
    let task: AnchorSession
    let height: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 20
    @AnchorReducedMotion private var reduceMotion
    // Indicators grow with the text they sit beside.
    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption2) private var ringSize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                Text(task.goal.title).font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                status
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                progressCapsule
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: height, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : height, alignment: .topLeading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 16))
        .shadow(color: AnchorIOSStyle.heading.opacity(0.10), radius: 9, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.goal.title)
        .accessibilityValue(accessibleStatus)
    }

    private var accessibleStatus: String {
        let states = HostedTaskAppearance.isComplete(task)
            ? L10n.completed
            : task.taskProcesses.map { L10n.processStatus($0) }.joined(separator: ", ")
        return "\(states), \(L10n.taskProgress) \(progressText)"
    }

    private var displayedProgress: Double? {
        guard let value = task.conversationsInJoiningOrder.first?.progress, value.isFinite else { return nil }
        return min(1, max(0, value))
    }

    private var progressText: String {
        displayedProgress?.formatted(.percent.precision(.fractionLength(0))) ?? L10n.unknown
    }

    /// Progress and status refresh in place; spatial easing is dropped when motion is reduced.
    private var liveValueAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity
    }

    private var status: some View {
        let indicator = HostedTaskIndicator(task: task)
        return ZStack(alignment: .topTrailing) {
            if indicator.isComplete {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.success)
                    .frame(width: 26, height: 26)
                    .accessibilityLabel(L10n.completed)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            } else {
                HStack(spacing: 3) {
                    dot(active: indicator.isRunning, color: .green, symbol: "play.fill")
                    dot(active: indicator.hasFailure, color: .red, symbol: "xmark")
                    dot(active: indicator.hasWarning, color: AnchorIOSStyle.yellow, symbol: "pause.fill")
                }
                .padding(.top, 3)
                .transition(.opacity)
            }
        }
        // One short cue when completion arrives; the seal then stays still.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.36, bounce: 0.3),
                   value: indicator.isComplete)
    }

    private func dot(active: Bool, color: Color, symbol: String) -> some View {
        Circle().fill(active ? color : AnchorIOSStyle.border)
            .frame(width: dotSize, height: dotSize)
            .overlay {
                if active && differentiateWithoutColor {
                    Image(systemName: symbol).font(.system(size: dotSize * 0.58, weight: .heavy))
                        .foregroundStyle(AnchorIOSStyle.onAccent)
                }
            }
            // A light turning on pulses once. Turning off, refreshes and the first
            // appearance stay still, so repeated syncs never re-announce a state.
            .keyframeAnimator(initialValue: CGFloat(1), trigger: active) { light, scale in
                light.scaleEffect(scale)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(active && !reduceMotion ? 1.45 : 1, duration: 0.12)
                    SpringKeyframe(1, duration: 0.32, spring: .bouncy)
                }
            }
            .animation(AnchorMotion.micro, value: active)
    }

    private var progressCapsule: some View {
        let progress = displayedProgress
        let color = HostedTaskAppearance.tint(task)
        return HStack(spacing: 5) {
            Group {
                if let progress {
                    ZStack {
                        Circle().stroke(color.opacity(0.25), lineWidth: 2)
                        Circle().trim(from: 0, to: progress)
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(liveValueAnimation, value: progress)
                    }
                } else {
                    Image(systemName: "questionmark")
                        .font(.caption2.weight(.semibold))
                }
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityHidden(true)
            Text(progressText)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: progress ?? 0))
                .animation(liveValueAnimation, value: progressText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(AnchorIOSStyle.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minWidth: 62)
        .background(color.opacity(0.18), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.taskProgress)
        .accessibilityValue(progressText)
    }
}
#endif
