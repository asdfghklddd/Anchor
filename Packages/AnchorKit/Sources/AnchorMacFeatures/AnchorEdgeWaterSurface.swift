#if os(macOS)
import SwiftUI

/// Quiet surface traces remain after the transient splash has dissipated.
struct AnchorEdgeWaterSurface: View {
    var body: some View {
        Canvas { context, size in
            for ring in 0..<2 {
                let radius = CGFloat(20 + ring * 10)
                for side in [CGFloat(-1), CGFloat(1)] {
                    var arc = Path()
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    arc.move(to: CGPoint(x: center.x + side * radius * 0.25, y: center.y - 2))
                    arc.addQuadCurve(
                        to: CGPoint(x: center.x + side * radius, y: center.y),
                        control: CGPoint(x: center.x + side * radius * 0.85, y: center.y - 3.5)
                    )
                    context.stroke(arc,
                                   with: .color(Color(red: 0.48, green: 0.72, blue: 0.88)
                                    .opacity(ring == 0 ? 0.38 : 0.18)),
                                   style: StrokeStyle(lineWidth: 0.65, lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
#endif
