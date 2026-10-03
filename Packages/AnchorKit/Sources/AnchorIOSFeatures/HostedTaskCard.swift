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

    @ViewBuilder private var status: some View {
        let indicator = HostedTaskIndicator(task: task)
        if indicator.isComplete {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.success)
                .frame(width: 26, height: 26)
                .accessibilityLabel(L10n.completed)
        } else {
            HStack(spacing: 3) {
                dot(active: indicator.isRunning, color: .green, symbol: "play.fill")
                dot(active: indicator.hasFailure, color: .red, symbol: "xmark")
                dot(active: indicator.hasWarning, color: AnchorIOSStyle.yellow, symbol: "pause.fill")
            }
            .padding(.top, 3)
        }
    }

    private func dot(active: Bool, color: Color, symbol: String) -> some View {
        Circle().fill(active ? color : AnchorIOSStyle.border)
            .frame(width: 12, height: 12)
            .overlay {
                if active && differentiateWithoutColor {
                    Image(systemName: symbol).font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(AnchorIOSStyle.onAccent)
                }
            }
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
                    }
                } else {
                    Image(systemName: "questionmark")
                        .font(.caption2.weight(.semibold))
                }
            }
            .frame(width: 13, height: 13)
            .accessibilityHidden(true)
            Text(progressText)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
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
