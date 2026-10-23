import SwiftUI

/// Anchor's own anchor: a solid, weighted silhouette (ring, a stock with round
/// end knobs, a tapered shank, curved arms with flukes), drawn as one filled
/// shape so it reads as an object with mass rather than an outline icon.
/// `depth` lights it from above with a soft gradient, for the moments when the
/// anchor is a thing that falls and sinks rather than a small sign.
public struct AnchorFigure: View {
    private let color: Color
    private let depth: Bool

    public init(color: Color = AnchorPalette.deepSea, depth: Bool = false) {
        self.color = color
        self.depth = depth
    }

    public var body: some View {
        Group {
            if depth {
                AnchorFigureShape().fill(LinearGradient(
                    colors: [color.mix(with: .white, by: 0.24), color],
                    startPoint: .top, endPoint: .bottom))
            } else {
                AnchorFigureShape().fill(color)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The silhouette in a unit square, scaled to fit the largest centered square.
public struct AnchorFigureShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        Self.unit.applying(Self.fit(rect))
    }

    static func fit(_ rect: CGRect) -> CGAffineTransform {
        let side = min(rect.width, rect.height)
        return CGAffineTransform(translationX: rect.midX - side / 2, y: rect.midY - side / 2)
            .scaledBy(x: side, y: side)
    }

    /// Built once: each part is a stroked or filled piece, joined into one outline.
    static let unit: Path = {
        func line(_ from: CGPoint, _ to: CGPoint, width: CGFloat) -> Path {
            var path = Path()
            path.move(to: from)
            path.addLine(to: to)
            return path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round))
        }
        func disc(_ center: CGPoint, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        func rounded(_ corners: [CGPoint], radius: CGFloat) -> Path {
            var path = Path()
            let last = corners[corners.count - 1]
            path.move(to: CGPoint(x: (last.x + corners[0].x) / 2, y: (last.y + corners[0].y) / 2))
            for index in corners.indices {
                path.addArc(tangent1End: corners[index], tangent2End: corners[(index + 1) % corners.count], radius: radius)
            }
            path.closeSubpath()
            return path
        }

        // The ring the rope ties to.
        var ring = Path()
        ring.addEllipse(in: CGRect(x: 0.425, y: 0.06, width: 0.15, height: 0.15))
        var parts = [ring.strokedPath(StrokeStyle(lineWidth: 0.056))]

        // The stock, with the round knobs of a ship's anchor at its ends.
        parts.append(line(CGPoint(x: 0.31, y: 0.315), CGPoint(x: 0.69, y: 0.315), width: 0.066))
        parts.append(disc(CGPoint(x: 0.30, y: 0.315), 0.048))
        parts.append(disc(CGPoint(x: 0.70, y: 0.315), 0.048))

        // The shank, a little heavier toward the crown.
        var shank = Path()
        shank.move(to: CGPoint(x: 0.465, y: 0.215))
        shank.addLine(to: CGPoint(x: 0.535, y: 0.215))
        shank.addLine(to: CGPoint(x: 0.552, y: 0.81))
        shank.addLine(to: CGPoint(x: 0.448, y: 0.81))
        shank.closeSubpath()
        parts.append(shank)

        // The arms: one arc under the shank, thickest where they meet the crown.
        var arms = Path()
        arms.addArc(center: CGPoint(x: 0.5, y: 0.5), radius: 0.33,
                    startAngle: .degrees(27), endAngle: .degrees(153), clockwise: false)
        parts.append(arms.strokedPath(StrokeStyle(lineWidth: 0.078, lineCap: .round)))
        parts.append(disc(CGPoint(x: 0.5, y: 0.80), 0.05))

        // A fluke at each arm's tip: an arrowhead along the arc, its barbs swept back.
        for side in [1.0, -1.0] {
            let angle = 27.0 * .pi / 180
            let tip = CGPoint(x: 0.5 + side * 0.33 * cos(angle), y: 0.5 + 0.33 * sin(angle))
            let along = CGPoint(x: side * sin(angle), y: -cos(angle))
            let out = CGPoint(x: side * cos(angle), y: sin(angle))
            func point(_ forward: CGFloat, _ outward: CGFloat) -> CGPoint {
                CGPoint(x: tip.x + forward * along.x + outward * out.x,
                        y: tip.y + forward * along.y + outward * out.y)
            }
            parts.append(rounded([point(0.118, 0), point(-0.035, 0.088), point(-0.035, -0.062)], radius: 0.014))
        }

        return parts.dropFirst().reduce(parts[0]) { $0.union($1) }
    }()
}
