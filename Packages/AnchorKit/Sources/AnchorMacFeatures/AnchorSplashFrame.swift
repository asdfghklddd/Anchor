#if os(macOS)
import SwiftUI

/// A bounded, deterministic burst: a thin water sheet breaks into ballistic droplets.
struct AnchorSplashFrame: View {
    let elapsed: TimeInterval
    let intensity: CGFloat

    private let water = Color(red: 0.38, green: 0.70, blue: 0.88)
    private let highlight = Color(red: 0.84, green: 0.96, blue: 1)

    var body: some View {
        Canvas { context, size in
            guard elapsed >= 0, elapsed < 0.68 else { return }
            let origin = CGPoint(x: size.width / 2, y: size.height - 4)
            let strength = min(1, max(0, intensity))
            guard strength > 0 else { return }
            drawRipples(in: context, origin: origin, strength: strength)
            drawCrown(in: context, origin: origin, strength: strength)
            drawDroplets(in: context, origin: origin, strength: strength)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func drawCrown(in context: GraphicsContext, origin: CGPoint, strength: CGFloat) {
        let t = elapsed / 0.26
        guard t < 1 else { return }
        let lift = sin(.pi * pow(t, 0.7)) * 18 * strength
        let spread = (5 + 22 * t) * strength
        let opacity = pow(1 - t, 0.8)
        // Unequal lobes make a continuous water sheet, not a radial starburst.
        let peaks: [CGFloat] = [0.44, 0.86, 0.61, 1, 0.56, 0.78, 0.38]
        var sheet = Path()
        sheet.move(to: CGPoint(x: origin.x - spread, y: origin.y))
        for index in peaks.indices {
            let x = origin.x + spread * (-1 + 2 * CGFloat(index) / 6)
            let crest = CGPoint(x: x, y: origin.y - lift * peaks[index])
            sheet.addQuadCurve(to: crest, control: CGPoint(x: x - spread / 9, y: origin.y - lift * 0.16))
        }
        sheet.addQuadCurve(to: CGPoint(x: origin.x + spread, y: origin.y),
                           control: CGPoint(x: origin.x + spread, y: origin.y - lift * 0.2))
        var fill = sheet
        fill.closeSubpath()
        context.fill(fill, with: .linearGradient(
            Gradient(colors: [highlight.opacity(0.30 * opacity), water.opacity(0.04 * opacity)]),
            startPoint: CGPoint(x: origin.x, y: origin.y - lift), endPoint: origin
        ))
        context.stroke(sheet, with: .color(highlight.opacity(0.72 * opacity)),
                       style: StrokeStyle(lineWidth: 0.65, lineCap: .round, lineJoin: .round))
    }

    private func drawDroplets(in context: GraphicsContext, origin: CGPoint, strength: CGFloat) {
        for index in 0..<28 {
            let a = variation(index, salt: 1)
            let b = variation(index, salt: 7)
            let delay = variation(index, salt: 13) * 0.055
            let age = elapsed - delay
            guard age > 0 else { continue }
            let vx = (a * 2 - 1) * 92 * strength
            let launchSpeed = (74 + b * 100) * strength
            let gravity = 680.0
            let lift = launchSpeed * age - 0.5 * gravity * age * age
            guard lift > 0 else { continue }
            let x = origin.x + vx * age + (a - 0.5) * 7
            let y = origin.y - lift
            let vy = -launchSpeed + gravity * age
            let radius = (0.55 + variation(index, salt: 23) * 0.85) * (0.7 + 0.3 * strength)
            let stretch = 1 + min(1.5, hypot(vx, vy) / 125)
            let landingFade = min(1, lift / 5)
            let opacity = min(1, age / 0.025) * landingFade * (0.55 + b * 0.35)
            var drop = context
            drop.translateBy(x: x, y: y)
            drop.rotate(by: .radians(atan2(vy, vx) - .pi / 2))
            let shape = Path(ellipseIn: CGRect(x: -radius, y: -radius * stretch,
                                              width: radius * 2, height: radius * 2 * stretch))
            drop.fill(shape, with: .linearGradient(
                Gradient(colors: [highlight.opacity(opacity), water.opacity(opacity * 0.55)]),
                startPoint: CGPoint(x: -radius, y: -radius), endPoint: CGPoint(x: radius, y: radius)
            ))
        }
    }

    private func drawRipples(in context: GraphicsContext, origin: CGPoint, strength: CGFloat) {
        for ring in 0..<3 {
            let age = elapsed - Double(ring) * 0.09
            guard age > 0 else { continue }
            let t = min(1, age / (0.68 - Double(ring) * 0.09))
            let radius = (5 + 43 * (1 - pow(1 - t, 2))) * strength
            let opacity = min(1, age / 0.035) * pow(1 - t, 1.7)
            // Broken, shallow arcs keep the surface light and avoid concentric target rings.
            for segment in 0..<3 {
                var arc = Path()
                for step in 0...24 {
                    let angle = Double(segment) * 2.1 + Double(step) / 24 * 1.65 + Double(ring) * 0.37
                    let point = CGPoint(x: origin.x + cos(angle) * radius,
                                        y: origin.y - 1 + sin(angle) * radius * 0.11)
                    if step == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
                }
                context.stroke(arc, with: .color(water.opacity(opacity * 0.65)),
                               style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                context.stroke(arc.offsetBy(dx: 0, dy: -0.45),
                               with: .color(highlight.opacity(opacity * 0.38)),
                               style: StrokeStyle(lineWidth: 0.4, lineCap: .round))
            }
        }
    }

    private func variation(_ index: Int, salt: Int) -> Double {
        // Stable samples prevent particle positions from flickering between Canvas redraws.
        let value = sin(Double(index * 127 + salt * 311)) * 43_758.5453
        return value - floor(value)
    }
}
#endif
