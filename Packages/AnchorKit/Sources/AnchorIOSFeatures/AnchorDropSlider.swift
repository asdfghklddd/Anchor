#if os(iOS)
import AnchorDesign
import SwiftUI

/// The drop, as a slide: the anchor rides a channel of water and lets go once
/// it reaches the far end. Water fills the channel behind it as it goes; while
/// it waits, a slow current of sea colors runs along the rim and the words, so
/// it reads as something to move. Short of the end, it floats back. VoiceOver
/// drops it with a plain activate.
struct AnchorDropSlider: View {
    let enabled: Bool
    let saving: Bool
    let stepCount: Int
    let onDrop: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var dragging = false
    /// Reached the end and sent the drop; holds there until the save settles.
    @State private var dropped = false
    /// Far enough that letting go drops it; ticks once on the way in.
    @State private var armed = false

    private let height: CGFloat = 64
    private let inset: CGFloat = 5
    private let threshold: CGFloat = 0.82
    private var knob: CGFloat { height - inset * 2 }
    private var live: Bool { enabled && !saving && !dropped }

    var body: some View {
        GeometryReader { geometry in
            let travel = max(1, geometry.size.width - knob - inset * 2)
            let progress = min(1, max(0, offset / travel))
            TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || !enabled)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                ZStack(alignment: .leading) {
                    channel(time: time)
                    caption(time: time)
                        .padding(.leading, knob + inset)
                        .opacity(Double(1 - min(1, progress * 1.6)))
                    // Water gathers only once the anchor moves.
                    if enabled, dragging || offset > 0 {
                        water(level: inset + offset + knob / 2, time: time)
                            .clipShape(.capsule)
                            .allowsHitTesting(false)
                    }
                    anchorKnob(progress: progress)
                        .offset(x: inset + offset)
                        .gesture(slide(travel: travel), isEnabled: live)
                }
            }
        }
        .frame(height: height)
        .sensoryFeedback(.selection, trigger: armed) { _, now in now }
        .sensoryFeedback(.impact(weight: .medium), trigger: dropped) { _, now in now }
        .onChange(of: saving) { _, now in if !now, dropped { reset() } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(saving ? SetupCopy.saving : SetupCopy.dropButton(steps: stepCount))
        .accessibilityHint(SetupCopy.slideHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if live { onDrop() } }
        .disabled(!enabled)
        .accessibilityIdentifier("setup.start.button")
    }

    // MARK: Parts

    /// The channel: pale water, with a rim the current runs along.
    private func channel(time: TimeInterval) -> some View {
        Capsule()
            .fill(AnchorSetupStyle.card.opacity(enabled ? 0.92 : 0.6))
            .overlay {
                Capsule().strokeBorder(rim(time: time), lineWidth: enabled ? 1.6 : 1)
            }
            .shadow(color: AnchorSetupStyle.wave.opacity(enabled ? 0.28 : 0), radius: 10, y: 4)
    }

    private func rim(time: TimeInterval) -> AnyShapeStyle {
        guard enabled else { return AnyShapeStyle(AnchorSetupStyle.controlSurface) }
        return AnyShapeStyle(AngularGradient(
            colors: Self.current + [Self.current[0]],
            center: .center,
            angle: .degrees(reduceMotion ? 0 : time.truncatingRemainder(dividingBy: 6) * 60)))
    }

    /// The words, with a band of sea colors sweeping through them.
    private func caption(time: TimeInterval) -> some View {
        let words = HStack(spacing: 6) {
            Text(saving ? SetupCopy.saving : SetupCopy.slideLabel(steps: stepCount))
                .contentTransition(.numericText())
                .animation(AnchorMotion.micro, value: stepCount)
            if !saving { Image(systemName: "chevron.right.2") }
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)

        let sweep = reduceMotion ? 0.5 : (time.truncatingRemainder(dividingBy: 2.6) / 2.6) * 2.2 - 0.6
        return words
            .foregroundStyle(AnchorSetupStyle.heading.opacity(enabled ? 0.5 : 0.28))
            .overlay {
                if enabled {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Self.current[0], location: 0.35),
                            .init(color: Self.current[1], location: 0.5),
                            .init(color: Self.current[2], location: 0.65),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: UnitPoint(x: sweep - 0.45, y: 0.5),
                        endPoint: UnitPoint(x: sweep + 0.45, y: 0.5))
                    .mask(words)
                }
            }
            .frame(maxWidth: .infinity)
    }

    /// Deeper water behind the anchor, its edge rolling, a few bubbles rising.
    private func water(level: CGFloat, time: TimeInterval) -> some View {
        Canvas { context, size in
            let phase = reduceMotion ? 0 : time * 3.2
            var path = Path()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: level, y: 0))
            let rows = 16
            for row in 0...rows {
                let y = size.height * CGFloat(row) / CGFloat(rows)
                let swell = sin(Double(row) / Double(rows) * .pi * 2 + phase) * 4
                path.addLine(to: CGPoint(x: level + swell, y: y))
            }
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .linearGradient(
                Gradient(colors: [AnchorSetupStyle.accent.opacity(0.45), AnchorSetupStyle.wave.opacity(0.9)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

            guard level > knob, !reduceMotion else { return }
            for index in 0..<4 {
                let rise = (time * 0.6 + Double(index) * 0.27).truncatingRemainder(dividingBy: 1)
                let x = level * (0.2 + 0.18 * CGFloat(index)) - knob * 0.4
                guard x > 12 else { continue }
                let radius = 1.6 + CGFloat(index % 2)
                let center = CGPoint(x: x + sin(rise * 6) * 2, y: size.height * (1 - rise))
                context.stroke(
                    Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(0.7 * (1 - rise))), lineWidth: 1)
            }
        }
    }

    private func anchorKnob(progress: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(AnchorSetupStyle.card)
                .shadow(color: AnchorPalette.deepSea.opacity(enabled ? 0.22 : 0.08), radius: dragging ? 9 : 5, y: dragging ? 5 : 3)
            AnchorFigure(color: enabled ? AnchorSetupStyle.accent : AnchorSetupStyle.secondary.opacity(0.5), depth: enabled)
                .frame(width: 28, height: 28)
                // Trails back as it is pulled, then sinks a little when it lets go.
                .rotationEffect(.degrees(dropped ? 0 : -16 * Double(progress)))
                .offset(y: dropped ? 4 : 0)
            if saving {
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(AnchorSetupStyle.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .padding(2)
                    .rotationEffect(.degrees(reduceMotion ? 0 : Date.now.timeIntervalSinceReferenceDate * 360))
            }
        }
        .frame(width: knob, height: knob)
        .scaleEffect(dragging ? 1.06 : 1)
        .animation(AnchorMotion.micro, value: dragging)
        .animation(AnchorMotion.micro, value: dropped)
        .contentShape(.circle)
    }

    // MARK: Motion

    private func slide(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragging = true
                offset = min(travel, max(0, value.translation.width))
                armed = offset / travel >= threshold
            }
            .onEnded { _ in
                dragging = false
                if offset / travel >= threshold {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.28, bounce: 0.15)) {
                        offset = travel
                    }
                    dropped = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.18))
                        onDrop()
                        // A drop that did not start saving (the title moved words) comes back.
                        try? await Task.sleep(for: .seconds(0.5))
                        if !saving { reset() }
                    }
                } else {
                    armed = false
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.4, bounce: 0.35)) {
                        offset = 0
                    }
                }
            }
    }

    private func reset() {
        dropped = false
        armed = false
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.45, bounce: 0.3)) {
            offset = 0
        }
    }

    /// The current's colors: shallows to open sea.
    private static let current: [Color] = [
        AnchorSetupStyle.accent, AnchorPalette.seafoam, AnchorSetupStyle.heading, AnchorSetupStyle.wave,
    ]
}
#endif
