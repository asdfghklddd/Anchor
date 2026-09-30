#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HostedTaskCard: View {
    let task: AnchorSession
    let height: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        .accessibilityValue(task.taskProcesses.map { L10n.status($0.status) }.joined(separator: ", ") + ", " + L10n.taskProgress + " " + (task.conversationsInJoiningOrder.first?.progress?.formatted(.percent) ?? "—"))
    }

    @ViewBuilder private var status: some View {
        if HostedTaskAppearance.isComplete(task) {
            VStack(spacing: 0) {
                Image(systemName: "medal.fill").font(.caption2).foregroundStyle(AnchorIOSStyle.yellow)
                Text("GET").font(.system(.caption2, design: .rounded).weight(.heavy))
                    .foregroundStyle(AnchorIOSStyle.text)
            }
        } else {
            HStack(spacing: 3) {
                dot(active: task.taskProcesses.contains { $0.status == .running } || (task.taskProcesses.isEmpty && task.status == .active), color: .green)
                dot(active: task.taskProcesses.contains { [.failed, .blocked, .disconnected].contains($0.status) }, color: .red)
                if task.taskProcesses.contains(where: { $0.status == .needsDecision }) {
                    Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(AnchorIOSStyle.yellow)
                        .frame(width: 12, height: 12)
                } else {
                    dot(active: false, color: AnchorIOSStyle.yellow)
                }
            }
            .padding(.top, 3)
        }
    }

    private func dot(active: Bool, color: Color) -> some View {
        Circle().fill(active ? color : AnchorIOSStyle.border).frame(width: 12, height: 12)
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
