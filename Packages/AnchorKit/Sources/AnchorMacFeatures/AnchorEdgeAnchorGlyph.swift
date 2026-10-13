#if os(macOS)
import SwiftUI

/// A small anchor in the icon's azure gradient, sized to the boat, with a lit edge.
struct AnchorEdgeAnchorGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let ring = w * 0.17
            var path = Path()
            path.addEllipse(in: CGRect(x: w / 2 - ring, y: 1, width: ring * 2, height: ring * 2))
            path.move(to: CGPoint(x: w / 2, y: 1 + ring * 2))
            path.addLine(to: CGPoint(x: w / 2, y: h - 2))
            path.move(to: CGPoint(x: w * 0.26, y: h * 0.36))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.36))
            path.move(to: CGPoint(x: w * 0.10, y: h * 0.60))
            path.addQuadCurve(to: CGPoint(x: w * 0.90, y: h * 0.60), control: CGPoint(x: w / 2, y: h * 1.16))
            // Flukes turn up at each arm.
            path.move(to: CGPoint(x: w * 0.03, y: h * 0.70))
            path.addLine(to: CGPoint(x: w * 0.10, y: h * 0.60))
            path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.64))
            path.move(to: CGPoint(x: w * 0.97, y: h * 0.70))
            path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.60))
            path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.64))
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [Color(red: 0.27, green: 0.82, blue: 0.97),
                                  Color(red: 0.06, green: 0.40, blue: 0.84)]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: h)
            ), style: StrokeStyle(lineWidth: max(1.6, w * 0.11), lineCap: .round, lineJoin: .round))
            context.stroke(path.offsetBy(dx: -0.35, dy: -0.35),
                           with: .color(Color.white.opacity(0.35)),
                           style: StrokeStyle(lineWidth: 0.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
#endif
