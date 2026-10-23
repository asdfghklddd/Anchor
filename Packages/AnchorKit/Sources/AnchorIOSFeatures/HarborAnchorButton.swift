#if os(iOS)
import AnchorDesign
import SwiftUI

/// One drop's timing, shared by the button, its haptics and the new task's card.
enum AnchorDrop {
    /// The setup sheet is out of the way before the anchor falls past it.
    static let lead: Duration = .milliseconds(350)
    /// The anchor meets the water.
    static let contact: TimeInterval = 0.42
    /// It catches and holds; the new task's card settles at the same moment.
    static let hold = contact + AnchorDropHaptics.catchDelay
    /// Gravity's ease-in: slow to leave, fast to land.
    static let gravity = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.5, y: 0), endControlPoint: UnitPoint(x: 0.9, y: 0.55))
}

/// The round anchor button at the bottom of the portrait home, which carries
/// three moments without words:
///
/// - **Anchor dropped** (`drops` changes after setup succeeds): the anchor falls
///   into the button, meets the water with a splash and a thud, bobs, and
///   catches with a lighter tap, becoming the button's own anchor.
/// - **Invitation** (`isInviting`): the cyan disc sinks into the harbor water
///   and the anchor grows out of it, hanging and rocking like a boat at
///   anchor. A slow current leans it toward the left edge, the way to turn,
///   and on a real phone it follows gravity.
/// - **Weighing** (`weighs` changes): back from landscape, the anchor rises
///   out of the water and settles into the button again.
///
/// The button keeps its action and identity throughout: tapping always opens
/// a new anchor.
struct HarborAnchorButton: View {
    let isInviting: Bool
    let drops: Int
    let weighs: Int
    let gravity: DeviceGravityMonitor
    let action: () -> Void

    @AnchorReducedMotion private var reduceMotion
    /// 0 is the round button, 1 the grown, hanging anchor.
    @State private var grown: CGFloat = 0
    @State private var invitedAt = Date.now
    @State private var pendulum = Pendulum()
    @State private var haptics = AnchorDropHaptics()

    private static let disc: CGFloat = 76
    private static let mark: CGFloat = 36

