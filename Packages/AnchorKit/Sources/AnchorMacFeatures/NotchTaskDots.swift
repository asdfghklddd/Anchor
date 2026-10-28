#if os(macOS)
import AnchorDesign
import SwiftUI

/// A dot per open task in its iPhone color, left of the housing. A thin arc
/// circles a task whose agent is running; a ring ripples out from one that
/// waits on the person. With no task yet, an empty ring.
struct NotchTaskDots: View {
    let tasks: [NotchIslandContent.Task]
    var flashes: [UUID: Int] = [:]

    var body: some View {
        HStack(spacing: NotchIslandMetrics.dotSpacing) {
            if tasks.isEmpty {
                Circle()
                    .strokeBorder(NotchIslandInk.faint, lineWidth: 1.5)
                    .frame(width: NotchIslandMetrics.dot, height: NotchIslandMetrics.dot)
            }
            ForEach(tasks) { task in
                NotchTaskDot(task: task, flash: flashes[task.id] ?? 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var summary: String {
        guard !tasks.isEmpty else { return EdgeMenuCopy.noTask }
        return tasks.map { task in
            NotchIslandCopy.taskState(task.title, task.conversation?.state ?? EdgeMenuCopy.noConversation)
        }
        .joined(separator: "\n")
    }
}

/// One task's dot. It lights up once when news about the task arrives.
struct NotchTaskDot: View {
    let task: NotchIslandContent.Task
    var flash = 0
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        let color = NotchIslandInk.task(task.colorIndex)
        let still = reduceMotion
        return ZStack {
            switch task.signal {
            case .running:
                NotchSpinner(color: color, diameter: 14)
            case .waiting:
                if reduceMotion {
                    Circle()
                        .stroke(color.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: NotchIslandMetrics.dot, height: NotchIslandMetrics.dot)
                        .keyframeAnimator(initialValue: 0.0, repeating: true) { ring, progress in
                            ring.scaleEffect(1 + progress * 1.3).opacity(0.85 * (1 - progress))
                        } keyframes: { _ in
                            CubicKeyframe(1, duration: 1.6)
                            LinearKeyframe(1, duration: 0.8)
                        }
                }
            case .idle, .done:
                EmptyView()
            }
            Circle()
                .fill(color.opacity(task.signal == .idle ? 0.45 : 1))
                .frame(width: NotchIslandMetrics.dot, height: NotchIslandMetrics.dot)
                .keyframeAnimator(initialValue: 1.0, trigger: flash) { dot, scale in
                    dot.scaleEffect(still ? 1 : scale)
                } keyframes: { _ in
                    SpringKeyframe(1.9, duration: 0.15, spring: .snappy)
                    SpringKeyframe(1, duration: 0.45, spring: .bouncy)
                }
        }
        .frame(width: NotchIslandMetrics.dot, height: NotchIslandMetrics.dot)
    }
}

/// A short arc going round, for work in progress. Still under Reduce Motion.
struct NotchSpinner: View {
    let color: Color
    let diameter: CGFloat
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        let arc = Circle()
            .trim(from: 0, to: 0.28)
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(width: diameter, height: diameter)
        if reduceMotion {
            arc.rotationEffect(.degrees(-90))
        } else {
            arc.keyframeAnimator(initialValue: 0.0, repeating: true) { view, angle in
                view.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                LinearKeyframe(360, duration: 1.2)
            }
        }
    }
}
#endif
