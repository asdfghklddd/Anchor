import SwiftUI

/// Anchor's harbor boat, drawn in the app icon's language: an azure hull shaped like
/// the anchor crown with the mark's white wave across it, a pale mainsail and a
/// brand-gradient jib, riding a small patch of the launch-screen water.
/// The bow points right, toward the screen edge it sails off when tucking away,
/// so the anchor rope leaves from the stern on the open-water side.
public struct HarborBoatGlyph: View {
    public var wind: CGFloat

    public init(wind: CGFloat = 0) {
        self.wind = wind
    }

    /// Stern tip in unit coordinates; the edge effects attach the anchor rope here.
    public static let ropePoint = CGPoint(x: 0.12, y: 0.59)
    /// Resting waterline in unit coordinates.
    public static let waterlineY: CGFloat = 0.80

    // The icon's azure gradient and the launch harbor's water.
    private static let azureLight = Color(red: 0.27, green: 0.82, blue: 0.97)
    private static let azure = Color(red: 0.10, green: 0.56, blue: 0.95)
    private static let azureDeep = Color(red: 0.06, green: 0.40, blue: 0.84)
    private static let sailLight = Color(red: 1.00, green: 1.00, blue: 1.00)
    private static let sailShade = Color(red: 0.84, green: 0.95, blue: 0.99)
    private static let outline = Color(red: 0.09, green: 0.43, blue: 0.70)
    private static let pennant = Color(red: 0.96, green: 0.78, blue: 0.18)
    private static let oceanSurface = Color(red: 0.44, green: 0.85, blue: 0.94)

