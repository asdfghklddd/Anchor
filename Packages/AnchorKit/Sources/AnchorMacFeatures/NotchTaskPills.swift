#if os(macOS)
import AnchorDesign
import SwiftUI

/// A pill per open task in its iPhone color, stacked left of the housing in
/// the order the open island lists them. A light sweeps along a task whose
/// agent is running; an outline ripples from one that waits on the person.
/// With no task yet, an empty outline.
struct NotchTaskPills: View {
    let tasks: [NotchIslandContent.Task]
    var flashes: [UUID: Int] = [:]

    var body: some View {
        VStack(spacing: NotchIslandMetrics.pillSpacing) {
            if tasks.isEmpty {
                Capsule()
                    .strokeBorder(NotchIslandInk.faint, lineWidth: 1)
                    .frame(width: NotchIslandMetrics.pillWidth, height: NotchIslandMetrics.pillHeight + 1)
            }
            ForEach(tasks) { task in
                NotchTaskPill(task: task, flash: flashes[task.id] ?? 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityIdentifier("notch.tasks")
    }

    private var summary: String {
        guard !tasks.isEmpty else { return EdgeMenuCopy.noTask }
        return tasks.map { task in
            NotchIslandCopy.taskState(task.title, task.conversation?.state ?? EdgeMenuCopy.noConversation)
        }
        .joined(separator: "\n")
    }
}

/// One task's pill. It swells once when news about the task arrives.
struct NotchTaskPill: View {
    let task: NotchIslandContent.Task
    var flash = 0
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        let color = NotchIslandInk.task(task.colorIndex)
        let size = CGSize(width: NotchIslandMetrics.pillWidth, height: NotchIslandMetrics.pillHeight)
        let still = reduceMotion
        return Capsule()
            .fill(color.opacity(task.signal == .idle ? 0.45 : 1))
            .overlay {
                switch task.signal {
                case .running:
                    if still {
                        Capsule().fill(.white.opacity(0.5)).frame(width: 4)
                    } else {
                        NotchPillMotion(motion: .sweep, color: color, size: size)
                    }
                case .waiting:
                    if still {
                        Capsule().stroke(color.opacity(0.6), lineWidth: 1).padding(-1.5)
                    } else {
                        NotchPillMotion(motion: .ripple, color: color, size: size)
                    }
                case .idle, .done:
                    EmptyView()
                }
            }
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: 1.0, trigger: flash) { pill, scale in
                pill.scaleEffect(still ? 1 : scale)
            } keyframes: { _ in
                SpringKeyframe(1.5, duration: 0.15, spring: .snappy)
                SpringKeyframe(1, duration: 0.45, spring: .bouncy)
            }
    }
}

/// How far the current task's plan has come, in its color, right of the
/// housing: an arc for the steps marked done, closing into a ring with a
/// check once every step is.
struct NotchPlanRing: View {
    let progress: NotchIslandContent.Progress
    let color: Color

    var body: some View {
        let line: CGFloat = 2
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: line)
            Circle()
                .trim(from: 0, to: progress.fraction)
                .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress.isFinished {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .heavy))
                    .foregroundStyle(color)
            }
        }
        .frame(width: NotchIslandMetrics.ring, height: NotchIslandMetrics.ring)
        .animation(.smooth(duration: 0.4), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PlanText.stepsDone(progress.done, of: progress.total))
        .accessibilityIdentifier("notch.plan.progress")
    }
}

/// A pill's endless motions, run by Core Animation for the same reason as
/// `NotchLayerMotion`: the island never lays itself out between frames.
struct NotchPillMotion: NSViewRepresentable {
    enum Motion {
        /// A short light crossing the pill every 1.6 s.
        case sweep
        /// An outline that swells and fades over 1.6 s, then rests 0.8 s.
        case ripple
    }

    let motion: Motion
    let color: Color
    let size: CGSize

    func makeNSView(context: Context) -> MotionView { MotionView(motion: motion) }

    func updateNSView(_ view: MotionView, context: Context) {
        view.update(color: NSColor(color).cgColor, size: size)
    }

    final class MotionView: NSView {
        private let motion: Motion
        private let shape = CAShapeLayer()
        private let light = CALayer()

        init(motion: Motion) {
            self.motion = motion
            super.init(frame: .zero)
            wantsLayer = true
            switch motion {
            case .sweep:
                // The light stays inside the pill.
                layer?.masksToBounds = true
                light.backgroundColor = NSColor.white.withAlphaComponent(0.6).cgColor
                layer?.addSublayer(light)
            case .ripple:
                layer?.masksToBounds = false
                shape.fillColor = nil
                shape.lineWidth = 1
                layer?.addSublayer(shape)
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        func update(color: CGColor, size: CGSize) {
            shape.strokeColor = color
            let bounds = CGRect(origin: .zero, size: size)
            guard shape.bounds != bounds || light.bounds.height != size.height else { return }
            layer?.cornerRadius = size.height / 2
            shape.bounds = bounds
            shape.path = CGPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
                                cornerWidth: size.height / 2 - 0.5, cornerHeight: size.height / 2 - 0.5,
                                transform: nil)
            light.bounds = CGRect(x: 0, y: 0, width: 4, height: size.height)
            light.cornerRadius = size.height / 2
            needsLayout = true
            restart()
        }

        override func layout() {
            super.layout()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shape.position = CGPoint(x: bounds.midX, y: bounds.midY)
            light.position = CGPoint(x: -light.bounds.width, y: bounds.midY)
            CATransaction.commit()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            restart()
        }

        private func restart() {
            shape.removeAllAnimations()
            light.removeAllAnimations()
            guard let window else { return }
            shape.contentsScale = window.backingScaleFactor
            switch motion {
            case .sweep:
                let width = max(bounds.width, NotchIslandMetrics.pillWidth)
                let cross = CABasicAnimation(keyPath: "position.x")
                cross.fromValue = -light.bounds.width
                cross.toValue = width + light.bounds.width
                cross.duration = 0.9
                cross.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                let sweep = CAAnimationGroup()
                sweep.animations = [cross]
                sweep.duration = 1.6
                sweep.repeatCount = .infinity
                light.add(sweep, forKey: "sweep")
            case .ripple:
                let swell = CABasicAnimation(keyPath: "transform.scale")
                swell.fromValue = 1
                swell.toValue = 1.8
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

/// One task's dot, where a peek names the task. It lights up once when
/// news about the task arrives.
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
