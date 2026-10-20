#if os(iOS)
import AnchorDesign
import SwiftUI

/// A slow current on the harbor water while a source reports a run and the
/// board's copy is fresh: the work is going on and the board is live. It
/// stills when the run ends or the link goes quiet, so a frozen board never
/// looks like a working one. With reduced motion the lines show but stay put.
struct HarborCurrent: View {
    let flowing: Bool
    let reduceMotion: Bool

    /// One wavelength crosses in this long: slow enough to sit in the corner of the eye.
    private static let period: TimeInterval = 9

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !flowing || reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            Canvas { canvas, size in
                for (y, amplitude, opacity, direction) in [(12.0, 2.2, 0.75, 1.0), (28.0, 1.6, 0.45, -0.6)] {
                    canvas.stroke(Self.wave(width: size.width, y: y, amplitude: amplitude, phase: phase * direction),
                                  with: .color(.white.opacity(opacity)), lineWidth: 1.4)
                }
            }
        }
        .opacity(flowing ? 1 : 0)
        .animation(.easeInOut(duration: 0.8), value: flowing)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func wave(width: CGFloat, y: CGFloat, amplitude: CGFloat, phase: Double) -> Path {
        let wavelength: CGFloat = 140
        var path = Path()
        for x in stride(from: 0, through: width, by: 4) {
            let angle = (x / wavelength + phase) * 2 * .pi
            let point = CGPoint(x: x, y: y + sin(angle) * amplitude)
            if x == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

/// One tinted swell over a task when a result for it arrives, then stillness:
/// the held state (its words and symbol) is the record, the swell only the news.
struct ResultSwell: View {
    let trigger: Int
    let tone: Color
    let cornerRadius: CGFloat
    let reduceMotion: Bool

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, rise in
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(tone.opacity(0.28 * rise))
                    .scaleEffect(reduceMotion ? 1 : 1 + 0.04 * rise)
            } keyframes: { _ in
                CubicKeyframe(1, duration: reduceMotion ? 0.12 : 0.24)
                LinearKeyframe(1, duration: 0.3)
                CubicKeyframe(0, duration: 0.8)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The check that draws itself when the person marks a step done, then fades;
/// the step lifting away and the count ticking carry the rest.
struct DrawnCheck: View {
    let trigger: Int
    let size: CGFloat
    let reduceMotion: Bool

    private struct Phase {
        var draw = 0.0
        var opacity = 0.0
    }

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .keyframeAnimator(initialValue: Phase(), trigger: trigger) { _, phase in
                CheckShape()
                    .trim(from: 0, to: phase.draw)
                    .stroke(AnchorStateTone.done.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .opacity(phase.opacity)
                    .frame(width: size, height: size)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.01)
                    LinearKeyframe(1, duration: 0.7)
                    CubicKeyframe(0, duration: 0.35)
                }
                KeyframeTrack(\.draw) {
                    CubicKeyframe(1, duration: reduceMotion ? 0.01 : 0.28)
                    LinearKeyframe(1, duration: reduceMotion ? 1.04 : 0.77)
                    LinearKeyframe(0, duration: 0.01)
                }
            }
            .accessibilityHidden(true)
    }

    private struct CheckShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.54))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.78))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.26))
            return path
        }
    }
}
#endif
