import SwiftUI

public struct HarborAnchorGlyph: View {
    private let color: Color
    private let lineWidth: CGFloat

    public init(color: Color = AnchorPalette.deepSea, lineWidth: CGFloat = 2.4) {
        self.color = color
        self.lineWidth = lineWidth
    }

    public var body: some View {
        Canvas { context, size in
            let centerX = size.width / 2
            let topY = size.height * 0.10
            let ringSize = min(size.width, size.height) * 0.23

            var path = Path()
            path.addEllipse(
                in: CGRect(
                    x: centerX - ringSize / 2,
                    y: topY,
                    width: ringSize,
                    height: ringSize
                )
            )
            path.move(to: CGPoint(x: centerX, y: topY + ringSize))
            path.addLine(to: CGPoint(x: centerX, y: size.height * 0.77))
            path.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.42))
            path.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.42))
            path.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.61))
            path.addCurve(
                to: CGPoint(x: centerX, y: size.height * 0.90),
                control1: CGPoint(x: size.width * 0.17, y: size.height * 0.82),
                control2: CGPoint(x: size.width * 0.34, y: size.height * 0.90)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.86, y: size.height * 0.61),
                control1: CGPoint(x: size.width * 0.66, y: size.height * 0.90),
                control2: CGPoint(x: size.width * 0.83, y: size.height * 0.82)
            )
            path.move(to: CGPoint(x: size.width * 0.14, y: size.height * 0.61))
            path.addLine(to: CGPoint(x: size.width * 0.10, y: size.height * 0.77))
            path.move(to: CGPoint(x: size.width * 0.86, y: size.height * 0.61))
            path.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.77))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
