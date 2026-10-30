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
                    NotchLayerMotion(motion: .ripple, color: color, diameter: NotchIslandMetrics.dot)
                        .frame(width: NotchIslandMetrics.dot, height: NotchIslandMetrics.dot)
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
            NotchLayerMotion(motion: .spin, color: color, diameter: diameter)
                .frame(width: diameter, height: diameter)
        }
    }
}

/// The island's endless motions, run by Core Animation. The island stays on
/// screen all day, and a SwiftUI animation that never ends lays the window
/// out on every frame; a layer animation costs the app nothing between frames.
struct NotchLayerMotion: NSViewRepresentable {
    enum Motion {
        /// A short arc going round once every 1.2 s.
        case spin
        /// A ring that swells and fades over 1.6 s, then rests 0.8 s.
        case ripple
    }

    let motion: Motion
    let color: Color
    let diameter: CGFloat

    func makeNSView(context: Context) -> MotionView { MotionView(motion: motion) }

    func updateNSView(_ view: MotionView, context: Context) {
        view.update(color: NSColor(color).cgColor, diameter: diameter)
    }

    final class MotionView: NSView {
        private let motion: Motion
        private let shape = CAShapeLayer()

        init(motion: Motion) {
            self.motion = motion
            super.init(frame: .zero)
            wantsLayer = true
            layer?.masksToBounds = false
            shape.fillColor = nil
            shape.lineWidth = 1.5
            shape.lineCap = .round
            layer?.addSublayer(shape)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        func update(color: CGColor, diameter: CGFloat) {
            shape.strokeColor = color
            let bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            guard shape.bounds != bounds else { return }
            shape.bounds = bounds
            let circle = CGPath(ellipseIn: bounds.insetBy(dx: 0.75, dy: 0.75), transform: nil)
            shape.path = circle
            if motion == .spin {
                shape.strokeStart = 0
                shape.strokeEnd = 0.28
            }
            needsLayout = true
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shape.position = CGPoint(x: bounds.midX, y: bounds.midY)
            CATransaction.commit()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            shape.removeAllAnimations()
            guard let window else { return }
            shape.contentsScale = window.backingScaleFactor
            switch motion {
            case .spin:
                let turn = CABasicAnimation(keyPath: "transform.rotation.z")
                // Clockwise, as the arc turns everywhere else in Anchor.
                turn.fromValue = 0
                turn.toValue = -2 * Double.pi
                turn.duration = 1.2
                turn.repeatCount = .infinity
                shape.add(turn, forKey: "spin")
            case .ripple:
                let swell = CABasicAnimation(keyPath: "transform.scale")
                swell.fromValue = 1
                swell.toValue = 2.3
                let fade = CABasicAnimation(keyPath: "opacity")
                fade.fromValue = 0.85
                fade.toValue = 0
                for part in [swell, fade] {
                    part.duration = 1.6
                    part.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    part.fillMode = .forwards
                }
                let ripple = CAAnimationGroup()
                ripple.animations = [swell, fade]
                ripple.duration = 2.4
                ripple.repeatCount = .infinity
                shape.opacity = 0
                shape.add(ripple, forKey: "ripple")
            }
        }
    }
}
#endif
