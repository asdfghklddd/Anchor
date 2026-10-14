#if os(iOS)
import AnchorDesign
import SwiftUI

/// The portrait invitation to the landscape work desk, told without text.
///
/// A band of harbor water sits at the bottom of the home screen with an anchor
/// hanging on its rope. The deck rolls gently, like standing on a boat; real
/// gravity from the motion sensor keeps the water level and swings the rope;
/// and a few times a slow current tugs the anchor toward the left edge, the
/// way to turn. After about twenty seconds the anchor sinks and the band
/// leaves quietly. `weighing` plays the reverse when work moves back to
/// portrait: the anchor rises out of the water and the band fades.
struct WorkInvitationHarbor: View {
    enum Mode: Equatable { case inviting, weighing }

    let mode: Mode
    let onEnd: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var gravity = DeviceGravityMonitor()
    @State private var pendulum = Pendulum()
    @State private var startedAt = Date.now
    @State private var didEnd = false

    static let height: CGFloat = 176
    private static let inviteDuration: TimeInterval = 20
    private static let sinkDuration: TimeInterval = 0.9
    private static let weighDuration: TimeInterval = 1.6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion && mode == .inviting)) { context in
            let elapsed = context.date.timeIntervalSince(startedAt)
            Canvas { canvas, size in
                draw(in: &canvas, size: size, elapsed: elapsed)
            } symbols: {
                HarborAnchorGlyph(color: AnchorIOSStyle.onAccent, lineWidth: 2.6)
                    .frame(width: 34, height: 34)
                    .tag("anchor")
            }
            .opacity(bandOpacity(elapsed))
            .onChange(of: elapsed >= endTime) { _, ended in if ended { finish() } }
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) { lockHint }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.workInvitation)
        .accessibilityIdentifier("work.invitation")
        .onAppear {
            startedAt = .now
            if !reduceMotion { gravity.start() }
            if reduceMotion { scheduleStaticEnd() }
        }
        .onDisappear { gravity.stop() }
    }

    private var endTime: TimeInterval {
        mode == .inviting ? Self.inviteDuration + Self.sinkDuration : Self.weighDuration
    }

    // MARK: Drawing

    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let roll = reduceMotion ? 0 : 0.038 * sin(2 * .pi * elapsed / 5.2)
        let tilt = (gravity.isAvailable ? gravity.angle : 0) + roll
        let waterTop = size.height * 0.58

        // A calm backdrop so the rope never crosses card text.
        let calm = AnchorIOSStyle.canvasBottom
        canvas.fill(Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height + 40))),
                    with: .linearGradient(Gradient(stops: [.init(color: calm.opacity(0), location: 0),
                                                           .init(color: calm.opacity(0.95), location: 0.22),
                                                           .init(color: calm.opacity(0.95), location: 1)]),
                                          startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        // Water stays level with the world: on screen it tilts against the phone.
        let surfaceAngle = -tilt
        var water = Path()
        let steps = 24
        for step in 0...steps {
            let x = size.width * Double(step) / Double(steps)
            let wave = reduceMotion ? 0 : 2.2 * sin(x / 38 + elapsed * 1.6)
            let y = waterTop + (x - size.width / 2) * tan(surfaceAngle) + wave
            step == 0 ? water.move(to: CGPoint(x: x, y: y)) : water.addLine(to: CGPoint(x: x, y: y))
        }
        var body = water
        body.addLine(to: CGPoint(x: size.width, y: size.height + 40))
        body.addLine(to: CGPoint(x: 0, y: size.height + 40))
        body.closeSubpath()
        canvas.fill(body, with: .color(AnchorIOSStyle.oceanSurface.opacity(0.55)))
        canvas.stroke(water, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
        canvas.fill(body.offsetBy(dx: 0, dy: 26), with: .color(AnchorIOSStyle.oceanDeep.opacity(0.22)))

        // The rope hangs from a mooring ring and follows gravity, the deck roll
        // and, a few times, the current toward the left edge.
        let pivot = CGPoint(x: size.width * 0.24, y: 34)
        let target = reduceMotion ? -0.26 : tilt + currentTug(elapsed)
        let angle = reduceMotion ? target : pendulum.step(toward: target, at: elapsed)
        var rope = 58.0
        var anchorOpacity = 1.0
        switch mode {
        case .inviting:
            let sink = max(0, elapsed - Self.inviteDuration) / Self.sinkDuration
            rope += 70 * eased(min(1, sink))
            anchorOpacity = 1 - min(1, sink)
        case .weighing:
            let rise = min(1, elapsed / 0.8)
            rope += 70 * (1 - eased(rise))
        }
        let end = CGPoint(x: pivot.x + rope * sin(angle), y: pivot.y + rope * cos(angle))

        var ropePath = Path()
        ropePath.move(to: pivot)
        ropePath.addLine(to: end)
        canvas.stroke(ropePath, with: .color(AnchorIOSStyle.secondaryText.opacity(0.75 * anchorOpacity)), lineWidth: 1.4)
        canvas.stroke(Path(ellipseIn: CGRect(x: pivot.x - 4, y: pivot.y - 4, width: 8, height: 8)),
                      with: .color(AnchorIOSStyle.secondaryText.opacity(0.8)), lineWidth: 1.6)

        if let glyph = canvas.resolveSymbol(id: "anchor") {
            var anchor = canvas
            anchor.opacity = anchorOpacity
            anchor.translateBy(x: end.x, y: end.y)
            anchor.rotate(by: .radians(-angle))
            anchor.draw(glyph, at: CGPoint(x: 0, y: 15), anchor: .center)
        }
    }

    /// Three slow pulls toward the left in the first fourteen seconds, then calm.
    private func currentTug(_ elapsed: TimeInterval) -> Double {
        guard mode == .inviting, elapsed > 1.2, elapsed < 15 else { return 0 }
        let phase = (elapsed - 1.2).truncatingRemainder(dividingBy: 4.6)
        guard phase < 1.6 else { return 0 }
        return -0.32 * sin(.pi * phase / 1.6)
    }

    private func bandOpacity(_ elapsed: TimeInterval) -> Double {
        let appear = min(1, elapsed / 0.5)
        switch mode {
        case .inviting:
            let leave = max(0, elapsed - Self.inviteDuration - Self.sinkDuration * 0.4) / (Self.sinkDuration * 0.6)
            return appear * (1 - min(1, leave))
        case .weighing:
            return appear * (1 - min(1, max(0, elapsed - 1.1) / 0.5))
        }
    }

    private func eased(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    // MARK: Text only where the gesture cannot work

    @ViewBuilder
    private var lockHint: some View {
        if mode == .inviting, gravity.suggestsOrientationLock {
            Label(L10n.workInvitationLock, systemImage: "lock.rotation")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AnchorIOSStyle.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AnchorIOSStyle.surface, in: .capsule)
                .padding(.top, -40)
                .transition(.opacity)
                .accessibilityIdentifier("work.invitation.lock")
        }
    }

    private func finish() {
        guard !didEnd else { return }
        didEnd = true
        gravity.stop()
        onEnd()
    }

    private func scheduleStaticEnd() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(endTime))
            finish()
        }
    }
}

/// A damped pendulum stepped once per frame. Reference state on purpose: it
/// integrates between frames and must not trigger view updates itself.
private final class Pendulum {
    private var angle = 0.0
    private var velocity = 0.0
    private var lastTime: TimeInterval?

    func step(toward target: Double, at time: TimeInterval) -> Double {
        let dt = min(1.0 / 20, max(0, time - (lastTime ?? time)))
        lastTime = time
        // Stiffness and damping give a rope that swings past once and settles.
        let acceleration = -26 * (angle - target) - 3.4 * velocity
        velocity += acceleration * dt
        angle += velocity * dt
        return angle
    }
}
#endif
