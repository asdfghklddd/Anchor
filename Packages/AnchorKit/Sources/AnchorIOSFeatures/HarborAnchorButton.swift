#if os(iOS)
import AnchorDesign
import SwiftUI

/// The round anchor button at the bottom of the portrait home, which carries
/// three moments without words:
///
/// - **Anchor dropped** (`drops` changes after setup succeeds): a small anchor
///   falls into the button, the button dips and splashes, one success haptic.
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
    /// 0 is high above the button, 1 has landed in it.
    @State private var fall: CGFloat = 1
    @State private var falling = false
    @State private var splash: CGFloat = 1
    @State private var dip: CGFloat = 1
    @State private var contacts = 0

    private static let disc: CGFloat = 76

    var body: some View {
        Button(action: action) {
            ZStack {
                ripples
                Circle()
                    .fill(AnchorIOSStyle.cyan)
                    .frame(width: Self.disc, height: Self.disc)
                    .shadow(color: AnchorIOSStyle.heading.opacity(0.22 * (1 - grown)), radius: 14, y: 6)
                    // The disc sinks into the water as the anchor grows out of it.
                    .scaleEffect((1 - grown * 0.5) * dip)
                    .offset(y: grown * 20)
                    .opacity(1 - grown)
                anchor
                fallingAnchor
            }
            .frame(width: Self.disc, height: Self.disc)
            .contentShape(Circle().scale(1 + grown * 0.4))
        }
        .buttonStyle(AnchorPressButtonStyle())
        .sensoryFeedback(.success, trigger: contacts)
        .accessibilityLabel(L10n.establishAnchor)
        .accessibilityHint(isInviting ? L10n.workInvitation : "")
        .accessibilityIdentifier("anchor.note.button")
        .onChange(of: isInviting) { _, inviting in setGrown(inviting) }
        .onChange(of: drops) { _, _ in playDrop() }
        .onChange(of: weighs) { _, _ in playWeigh() }
        .onAppear { if isInviting { setGrown(true) } }
    }

    // MARK: The anchor

    private var anchor: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: grown == 0 || reduceMotion)) { context in
            let size = 36 + grown * 70
            let swing = grown > 0 ? angle(at: context.date.timeIntervalSince(invitedAt)) : 0
            VStack(spacing: 0) {
                // A short rope from above: the anchor hangs, it does not float.
                Capsule()
                    .fill(AnchorIOSStyle.secondaryText.opacity(0.7))
                    .frame(width: 1.6, height: 44 * grown)
                    .opacity(Double(grown))
                HarborAnchorGlyph(color: AnchorIOSStyle.onAccent, lineWidth: 3 + grown * 2.4)
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

    private var fallingAnchor: some View {
        HarborAnchorGlyph(color: AnchorIOSStyle.heading, lineWidth: 2.4)
            .frame(width: 28, height: 28)
            .offset(y: -260 * (1 - fall))
            .opacity(falling ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var ripples: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { ring in
                let progress = min(1, max(0, splash - CGFloat(ring) * 0.18) / 0.82)
                Circle()
                    .stroke(AnchorIOSStyle.cyan.opacity(0.75), lineWidth: 2.5)
                    .frame(width: Self.disc, height: Self.disc)
                    .scaleEffect(1 + progress * 1.3)
                    .opacity(splash < 1 ? Double(1 - progress) : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func playDrop() {
        Task { @MainActor in
            if !reduceMotion {
                withAnimation(nil) { fall = 0; falling = true }
                try? await Task.sleep(for: .milliseconds(30))
                // Gravity's ease-in: slow to leave, fast to land.
                withAnimation(.timingCurve(0.5, 0, 0.9, 0.55, duration: 0.42)) { fall = 1 }
                try? await Task.sleep(for: .milliseconds(420))
            }
            falling = false
            contacts += 1
            withAnimation(nil) { splash = 0 }
            withAnimation(.easeOut(duration: reduceMotion ? 0.4 : 0.75)) { splash = 1 }
            guard !reduceMotion else { return }
            withAnimation(.spring(duration: 0.18)) { dip = 0.86 }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.spring(duration: 0.45, bounce: 0.5)) { dip = 1 }
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