    var body: some View {
        Button(action: action) {
            KeyframeAnimator(initialValue: DropMotion(), trigger: drops) { motion in
                ZStack {
                    ripples(motion.splash)
                    if !reduceMotion { spray(motion.splash) }
                    Circle()
                        .fill(AnchorIOSStyle.cyan)
                        .frame(width: Self.disc, height: Self.disc)
                        .shadow(color: AnchorIOSStyle.heading.opacity(0.22 * (1 - grown)), radius: 14, y: 6)
                        // The disc sinks into the water as the anchor grows out of it.
                        .scaleEffect((1 - grown * 0.5) * motion.dip)
                        .offset(y: grown * 20)
                        .opacity(1 - grown)
                    anchor.opacity(motion.resting)
                    falling(motion)
                }
                .frame(width: Self.disc, height: Self.disc)
            } keyframes: { _ in
                dropKeyframes
            }
            .contentShape(Circle().scale(1 + grown * 0.4))
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityLabel(L10n.establishAnchor)
        .accessibilityHint(isInviting ? L10n.workInvitation : "")
        .accessibilityIdentifier("anchor.note.button")
        .onChange(of: isInviting) { _, inviting in setGrown(inviting) }
        .onChange(of: drops) { _, _ in
            if reduceMotion { haptics.playCatch() } else { haptics.playDrop(after: AnchorDrop.contact) }
        }
        .onChange(of: weighs) { _, _ in playWeigh() }
        .onAppear { if isInviting { setGrown(true) } }
    }

    // MARK: The anchor

    private var anchor: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: grown == 0 || reduceMotion)) { context in
            let size = Self.mark + grown * 70
            let swing = grown > 0 ? angle(at: context.date.timeIntervalSince(invitedAt)) : 0
            VStack(spacing: 0) {
                // A short rope from above: the anchor hangs, it does not float.
                Capsule()
                    .fill(AnchorIOSStyle.secondaryText.opacity(0.7))
                    .frame(width: 1.6, height: 44 * grown)
                    .opacity(Double(grown))
                AnchorFigure(color: AnchorIOSStyle.onAccent, depth: true)
                    .frame(width: size, height: size)
            }
            // Angles follow screen gravity (negative = toward the left edge); a
            // hanging anchor's bottom swings left under a clockwise rotation.
            .rotationEffect(.radians(-swing), anchor: .top)
            .offset(y: -grown * 62)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Boat roll, three slow currents to the left, and real gravity on device.
    private func angle(at elapsed: TimeInterval) -> Double {
        if reduceMotion { return -0.28 }
        let roll = 0.10 * sin(2 * .pi * elapsed / 5.2)
        var current = 0.0
        if elapsed > 1.2, elapsed < 15 {
            let phase = (elapsed - 1.2).truncatingRemainder(dividingBy: 4.6)
            if phase < 1.6 { current = -0.42 * sin(.pi * phase / 1.6) }
        }
        let tilt = gravity.isAvailable ? gravity.angle : 0
        return pendulum.step(toward: roll + current + tilt, at: elapsed)
    }

    private func setGrown(_ inviting: Bool) {
        if inviting { invitedAt = .now; pendulum = Pendulum() }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.7, bounce: 0.28)) {
            grown = inviting ? 1 : 0
        }
    }

    // MARK: Anchor dropped

    /// The dropped anchor: the same figure, size and color as the button's own,
    /// so when it settles it simply becomes it.
    private func falling(_ motion: DropMotion) -> some View {
        AnchorFigure(color: AnchorIOSStyle.onAccent, depth: true)
            .frame(width: Self.mark, height: Self.mark)
            .shadow(color: AnchorIOSStyle.heading.opacity(motion.shadow), radius: 4, y: 3)
            .scaleEffect(x: motion.scale, y: motion.scale * motion.stretch, anchor: .bottom)
            .rotationEffect(.degrees(motion.tilt))
            .offset(y: motion.y)
            .opacity(motion.falling)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Two rings spread from where the anchor went in.
    private func ripples(_ splash: CGFloat) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { ring in
                let progress = min(1, max(0, splash - CGFloat(ring) * 0.18) / 0.82)
                Circle()
                    .stroke(AnchorIOSStyle.cyan.opacity(0.75), lineWidth: 2.5)
                    .frame(width: Self.disc, height: Self.disc)
                    .scaleEffect(1 + progress * 1.3)
                    .opacity(splash > 0 && splash < 1 ? Double(1 - progress) : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A few drops thrown up by the impact, each on its own arc.
    private func spray(_ splash: CGFloat) -> some View {
        ZStack {
            ForEach(Self.droplets.indices, id: \.self) { index in
                let droplet = Self.droplets[index]
                // The spray is over in the first part of the splash.
                let t = min(1, splash / 0.62)
                Circle()
                    .fill(AnchorIOSStyle.cyan)
                    .frame(width: droplet.size, height: droplet.size)
                    .offset(x: droplet.dx * t, y: -30 - droplet.rise * 4 * t * (1 - t) + 10 * t * t)
                    .opacity(splash > 0 && t < 1 ? Double(min(1, t / 0.12) * (1 - t * t)) : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static let droplets: [(dx: CGFloat, rise: CGFloat, size: CGFloat)] = [
        (-30, 26, 4.5), (-14, 42, 6), (3, 50, 5), (17, 38, 5.5), (31, 24, 4),
    ]

    /// Fall, splash and bob, then the catch: the anchor settles into place with
    /// a small tug of the disc. Under reduced motion only the ripples fade out.
    @KeyframesBuilder<DropMotion> private var dropKeyframes: some Keyframes<DropMotion> {
        let moving = !reduceMotion
        let contact = moving ? AnchorDrop.contact : 0.01
        let hold = contact + AnchorDropHaptics.catchDelay
        let settle = 0.42
        KeyframeTrack(\.y) {
            MoveKeyframe(moving ? -300 : 0)
            LinearKeyframe(0, duration: contact, timingCurve: AnchorDrop.gravity)
            LinearKeyframe(moving ? 9 : 0, duration: 0.18, timingCurve: .easeOut)
            LinearKeyframe(moving ? 9 : 0, duration: hold - contact - 0.18)
            SpringKeyframe(0, duration: settle, spring: .bouncy)
        }
        KeyframeTrack(\.scale) {
            MoveKeyframe(moving ? 0.86 : 1)
            LinearKeyframe(1, duration: contact)
        }
        KeyframeTrack(\.stretch) {
            MoveKeyframe(1)
            LinearKeyframe(moving ? 1.08 : 1, duration: contact, timingCurve: .easeIn)
            LinearKeyframe(moving ? 0.9 : 1, duration: 0.06)
            SpringKeyframe(1, duration: 0.3, spring: .bouncy)
        }
        KeyframeTrack(\.tilt) {
            MoveKeyframe(moving ? -12 : 0)
            LinearKeyframe(0, duration: contact, timingCurve: .easeOut)
            LinearKeyframe(moving ? 6 : 0, duration: 0.14)
            LinearKeyframe(moving ? -3 : 0, duration: 0.18)
            SpringKeyframe(0, duration: 0.4, spring: .smooth)
        }
        KeyframeTrack(\.shadow) {
            MoveKeyframe(moving ? 0.22 : 0)
            LinearKeyframe(moving ? 0.22 : 0, duration: contact)
            LinearKeyframe(0, duration: 0.1)
        }
        // The button's own anchor steps aside for the one that falls, and is
        // back, unseen, the moment the two are in the same place.
        KeyframeTrack(\.falling) {
            MoveKeyframe(0)
            LinearKeyframe(moving ? 1 : 0, duration: 0.08)
            LinearKeyframe(moving ? 1 : 0, duration: hold + settle - 0.08)
            MoveKeyframe(0)
        }
        KeyframeTrack(\.resting) {
            LinearKeyframe(moving ? 0 : 1, duration: 0.15)
            LinearKeyframe(moving ? 0 : 1, duration: hold + settle - 0.15)
            MoveKeyframe(1)
        }
        KeyframeTrack(\.splash) {
            MoveKeyframe(0)
            LinearKeyframe(0, duration: contact)
            LinearKeyframe(1, duration: moving ? 0.8 : 0.4, timingCurve: .easeOut)
            MoveKeyframe(0)
        }
        KeyframeTrack(\.dip) {
            MoveKeyframe(1)
            LinearKeyframe(1, duration: contact)
            LinearKeyframe(moving ? 0.86 : 1, duration: 0.09, timingCurve: .easeOut)
            SpringKeyframe(1, duration: 0.36, spring: .bouncy)
            LinearKeyframe(1, duration: max(0.01, hold - contact - 0.45))
            LinearKeyframe(moving ? 0.96 : 1, duration: 0.06)
            SpringKeyframe(1, duration: 0.3, spring: .bouncy)
        }
    }

    // MARK: Weighing

    private func playWeigh() {
        guard !reduceMotion else { return }
        invitedAt = .now
        pendulum = Pendulum()
        withAnimation(nil) { grown = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) { grown = 0 }
        }
    }
}

/// Everything that moves during one drop, read once per frame.
struct DropMotion {
    var y: CGFloat = 0
    var scale: CGFloat = 1
    var stretch: CGFloat = 1
    var tilt: Double = 0
    var shadow: Double = 0
    /// The falling anchor; the button's own anchor is `resting`.
    var falling: Double = 0
    var resting: Double = 1
    /// 0 before the anchor meets the water, 1 once the water is still.
    var splash: CGFloat = 0
    var dip: CGFloat = 1
}

/// A damped pendulum stepped once per frame. Reference state on purpose: it
/// integrates between frames and must not trigger view updates itself.
final class Pendulum {
    private var angle = 0.0
    private var velocity = 0.0
    private var lastTime: TimeInterval?

    func step(toward target: Double, at time: TimeInterval) -> Double {
        let dt = min(1.0 / 20, max(0, time - (lastTime ?? time)))
        lastTime = time
        // Stiffness and damping give an anchor that swings past once and settles.
        let acceleration = -26 * (angle - target) - 3.4 * velocity
        velocity += acceleration * dt
        angle += velocity * dt
        return angle
    }
}
#endif