    public var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: w * x, y: h * y) }
            let gust = min(1, max(-1, wind))
            let billow = gust * w * 0.02
            let line = max(0.6, w * 0.012)

            // Harbor water under the hull: a soft lens rather than a hard horizon.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: w * 0.02))
                layer.fill(
                    Path(ellipseIn: CGRect(x: w * 0.06, y: h * 0.775, width: w * 0.88, height: h * 0.13)),
                    with: .radialGradient(
                        Gradient(colors: [Self.oceanSurface.opacity(0.55), Self.oceanSurface.opacity(0)]),
                        center: p(0.5, 0.83), startRadius: 0, endRadius: w * 0.44
                    )
                )
            }

            // Mainsail, aft of the mast; its leech swells with the wind.
            var mainsail = Path()
            mainsail.move(to: p(0.475, 0.10))
            mainsail.addLine(to: p(0.475, 0.605))
            mainsail.addLine(to: p(0.19, 0.605))
            mainsail.addQuadCurve(to: p(0.475, 0.10), control: CGPoint(x: w * 0.22 - billow, y: h * 0.31))
            context.fill(mainsail, with: .linearGradient(
                Gradient(colors: [Self.sailLight, Self.sailShade]),
                startPoint: p(0.40, 0.12), endPoint: p(0.26, 0.62)
            ))
            context.stroke(mainsail, with: .color(Self.outline.opacity(0.55)),
                           style: StrokeStyle(lineWidth: line, lineJoin: .round))

            // The jib takes the icon's azure gradient.
            var jib = Path()
            jib.move(to: p(0.525, 0.15))
            jib.addQuadCurve(to: p(0.80, 0.585), control: CGPoint(x: w * 0.78 + billow, y: h * 0.32))
            jib.addLine(to: p(0.525, 0.595))
            jib.closeSubpath()
            context.fill(jib, with: .linearGradient(
                Gradient(colors: [Self.azureLight, Self.azure]),
                startPoint: p(0.55, 0.16), endPoint: p(0.70, 0.60)
            ))
            // The icon's crossbar: one batten across both sails turns them into its "A".
            var batten = Path()
            batten.move(to: p(0.31, 0.44))
            batten.addLine(to: p(0.475, 0.44))
            context.stroke(batten, with: .color(Self.azure.opacity(0.70)),
                           style: StrokeStyle(lineWidth: line * 1.5, lineCap: .round))
            batten = Path()
            batten.move(to: p(0.525, 0.44))
            batten.addLine(to: p(0.71, 0.44))
            context.stroke(batten, with: .color(.white.opacity(0.80)),
                           style: StrokeStyle(lineWidth: line * 1.5, lineCap: .round))

            var mast = Path()
            mast.move(to: p(0.50, 0.075))
            mast.addLine(to: p(0.50, 0.66))
            context.stroke(mast, with: .color(Self.outline), style: StrokeStyle(lineWidth: w * 0.024, lineCap: .round))

            var flag = Path()
            flag.move(to: p(0.51, 0.075))
            flag.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.105 + billow * 0.5),
                              control: CGPoint(x: w * 0.59, y: h * 0.07 + billow * 0.3))
            flag.addLine(to: p(0.51, 0.145))
            flag.closeSubpath()
            context.fill(flag, with: .color(Self.pennant))

            // A crescent hull with upturned tips, echoing the anchor crown in the icon.
            var hull = Path()
            hull.move(to: p(0.10, 0.575))
            hull.addQuadCurve(to: p(0.93, 0.545), control: p(0.52, 0.735))
            hull.addCurve(to: p(0.50, 0.845), control1: p(0.86, 0.77), control2: p(0.70, 0.845))
            hull.addCurve(to: p(0.10, 0.575), control1: p(0.29, 0.845), control2: p(0.15, 0.76))
            hull.closeSubpath()
            context.fill(hull, with: .linearGradient(
                Gradient(colors: [Self.azureLight, Self.azure, Self.azureDeep]),
                startPoint: p(0.5, 0.60), endPoint: p(0.5, 0.87)
            ))
            context.stroke(hull, with: .color(Self.outline.opacity(0.45)),
                           style: StrokeStyle(lineWidth: line * 0.8, lineJoin: .round))

            // The mark's white wave rides along the hull.
            var wave = Path()
            wave.move(to: p(0.26, 0.745))
            wave.addCurve(to: p(0.50, 0.745), control1: p(0.33, 0.70), control2: p(0.42, 0.79))
            wave.addCurve(to: p(0.76, 0.728), control1: p(0.58, 0.70), control2: p(0.69, 0.775))
            context.stroke(wave, with: .color(.white.opacity(0.92)),
                           style: StrokeStyle(lineWidth: w * 0.03, lineCap: .round, lineJoin: .round))
            // A glossy rail catches light along the sheer, like the icon's highlight.
            var rail = Path()
            rail.move(to: p(0.16, 0.612))
            rail.addQuadCurve(to: p(0.87, 0.585), control: p(0.52, 0.728))
            context.stroke(rail, with: .color(.white.opacity(0.55)),
                           style: StrokeStyle(lineWidth: line, lineCap: .round))

            // Water laps over the keel so the hull sits in the harbor, not on it.
            context.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: h * Self.waterlineY, width: w, height: h)))
                layer.fill(hull, with: .color(Self.oceanSurface.opacity(0.35)))
            }
            var surface = Path()
            surface.move(to: p(0.08, Self.waterlineY + 0.005))
            surface.addQuadCurve(to: p(0.30, Self.waterlineY), control: p(0.19, Self.waterlineY - 0.025))
            surface.move(to: p(0.70, Self.waterlineY))
            surface.addQuadCurve(to: p(0.93, Self.waterlineY + 0.005), control: p(0.81, Self.waterlineY - 0.025))
            context.stroke(surface, with: .color(.white.opacity(0.85)),
                           style: StrokeStyle(lineWidth: line, lineCap: .round))
            var ripple = Path()
            ripple.move(to: p(0.22, 0.885))
            ripple.addQuadCurve(to: p(0.78, 0.885), control: p(0.50, 0.915))
            context.stroke(ripple, with: .linearGradient(
                Gradient(colors: [Self.oceanSurface.opacity(0), Self.oceanSurface.opacity(0.85), Self.oceanSurface.opacity(0)]),
                startPoint: p(0.22, 0.885), endPoint: p(0.78, 0.885)
            ), style: StrokeStyle(lineWidth: line * 1.2, lineCap: .round))
        }
        .accessibilityHidden(true)
    }
}
