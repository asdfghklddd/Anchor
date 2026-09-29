#if os(macOS)
import SwiftUI

/// Interpolates rope endpoints with the vertical animation, while its bend lags the weight.
struct AnchorEdgeRopeShape: Shape {
    var start: CGPoint
    var end: CGPoint
    var bend: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(end.y, AnimatablePair(end.x, bend)) }
        set {
            end.y = newValue.first
            end.x = newValue.second.first
            bend = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let length = max(0, end.y - start.y)
        var path = Path()
        path.move(to: start)
        path.addCurve(
            to: end,
            control1: CGPoint(x: start.x + bend, y: start.y + length * 0.34),
            control2: CGPoint(x: end.x - bend * 0.6, y: start.y + length * 0.76)
        )
        return path
    }
}
#endif
