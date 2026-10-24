#if os(iOS)
import SwiftUI

/// The desk clock's digits in the Figma typeface (LogoSC Unbounded Sans),
/// drawn from outlines traced off the owner's digit sheet, so the clock
/// matches the design without bundling the font.
enum DeskClockGlyphs {
    struct Shape {
        /// Ink width, in the same units as the outlines.
        let width: Double
        /// Closed outlines as x, y pairs; holes fill even-odd.
        let contours: [[Double]]
    }

    /// Space between glyphs, as the Figma clock sets "21:27".
    static let gap = 4.0
    /// The colon sits lower in the design's full-width "：" than on the sheet.
    static let colonDrop = 3.5

    static func width(of text: String) -> Double {
        let glyphs = text.compactMap { shapes[$0] }
        return glyphs.map(\.width).reduce(0, +) + gap * Double(max(0, glyphs.count - 1))
    }

    /// The outline of `text`, scaled so its digits are `capHeight` tall.
    static func path(_ text: String, capHeight: CGFloat) -> Path {
        let scale = capHeight / self.capHeight
        var path = Path()
        var x = 0.0
        for character in text {
            guard let shape = shapes[character] else { continue }
            let dy = character == ":" ? colonDrop : 0
            for contour in shape.contours {
                let points = stride(from: 0, to: contour.count - 1, by: 2).map {
                    CGPoint(x: (x + contour[$0]) * scale, y: (contour[$0 + 1] + dy) * scale)
                }
                guard let last = points.last else { continue }
                // The traced points steer quadratic curves through their midpoints, so edges stay smooth.
                path.move(to: midpoint(last, points[0]))
                for (index, point) in points.enumerated() {
                    path.addQuadCurve(to: midpoint(point, points[(index + 1) % points.count]), control: point)
                }
                path.closeSubpath()
            }
            x += shape.width + gap
        }
        return path
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

/// "21:27" in the desk typeface. It reads as text to VoiceOver.
struct DeskClockText: View {
    let text: String
    var capHeight: CGFloat = 47
    var color: Color

    var body: some View {
        let scale = capHeight / DeskClockGlyphs.capHeight
        DeskClockGlyphs.path(text, capHeight: capHeight)
            .fill(color, style: FillStyle(eoFill: true))
            .frame(width: DeskClockGlyphs.width(of: text) * scale, height: capHeight, alignment: .topLeading)
            .accessibilityElement()
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isStaticText)
    }
}
#endif
