#if os(iOS)
import AnchorDesign
import SwiftUI

/// Small shallow crests, anchored to the sheet edge rather than the action dock.
/// Two layers drift slowly against each other; the water line stays level as
/// the phone tilts, sloshing once and settling, like water in a glass.
/// With reduced motion it holds still.
struct AnchorSetupWave: View {
    @AnchorReducedMotion private var reduceMotion
    @State private var gravity = DeviceGravityMonitor()
    @State private var slosh = WaveSlosh()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let tilt = reduceMotion ? 0 : slosh.step(toward: -gravity.angle, at: time)
                // The back layer is lighter and runs the other way.
                canvas.fill(
                    surface(in: size, tilt: tilt, phase: -time * 0.35, crest: 6 + slosh.energy * 0.6, lift: 7),
                    with: .color(AnchorSetupStyle.wave.opacity(0.35)))
                canvas.fill(
                    surface(in: size, tilt: tilt * 1.1, phase: time * 0.5, crest: 7 + slosh.energy, lift: 0),
                    with: .linearGradient(
                        Gradient(colors: [AnchorSetupStyle.wave, AnchorSetupStyle.bottom]),
                        startPoint: CGPoint(x: 0, y: Self.baseline), endPoint: CGPoint(x: 0, y: size.height)))
            }
        }
        .onAppear { if !reduceMotion { gravity.start() } }
        .onDisappear { gravity.stop() }
        .onChange(of: reduceMotion) { _, reduced in if reduced { gravity.stop() } else { gravity.start() } }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// Where the still water sits, from the top of the band.
    private static let baseline: CGFloat = 30
    /// How far the water may climb either edge when the phone leans.
    private static let maxRise: CGFloat = 16

    private func surface(in size: CGSize, tilt: Double, phase: Double, crest: CGFloat, lift: CGFloat) -> Path {
        let width = size.width
        let rise = CGFloat(max(-1, min(1, tilt / 0.45))) * Self.maxRise
        let crests = 3.0
        var path = Path()
        let steps = 48
        for index in 0...steps {
            let x = width * CGFloat(index) / CGFloat(steps)
            let along = Double(x / max(1, width))
            // The level line through the middle, and a long soft swell on it.
            let level = Self.baseline - lift - rise * CGFloat(along * 2 - 1)
            let swell = sin(along * .pi * 2 * crests + phase) * 0.7 + sin(along * .pi * 2 * crests * 1.9 - phase * 1.3) * 0.3
            let point = CGPoint(x: x, y: level + CGFloat(swell) * crest * 0.5)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.addLine(to: CGPoint(x: width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}

/// The water line's lean, as an under-damped spring chasing real gravity, so a
/// tilt overshoots a little and rocks back. Stepped once per frame from the
/// renderer; nothing observes it, so stepping never redraws by itself.
private final class WaveSlosh {
    private var lean: Double = 0
    private var speed: Double = 0
    private var last: TimeInterval?

    /// Grows with how fast the water is moving; the crests stand up with it.
    private(set) var energy: CGFloat = 0

    func step(toward target: Double, at time: TimeInterval) -> Double {
        let dt = min(1 / 20, max(0, time - (last ?? time)))
        last = time
        let goal = max(-0.6, min(0.6, target))
        // Stiffness 40 and damping 5 give one visible rock, then rest.
        let pull = 40 * (goal - lean) - 5 * speed
        speed += pull * dt
        lean += speed * dt
        energy = min(6, CGFloat(abs(speed)) * 7)
        return lean
    }
}
#endif
