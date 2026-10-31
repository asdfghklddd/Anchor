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

/// The round anchor button at the bottom of the portrait home. When an anchor
/// is dropped (`drops` changes after setup succeeds), the anchor falls into the
/// button, meets the water with a splash and a thud, bobs, and catches with a
/// lighter tap, becoming the button's own anchor. Tapping always opens a new
/// anchor.
struct HarborAnchorButton: View {
    let drops: Int
    let action: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var haptics = AnchorDropHaptics()

    private static let disc: CGFloat = 75
    private static let mark: CGFloat = 36

    var body: some View {
        Button(action: action) {
            KeyframeAnimator(initialValue: DropMotion(), trigger: drops) { motion in
                ZStack {
                    ripples(motion.splash)
                    if !reduceMotion { spray(motion.splash) }
                    Circle()
                        .fill(HomeStyle.anchor)
                        .frame(width: Self.disc, height: Self.disc)
                        .shadow(color: AnchorIOSStyle.heading.opacity(0.22), radius: 14, y: 6)
                        .scaleEffect(motion.dip)
                    anchor.opacity(motion.resting)
                    falling(motion)
                }
                .frame(width: Self.disc, height: Self.disc)
            } keyframes: { _ in
                dropKeyframes
            }
            .contentShape(Circle())
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityLabel(L10n.establishAnchor)
        .accessibilityIdentifier("anchor.note.button")
        .onChange(of: drops) { _, _ in
            if reduceMotion { haptics.playCatch() } else { haptics.playDrop(after: AnchorDrop.contact) }
        }
    }

    private var anchor: some View {
        AnchorFigure(color: AnchorIOSStyle.onAccent, depth: true)
            .frame(width: Self.mark, height: Self.mark)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
                    .stroke(HomeStyle.anchor.opacity(0.75), lineWidth: 2.5)
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
                    .fill(HomeStyle.anchor)
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

#endif
