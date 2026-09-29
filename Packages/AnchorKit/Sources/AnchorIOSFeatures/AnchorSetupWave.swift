#if os(iOS)
import SwiftUI

/// Small shallow crests, anchored to the sheet edge rather than the action dock.
struct AnchorSetupWave: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                path.move(to: CGPoint(x: 0, y: 5))
                for index in 0..<18 {
                    let x = width * CGFloat(index) / 18
                    let end = width * CGFloat(index + 1) / 18
                    let amplitude: CGFloat = index.isMultiple(of: 3) ? 9 : 7
                    path.addQuadCurve(to: CGPoint(x: end, y: 5),
                        control: CGPoint(x: (x + end) / 2, y: 5 + (index.isMultiple(of: 2) ? amplitude : -amplitude)))
                }
                path.addLine(to: CGPoint(x: width, y: geometry.size.height))
                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [AnchorSetupStyle.wave, AnchorSetupStyle.bottom], startPoint: .top, endPoint: .bottom))
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
#endif
