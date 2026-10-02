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
        VStack(alignment: .leading, spacing: 4) {
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
        let progress = task.conversationsInJoiningOrder.first?.progress?.formatted(.percent) ?? "—"
        return "\(states), \(L10n.taskProgress) \(progress)"
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
        let progress = task.conversationsInJoiningOrder.first?.progress
        let color = HostedTaskAppearance.tint(task)
        return HStack(spacing: 3) {
            ZStack {
                Circle().stroke(color.opacity(0.22), lineWidth: 2)
                if let progress {
                    Circle().trim(from: 0, to: min(1, max(0, progress)))
                        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
            .frame(width: 13, height: 13)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 3)
        .frame(width: 50, height: 17)
        .background(color.opacity(0.18), in: .capsule)
        .accessibilityLabel(L10n.taskProgress)
        .accessibilityValue(progress?.formatted(.percent) ?? "—")
    }
}
#endif
