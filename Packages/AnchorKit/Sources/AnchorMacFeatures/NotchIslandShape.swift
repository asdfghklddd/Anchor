#if os(macOS)
import SwiftUI

/// The island: flat along the top edge of the screen, flaring out where it
/// meets the bezel so it reads as grown from the housing, with soft corners
/// at the bottom. Both radii animate as the island opens.
struct NotchIslandShape: Shape {
    var flare: CGFloat
    var radius: CGFloat
    /// Leaves out the top edge, for the hairline that must not cross the bezel.
    var isOutline = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(flare, radius) }
        set {
            flare = newValue.first
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let f = min(flare, w / 4, h / 2)
        let r = min(radius, (w - f * 2) / 2, h - f)
        // How far a cubic's handles reach to trace a quarter circle.
        let k: CGFloat = 0.5523
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + f, y: rect.minY + f),
                          control: CGPoint(x: rect.minX + f, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + f, y: rect.minY + h - r))
        path.addCurve(to: CGPoint(x: rect.minX + f + r, y: rect.minY + h),
                      control1: CGPoint(x: rect.minX + f, y: rect.minY + h - r + r * k),
                      control2: CGPoint(x: rect.minX + f + r - r * k, y: rect.minY + h))
        path.addLine(to: CGPoint(x: rect.minX + w - f - r, y: rect.minY + h))
        path.addCurve(to: CGPoint(x: rect.minX + w - f, y: rect.minY + h - r),
                      control1: CGPoint(x: rect.minX + w - f - r + r * k, y: rect.minY + h),
                      control2: CGPoint(x: rect.minX + w - f, y: rect.minY + h - r + r * k))
        path.addLine(to: CGPoint(x: rect.minX + w - f, y: rect.minY + f))
        path.addQuadCurve(to: CGPoint(x: rect.minX + w, y: rect.minY),
                          control: CGPoint(x: rect.minX + w - f, y: rect.minY))
        if !isOutline { path.closeSubpath() }
        return path
    }
}
#endif
