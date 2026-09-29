import SwiftUI

/// Freestanding blue sails and a small wake, with no app-icon container.
public struct HarborBoatGlyph: View {
    public var wind: CGFloat

    public init(wind: CGFloat = 0) {
        self.wind = wind
    }

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let billow = min(1, max(-1, wind)) * w * 0.018
            let blue = Color(red: 0.27, green: 0.48, blue: 0.79)
            let pale = Color(red: 0.57, green: 0.76, blue: 0.97)
            var sail = Path()
            sail.move(to: CGPoint(x: w * 0.49, y: h * 0.20))
            sail.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.67), control: CGPoint(x: w * 0.25 + billow, y: h * 0.41))
            sail.addLine(to: CGPoint(x: w * 0.46, y: h * 0.65))
            sail.closeSubpath()
            context.fill(sail, with: .linearGradient(Gradient(colors: [pale, blue]), startPoint: .zero, endPoint: CGPoint(x: w * 0.5, y: h)))
            var forward = Path()
            forward.move(to: CGPoint(x: w * 0.55, y: h * 0.23))
            forward.addQuadCurve(to: CGPoint(x: w * 0.80, y: h * 0.65), control: CGPoint(x: w * 0.87 + billow, y: h * 0.43))
            forward.addLine(to: CGPoint(x: w * 0.53, y: h * 0.65))
            forward.closeSubpath()
            context.fill(forward, with: .linearGradient(Gradient(colors: [blue, pale]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            // Fine sail seams follow the cloth curvature without adding visual weight.
            var seam = Path()
            seam.move(to: CGPoint(x: w * 0.46, y: h * 0.30))
            seam.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.62),
                              control: CGPoint(x: w * 0.31 + billow, y: h * 0.47))
            seam.move(to: CGPoint(x: w * 0.58, y: h * 0.33))
            seam.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.61),
                              control: CGPoint(x: w * 0.76 + billow, y: h * 0.47))
            context.stroke(seam, with: .color(.white.opacity(0.30)),
                           style: StrokeStyle(lineWidth: 0.55, lineCap: .round))
            var mast = Path()
            mast.move(to: CGPoint(x: w * 0.51, y: h * 0.10))
            mast.addLine(to: CGPoint(x: w * 0.49, y: h * 0.74))
            context.stroke(mast, with: .color(pale), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            var flag = Path()
            flag.move(to: CGPoint(x: w * 0.54, y: h * 0.10))
            flag.addLine(to: CGPoint(x: w * 0.73, y: h * 0.15 + billow))
            flag.addLine(to: CGPoint(x: w * 0.54, y: h * 0.19))
            flag.closeSubpath()
            context.fill(flag, with: .color(Color(red: 0.88, green: 0.43, blue: 0.48)))
            var hull = Path()
            hull.move(to: CGPoint(x: w * 0.20, y: h * 0.73))
            hull.addLine(to: CGPoint(x: w * 0.81, y: h * 0.70))
            hull.addQuadCurve(to: CGPoint(x: w * 0.69, y: h * 0.87), control: CGPoint(x: w * 0.79, y: h * 0.83))
            hull.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.87), control: CGPoint(x: w * 0.49, y: h * 0.94))
            hull.closeSubpath()
            context.fill(hull, with: .linearGradient(
                Gradient(colors: [pale, blue.opacity(0.95)]),
                startPoint: CGPoint(x: 0, y: h * 0.72),
                endPoint: CGPoint(x: 0, y: h * 0.94)
            ))
            var gunwale = Path()
            gunwale.move(to: CGPoint(x: w * 0.22, y: h * 0.735))
            gunwale.addLine(to: CGPoint(x: w * 0.79, y: h * 0.707))
            context.stroke(gunwale, with: .color(.white.opacity(0.62)),
                           style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            // Tapered, offset wakes keep the small silhouette readable at native scale.
            for row in 0..<3 {
                let y = h * (0.91 + Double(row) * 0.033)
                var wake = Path()
                wake.move(to: CGPoint(x: w * (0.12 + Double(row) * 0.06), y: y))
                wake.addQuadCurve(
                    to: CGPoint(x: w * (0.80 - Double(row) * 0.09), y: y - 0.4),
                    control: CGPoint(x: w * 0.44, y: y + 1.8)
                )
                context.stroke(wake, with: .linearGradient(
                    Gradient(colors: [pale.opacity(0), pale.opacity(0.50 - Double(row) * 0.13), pale.opacity(0)]),
                    startPoint: CGPoint(x: w * 0.1, y: y), endPoint: CGPoint(x: w * 0.82, y: y)
                ), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
