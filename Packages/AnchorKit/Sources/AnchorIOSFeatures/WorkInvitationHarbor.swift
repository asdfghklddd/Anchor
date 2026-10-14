#if os(iOS)
import AnchorDesign
import SwiftUI

/// The harbor water behind the anchor button during the landscape invitation.
///
/// The anchor itself is the bottom button (`HarborAnchorButton`), which grows
/// into a rocking anchor. This band is only its sea: the deck rolls gently,
/// like standing on a boat, and real gravity keeps the water level. After
/// about twenty seconds it leaves quietly. `weighing` shows the water briefly
/// while the anchor rises back into the button.
struct WorkInvitationHarbor: View {
    enum Mode: Equatable { case inviting, weighing }

    let mode: Mode
    let gravity: DeviceGravityMonitor
    let onEnd: () -> Void

    @AnchorReducedMotion private var reduceMotion
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
            if reduceMotion { scheduleStaticEnd() }
        }
    }

    private var endTime: TimeInterval {
        mode == .inviting ? Self.inviteDuration + Self.sinkDuration : Self.weighDuration
    }

    // MARK: Drawing

    private func draw(in canvas: inout GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let roll = reduceMotion ? 0 : 0.038 * sin(2 * .pi * elapsed / 5.2)
        let tilt = (gravity.isAvailable ? gravity.angle : 0) + roll
        let waterTop = size.height * 0.58

        // A calm backdrop so the grown anchor reads against water, not card text.
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
    }

    private func bandOpacity(_ elapsed: TimeInterval) -> Double {
        let appear = min(1, elapsed / 0.5)
        switch mode {
        case .inviting:
            let leave = max(0, elapsed - Self.inviteDuration - Self.sinkDuration * 0.4) / (Self.sinkDuration * 0.6)
            return appear * (1 - min(1, leave))
        case .weighing:
            return appear * (1 - min(1, max(0, elapsed - 1.0) / 0.6))
        }
    }


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
        onEnd()
    }

    private func scheduleStaticEnd() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(endTime))
            finish()
        }
    }
}

#endif
