#if os(macOS)
import SwiftUI

/// A slim blue metal anchor with a restrained bevel along its lit edge.
struct AnchorEdgeAnchorGlyph: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            var path = Path()
            path.addEllipse(in: CGRect(x: w / 2 - 3, y: 1, width: 6, height: 6))
            path.move(to: CGPoint(x: w / 2, y: 7))
            path.addLine(to: CGPoint(x: w / 2, y: h - 4))
            path.move(to: CGPoint(x: w * 0.32, y: 13))
            path.addLine(to: CGPoint(x: w * 0.68, y: 13))
            path.move(to: CGPoint(x: 3, y: h * 0.62))
            path.addCurve(to: CGPoint(x: w - 3, y: h * 0.62), control1: CGPoint(x: 4, y: h + 1), control2: CGPoint(x: w - 4, y: h + 1))
            path.move(to: CGPoint(x: 2, y: h * 0.75))
            path.addLine(to: CGPoint(x: 3, y: h * 0.62))
            path.addLine(to: CGPoint(x: 7, y: h * 0.67))
            path.move(to: CGPoint(x: w - 2, y: h * 0.75))
            path.addLine(to: CGPoint(x: w - 3, y: h * 0.62))
            path.addLine(to: CGPoint(x: w - 7, y: h * 0.67))
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [Color(red: 0.63, green: 0.83, blue: 0.98),
                                  Color(red: 0.24, green: 0.49, blue: 0.72)]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: h)
            ), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            context.stroke(path.offsetBy(dx: -0.3, dy: -0.2),
                           with: .color(Color.white.opacity(0.28)),
                           style: StrokeStyle(lineWidth: 0.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}
#endif
