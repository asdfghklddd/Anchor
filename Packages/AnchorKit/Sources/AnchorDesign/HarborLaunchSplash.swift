#if os(iOS)
import SwiftUI

/// The launch harbor. Layers, back to front: sky, deep water, the threads and the
/// main line, the logo, the translucent near water that tints whatever is
/// submerged, spray, then the wordmark and slogan.
public struct HarborLaunchSplash: View {
    private let startedAt: Date
    private let timing: HarborLaunchChoreography.Timing
    private let onSkip: () -> Void

    public init(startedAt: Date, timing: HarborLaunchChoreography.Timing, onSkip: @escaping () -> Void = {}) {
        self.startedAt = startedAt
        self.timing = timing
        self.onSkip = onSkip
    }

    /// The logo's blue, for the main line and the words about it.
    private static let lineBlue = Color(anchorHex: 0x1E8FF2)
    /// The task folders' colors, for the threads.
    private static let threadColors = [Color(anchorHex: 0xFFB400), Color(anchorHex: 0x49C8FF), Color(anchorHex: 0xFF64DB)]

    public var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSince(startedAt)
                let scene = HarborLaunchChoreography(size: geometry.size, timing: timing)
                ZStack {
                    Canvas { canvas, size in drawBackdrop(in: &canvas, size: size, scene: scene, t: t) }
                    logo(scene.logo(at: t), side: scene.logoSide, submersion: scene.submersion(at: t))
                    Canvas { canvas, size in drawForeground(in: &canvas, size: size, scene: scene, t: t) }
                    wordmark(scene: scene, t: t)
                }
                .opacity(scene.sceneOpacity(at: t))
            }
        }
        .ignoresSafeArea()
        // The scene is decoration; a tap hands over to the workspace early.
        .contentShape(.rect)
        .onTapGesture(perform: onSkip)
        .accessibilityHidden(true)
    }

    private func logo(_ pose: HarborLaunchChoreography.LogoPose, side: CGFloat, submersion: Double) -> some View {
        Image("AnchorLaunchLogo", bundle: .module)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .overlay {
                Image("AnchorLaunchLogo", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .opacity(submersion)
            }
            .frame(width: side, height: side)
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(pose.rotationDegrees))
            .position(pose.center)
            .opacity(pose.opacity)
    }

    private func wordmark(scene: HarborLaunchChoreography, t: Double) -> some View {
        let mark = scene.wordmark(at: t)
        return VStack(spacing: 8) {
            Text(verbatim: "Anchor")
                .font(AnchorFonts.poppins(38, medium: true, relativeTo: .largeTitle))
                .foregroundStyle(AnchorIOSStyle.heading)
                .opacity(mark.opacity)
                .blur(radius: mark.blur)
                .offset(y: mark.offset)
            // One line where it fits; a narrow screen stacks the two halves.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { sloganPhrases(scene: scene, t: t) }
                VStack(spacing: 4) { sloganPhrases(scene: scene, t: t) }
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .frame(width: scene.size.width, height: scene.textBottomY, alignment: .bottom)
        .position(x: scene.size.width / 2, y: scene.textBottomY / 2)
    }

    /// Each half of the slogan arrives with what it describes: the threads, then the main line.
    @ViewBuilder
    private func sloganPhrases(scene: HarborLaunchChoreography, t: Double) -> some View {
        let threads = scene.threadsLine(at: t)
        let main = scene.mainLineText(at: t)
        Text(L10n.launchSloganThreads)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(AnchorIOSStyle.secondaryText)
            .lineLimit(1)
            .fixedSize()
            .opacity(threads.opacity)
            .blur(radius: threads.blur)
            .offset(y: threads.offset)
        Text(L10n.launchSloganMainLine)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Self.lineBlue)
            .lineLimit(1)
            .fixedSize()
            .opacity(main.opacity)
            .blur(radius: main.blur)
            .offset(y: main.offset)
    }

    // MARK: Drawing

    private func surfacePath(size: CGSize, scene: HarborLaunchChoreography, t: Double, phase: Double = 0) -> Path {
        let base = scene.waterline(at: t)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height))
        stride(from: CGFloat(0), through: size.width, by: 4).forEach { x in
            path.addLine(to: CGPoint(x: x, y: base + scene.surfaceOffset(x: x, at: t + phase)))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }

    private func drawBackdrop(in canvas: inout GraphicsContext, size: CGSize, scene: HarborLaunchChoreography, t: Double) {
        let rect = CGRect(origin: .zero, size: size)
        canvas.fill(Path(rect), with: .linearGradient(
            Gradient(colors: [AnchorIOSStyle.canvasTop, AnchorIOSStyle.canvasBottom]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Far water, offset in phase so the two layers read as depth.
        let waterline = scene.waterline(at: t)
        canvas.fill(surfacePath(size: size, scene: scene, t: t, phase: 0.9), with: .linearGradient(
            Gradient(colors: [AnchorIOSStyle.oceanSurface, AnchorIOSStyle.oceanDeep]),
            startPoint: CGPoint(x: 0, y: waterline), endPoint: CGPoint(x: 0, y: size.height)
        ))

        // Soft light shafts through the water; still under reduced motion.
        let drift = timing.reduceMotion ? 0 : CGFloat(sin(t * 0.8)) * 10
        for (index, x) in [0.22, 0.52, 0.80].enumerated() {
            let top = size.width * x + drift * CGFloat(index % 2 == 0 ? 1 : -1)
            var shaft = Path()
            shaft.move(to: CGPoint(x: top - 14, y: waterline))
            shaft.addLine(to: CGPoint(x: top + 22, y: waterline))
            shaft.addLine(to: CGPoint(x: top + 70, y: size.height))
            shaft.addLine(to: CGPoint(x: top - 4, y: size.height))
            shaft.closeSubpath()
            canvas.fill(shaft, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.16), .white.opacity(0)]),
                startPoint: CGPoint(x: 0, y: waterline), endPoint: CGPoint(x: 0, y: size.height * 0.95)
            ))
        }

        drawThreads(in: &canvas, scene: scene, t: t)
    }

    /// The many threads with their running beads, then the one line they become.
    private func drawThreads(in canvas: inout GraphicsContext, scene: HarborLaunchChoreography, t: Double) {
        for thread in scene.threads(at: t) {
            guard let first = thread.points.first else { continue }
            let color = Self.threadColors[thread.hue % Self.threadColors.count]
            var path = Path()
            path.move(to: first)
            thread.points.dropFirst().forEach { path.addLine(to: $0) }
            canvas.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            if let bead = thread.bead {
                canvas.fill(Path(ellipseIn: CGRect(x: bead.x - 4, y: bead.y - 4, width: 8, height: 8)), with: .color(color))
                canvas.fill(Path(ellipseIn: CGRect(x: bead.x - 1.6, y: bead.y - 1.6, width: 3.2, height: 3.2)), with: .color(.white))
            }
        }

        if let pulse = scene.mergePulse(at: t) {
            let ring = CGRect(x: pulse.center.x - pulse.radius, y: pulse.center.y - pulse.radius,
                              width: pulse.radius * 2, height: pulse.radius * 2)
            canvas.stroke(Path(ellipseIn: ring), with: .color(Self.lineBlue.opacity(pulse.opacity)), lineWidth: 2)
        }

        if let line = scene.mainLine(at: t) {
            var path = Path()
            path.move(to: line.top)
            path.addQuadCurve(
                to: line.bottom,
                control: CGPoint(x: (line.top.x + line.bottom.x) / 2 + line.sway, y: (line.top.y + line.bottom.y) / 2)
            )
            canvas.stroke(path, with: .color(Self.lineBlue), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            canvas.stroke(path, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, dash: [5, 7]))
        }
    }

    private func drawForeground(in canvas: inout GraphicsContext, size: CGSize, scene: HarborLaunchChoreography, t: Double) {
        let waterline = scene.waterline(at: t)
        let surface = surfacePath(size: size, scene: scene, t: t)
        canvas.fill(surface, with: .linearGradient(
            // Light enough that the submerged logo stays legible during the hold.
            Gradient(colors: [AnchorIOSStyle.oceanSurface.opacity(0.30), AnchorIOSStyle.oceanDeep.opacity(0.46)]),
            startPoint: CGPoint(x: 0, y: waterline), endPoint: CGPoint(x: 0, y: size.height)
        ))

        // A bright rim along the surface line.
        var rim = Path()
        stride(from: CGFloat(0), through: size.width, by: 4).forEach { x in
            let point = CGPoint(x: x, y: waterline + scene.surfaceOffset(x: x, at: t))
            if x == 0 { rim.move(to: point) } else { rim.addLine(to: point) }
        }
        canvas.stroke(rim, with: .color(.white.opacity(0.75)), lineWidth: 1.5)

        for ripple in scene.ripples(at: t) {
            let ring = CGRect(
                x: ripple.center.x - ripple.radius, y: ripple.center.y - ripple.radius * 0.24,
                width: ripple.radius * 2, height: ripple.radius * 0.48
            )
            canvas.stroke(Path(ellipseIn: ring), with: .color(.white.opacity(ripple.opacity)), lineWidth: 1.5)
        }
        for bubble in scene.bubbles(at: t) {
            canvas.stroke(Path(ellipseIn: circle(bubble)), with: .color(.white.opacity(bubble.opacity)), lineWidth: 1)
        }
        for drop in scene.droplets(at: t) {
            canvas.fill(Path(ellipseIn: circle(drop)), with: .color(AnchorIOSStyle.oceanSurface.opacity(drop.opacity)))
            canvas.fill(
                Path(ellipseIn: circle(drop).insetBy(dx: drop.radius * 0.45, dy: drop.radius * 0.45)
                    .offsetBy(dx: -drop.radius * 0.2, dy: -drop.radius * 0.2)),
                with: .color(.white.opacity(drop.opacity * 0.8))
            )
        }
    }

    private func circle(_ particle: HarborLaunchChoreography.Particle) -> CGRect {
        CGRect(
            x: particle.center.x - particle.radius, y: particle.center.y - particle.radius,
            width: particle.radius * 2, height: particle.radius * 2
        )
    }
}
#endif
