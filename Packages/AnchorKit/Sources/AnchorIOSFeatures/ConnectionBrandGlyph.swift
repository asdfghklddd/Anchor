#if os(iOS)
import SwiftUI

/// Vector rendition of Anchor's existing A-and-anchor mark.
struct ConnectionBrandGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 43, y: 2)); p.addLine(to: CGPoint(x: 55, y: 2))
        p.addLine(to: CGPoint(x: 80, y: 68))
        p.addCurve(to: CGPoint(x: 70, y: 73), control1: CGPoint(x: 76, y: 73), control2: CGPoint(x: 71, y: 78))
        p.addLine(to: CGPoint(x: 62, y: 51)); p.addLine(to: CGPoint(x: 36, y: 51))
        p.addLine(to: CGPoint(x: 28, y: 73)); p.addLine(to: CGPoint(x: 17, y: 72)); p.closeSubpath()
        p.move(to: CGPoint(x: 49, y: 17)); p.addLine(to: CGPoint(x: 39, y: 44))
        p.addLine(to: CGPoint(x: 59, y: 44)); p.closeSubpath()
        p.move(to: CGPoint(x: 2, y: 53))
        p.addCurve(to: CGPoint(x: 16, y: 64), control1: CGPoint(x: 1, y: 48), control2: CGPoint(x: 12, y: 61))
        p.addLine(to: CGPoint(x: 12, y: 65))
        p.addCurve(to: CGPoint(x: 51, y: 65), control1: CGPoint(x: 22, y: 83), control2: CGPoint(x: 43, y: 76))
        p.addCurve(to: CGPoint(x: 57, y: 65), control1: CGPoint(x: 56, y: 57), control2: CGPoint(x: 56, y: 61))
        p.addCurve(to: CGPoint(x: 75, y: 76), control1: CGPoint(x: 56, y: 79), control2: CGPoint(x: 66, y: 86))
        p.addLine(to: CGPoint(x: 80, y: 64))
        p.addCurve(to: CGPoint(x: 84, y: 71), control1: CGPoint(x: 83, y: 60), control2: CGPoint(x: 83, y: 69))
        p.addLine(to: CGPoint(x: 97, y: 53))
        p.addCurve(to: CGPoint(x: 92, y: 76), control1: CGPoint(x: 103, y: 43), control2: CGPoint(x: 98, y: 71))
        p.addLine(to: CGPoint(x: 90, y: 72))
        p.addCurve(to: CGPoint(x: 50, y: 100), control1: CGPoint(x: 79, y: 88), control2: CGPoint(x: 62, y: 90))
        p.addCurve(to: CGPoint(x: 7, y: 72), control1: CGPoint(x: 32, y: 88), control2: CGPoint(x: 16, y: 89))
        p.addLine(to: CGPoint(x: 5, y: 76))
        p.addCurve(to: CGPoint(x: 2, y: 53), control1: CGPoint(x: 1, y: 73), control2: CGPoint(x: 0, y: 60)); p.closeSubpath()
        p.move(to: CGPoint(x: 25, y: 82))
        p.addCurve(to: CGPoint(x: 88, y: 73), control1: CGPoint(x: 51, y: 93), control2: CGPoint(x: 70, y: 89))
        p.addCurve(to: CGPoint(x: 25, y: 82), control1: CGPoint(x: 76, y: 93), control2: CGPoint(x: 47, y: 96)); p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width / 100, y: rect.height / 102).translatedBy(x: rect.minX, y: rect.minY))
    }
}
#endif
