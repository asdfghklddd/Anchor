// Role: everything the tour draws over the real screens: the frost with its clean cut around the target (`TourFrost`),
// captions, hint rings, tap blockers, and scene pieces such as the dial, turn prompt and first drop.
// Note: real views publish where they are through `TourSpot` preferences, and the frost cuts around them.
// `TourBlocker` swallows taps outside the opening. Give any button that must work during a step an opening too.
// Design: whole screen under frost with only the key area clear. No dimming, one line of copy, no Next buttons.
// Performance: animated strokes must wrap phases; see the note in `AnchorDropSlider.swift`.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UserNotifications

// MARK: Spots

/// The parts of the real home and desk the tour lights, in the order it lights them.
enum TourSpot: Hashable {
    /// Today's anchoring on the home: its clock, goal and token bars.
    case clock
    case tasks, anchorButton
    /// Skip in the home's top bar, which answers even while the rest is held.
    case skip
    /// A folder on the desk, by its place from the left.
    case folder(Int)
    /// A task's folder on the desk.
    case taskFolder(UUID)
    /// The card in front of a task's folder.
    case frontCard(UUID)
    /// A task's card on the home.
    case homeTask(UUID)
    /// On the setup page: its line, both fields, the plan field, the slider.
    case setupLine, setupInput, setupPlan, setupSlider
    /// The conversation opened over the desk, and what it waits on the person for.
    case recallCard, recallWaiting
    /// The pet's nook on the desk.
    case pet
}

/// Collects target frames from the real views.
struct TourSpotKey: PreferenceKey {
    static let defaultValue: [TourSpot: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourSpot: Anchor<CGRect>], nextValue: () -> [TourSpot: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks a part of the home or desk the tour can light. Parts inside it
    /// (a folder's front card) keep their own marks.
    func tourSpot(_ spot: TourSpot) -> some View {
        transformAnchorPreference(key: TourSpotKey.self, value: .bounds) { spots, anchor in spots[spot] = anchor }
    }

    /// Marks a part only while it is that part, such as the card in front.
    func tourSpot(_ spot: TourSpot?) -> some View {
        transformAnchorPreference(key: TourSpotKey.self, value: .bounds) { spots, anchor in
            if let spot { spots[spot] = anchor }
        }
    }
}

// MARK: Hints

/// The tour's line: one short line, written straight on the frost (or on a
/// page of the tour's own), saying what to do. When the screen moves on by
/// itself, the line is replaced where it stands.
struct TourCaption<Lead: View>: View {
    let text: String
    /// Centred and a size up, for a line with the middle of the screen to itself.
    var centered = false
    /// A small picture before the line, such as the phone turning.
    @ViewBuilder var lead: Lead

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            lead
            ZStack(alignment: centered ? .top : .topLeading) {
                TourRisingLine(text: text, reduceMotion: reduceMotion, size: centered ? 28 : 22, centered: centered)
                    .id(text)
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.1), value: text)
    }
}

extension TourCaption where Lead == EmptyView {
    init(text: String, centered: Bool = false) {
        self.init(text: text, centered: centered) { EmptyView() }
    }
}

/// Frosted glass over the whole screen, cut clean around the step's target
/// like a pane with a window in it. The cut opens out from the target's
/// middle as the glass condenses, and glides from target to target; its edge
/// is the pane's own: a little shade where the glass is thick, a hairline of
/// light brighter where the light falls from above, and a faint dark line
/// holding the clear part. Each time the cut lands, a streak of light runs
/// once round it, then the edge breathes; a tap that misses brightens it
/// once. With no target the whole screen frosts, the cut closing into where
/// it last was.
struct TourFrost: View {
    /// The part left clear, in this view's space; none frosts everything.
    var hole: CGRect?
    var radius: CGFloat = 0
    var nudges = 0

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var shown = false
    /// Where the cut last was, so frosting over closes it there, not in a corner.
    @State private var resting: CGRect?
    /// Each landing somewhere new sends the light round the edge.
    @State private var landings = 0
    @State private var drift = false

    /// The clear margin around the target, beyond what the step already leaves.
    static let margin: CGFloat = 2
    static let glide = Animation.spring(duration: 0.8, bounce: 0.12)

    var body: some View {
        let target = hole.map { $0.insetBy(dx: -Self.margin, dy: -Self.margin) }
            ?? resting.map { CGRect(x: $0.midX, y: $0.midY, width: 0, height: 0) } ?? .zero
        let cut = shown ? target : CGRect(x: target.midX, y: target.midY, width: 0, height: 0)
        let corner = hole == nil || !shown ? 0 : radius + Self.margin
        glass
            .mask {
                SpotlightVeil(hole: cut, radius: corner)
                    .fill(style: FillStyle(eoFill: true))
            }
            .overlay(alignment: .topLeading) {
                if hole != nil, shown {
                    TourGlint(cut: cut, radius: corner, landings: landings, nudges: nudges)
                        .transition(.opacity)
                }
            }
            .opacity(shown ? 1 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.25) : Self.glide, value: hole)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                if let hole { resting = hole }
                withAnimation(reduceMotion ? .easeOut(duration: 0.25) : .spring(duration: 0.9, bounce: 0.1)) { shown = true }
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
                }
            }
            .onChange(of: hole) { old, new in
                guard let new else { return }
                resting = new
                if old.map({ abs($0.midX - new.midX) + abs($0.midY - new.midY) > 8 }) ?? true { landings += 1 }
            }
    }

    /// The pane: a strong blur, a breath of tint so words read on it, a sheen
    /// across it like glass under a ceiling light, and a slow light drifting
    /// through it as through the glass on a new iPhone's hello.
    private var glass: some View {
        let dark = colorScheme == .dark
        return GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(dark ? Color.black.opacity(0.2) : Color.white.opacity(0.16))
                LinearGradient(stops: [.init(color: .white.opacity(dark ? 0.07 : 0.26), location: 0),
                                       .init(color: .white.opacity(0), location: 0.45),
                                       .init(color: .white.opacity(dark ? 0.03 : 0.1), location: 1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [(dark ? TourInk.guide.opacity(0.1) : Color.white.opacity(0.32)), .clear],
                               center: .center, startRadius: 0, endRadius: max(size.width, size.height) * 0.45)
                    .frame(width: size.width * 1.4, height: size.height * 1.4)
                    .offset(x: size.width * (drift ? 0.22 : -0.22), y: size.height * (drift ? -0.18 : 0.14))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }
}

/// The cut's edge, drawn over the whole pane in its space: the shade of the
/// glass's thickness just outside the cut, a faint dark line holding the
/// clear part, and the hairline of light on the edge itself, brighter at the
/// top left; a streak runs once round it when the cut lands.
private struct TourGlint: View {
    let cut: CGRect
    let radius: CGFloat
    let landings: Int
    let nudges: Int

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .topLeading) {
            // The glass's thickness: shade on the frost, fading out from the cut.
            TourCutOutline(rect: cut, radius: radius)
                .stroke(Color.black.opacity(dark ? 0.45 : 0.14), lineWidth: 14)
                .blur(radius: 7)
                .mask {
                    SpotlightVeil(hole: cut, radius: radius).fill(style: FillStyle(eoFill: true))
                }
            ZStack {
                shape.inset(by: -1.2)
                    .stroke(Color.black.opacity(dark ? 0.5 : 0.1), lineWidth: 0.6)
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.4) / 3.4
                    let breath = reduceMotion ? 1 : 0.72 + 0.28 * (0.5 - 0.5 * cos(t * 2 * .pi))
                    ZStack {
                        shape.stroke(
                            LinearGradient(colors: [.white.opacity(dark ? 0.75 : 1), .white.opacity(dark ? 0.12 : 0.35)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2)
                        // A soft catch of light along the top edge.
                        shape.stroke(
                            LinearGradient(colors: [.white.opacity(dark ? 0.3 : 0.55), .clear],
                                           startPoint: .top, endPoint: .center),
                            lineWidth: 3)
                            .blur(radius: 1.5)
                    }
                    .opacity(breath)
                }
                if !reduceMotion {
                    // The streak: a short bright arc that travels the whole edge once.
                    Color.clear.keyframeAnimator(initialValue: 1.0, trigger: landings) { _, run in
                        ZStack {
                            shape.trim(from: max(0, run - 0.14), to: run)
                                .stroke(.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            shape.trim(from: max(0, run - 0.14), to: run)
                                .stroke(.white.opacity(dark ? 0.45 : 0.8), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .blur(radius: 4)
                        }
                        .opacity(run >= 1 ? 0 : 1)
                    } keyframes: { _ in
                        LinearKeyframe(0.0, duration: 0.01)
                        LinearKeyframe(0.0, duration: 0.45)
                        CubicKeyframe(1.0, duration: 1.25)
                    }
                }
            }
            .frame(width: cut.width, height: cut.height)
            .keyframeAnimator(initialValue: 1.0, trigger: nudges) { content, glow in
                content.brightness(0.3 * (glow - 1)).scaleEffect(1 + 0.03 * (glow - 1))
            } keyframes: { _ in
                SpringKeyframe(2.0, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.5)
            }
            .offset(x: cut.minX, y: cut.minY)
        }
        .allowsHitTesting(false)
    }
}

/// The tour's own voice, kept apart from the app's navy headings so a line
/// reads as something said to the person; the rings on targets share it.
enum TourInk {
    static let guide = adaptive(0x0A8FB3, dark: 0x5CCDE8)

    private static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(anchorHex: dark)) : UIColor(Color(anchorHex: light)) })
    }
}

/// A new line arrives two characters at a time, each rising out of a soft
/// blur into place, rather than being printed on the page.
private struct TourRisingLine: View {
    let text: String
    let reduceMotion: Bool
    var size: CGFloat = 22
    var centered = false
    @Environment(\.launchSplashShowing) private var covered
    @State private var elapsed: Double = 0

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(TourInk.guide)
            .multilineTextAlignment(centered ? .center : .leading)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .textRenderer(TourRise(elapsed: reduceMotion ? TourRise.settled : elapsed))
            .opacity(reduceMotion && elapsed == 0 ? 0 : 1)
            // The first line waits for the launch splash, so its arrival is seen.
            .task(id: covered) {
                guard !covered, elapsed == 0 else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .linear(duration: TourRise.settled)) {
                    elapsed = TourRise.settled
                }
            }
    }
}

/// Draws each pair of glyphs rising 8 pt out of a 5 pt blur over half a
/// second, the pairs starting one after another; a long line keeps the
/// whole arrival under a second and a half.
private struct TourRise: TextRenderer, Animatable {
    var elapsed: Double

    static let rise = 0.5
    static let spread = 0.9
    static let settled = rise + spread

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let pairs = max(1, layout.flatMap { $0 }.reduce(0) { $0 + $1.count } / 2)
        let step = min(0.055, Self.spread / Double(pairs))
        var index = 0
        for line in layout {
            for run in line {
                for glyph in run {
                    let t = min(1, max(0, (elapsed - Double(index / 2) * step) / Self.rise))
                    // A strong ease-out: quick to start, soft to land.
                    let p = 1 - pow(1 - t, 4)
                    var copy = context
                    copy.opacity = p
                    if p < 1 {
                        copy.translateBy(x: 0, y: (1 - p) * 8)
                        copy.addFilter(.blur(radius: (1 - p) * 5))
                    }
                    copy.draw(glyph)
                    index += 1
                }
            }
        }
    }
}

/// The hint on something to tap: a ring around it, and rings spreading from
/// it like water around a dropped anchor. A tap anywhere else sends the ring
/// out once more at once.
struct TourHalo: View {
    let radius: CGFloat
    var nudges = 0

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion {
                ring(delay: 0)
                ring(delay: 1.2)
            }
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(TourInk.guide, lineWidth: 2)
                .shadow(color: TourInk.guide.opacity(0.35), radius: 8)
        }
        .keyframeAnimator(initialValue: 1.0, trigger: nudges) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.06, duration: 0.18)
            SpringKeyframe(1.0, duration: 0.4)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ring(delay: Double) -> some View {
        TimelineView(.animation) { context in
            let phase = (context.date.timeIntervalSinceReferenceDate + delay).truncatingRemainder(dividingBy: 2.4) / 2.4
            RoundedRectangle(cornerRadius: radius + 16 * phase, style: .continuous)
                .stroke(TourInk.guide.opacity(0.5 * (1 - phase)), lineWidth: 2)
                .padding(-16 * phase)
        }
    }
}

/// The hint on something to drag: a hollow ring on the part to hold, which
/// rests, glides the way it goes, fades, and starts again.
struct TourGrip: View {
    var size: CGFloat = 46
    /// Where the ring is, from its rest, as it glides from 0 to 1.
    let glide: (Double) -> CGSize

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0.3 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.8)
            let p = min(1, max(0, (t - 0.7) / 1.3))
            let eased = p * p * (3 - 2 * p)
            let fade = t < 0.3 ? t / 0.3 : max(0, 1 - max(0, t - 2.2) / 0.4)
            Circle()
                .fill(Color.white.opacity(0.35))
                .overlay { Circle().strokeBorder(TourInk.guide, lineWidth: 2.5) }
                .frame(width: size, height: size)
                .shadow(color: TourInk.guide.opacity(0.3), radius: 6)
                .offset(glide(eased))
                .opacity(fade)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Keeps taps for the part the tour is on, or for nothing; a tap anywhere
/// else only nudges the hint.
struct TourBlocker: View {
    var hole: CGRect?
    var radius: CGFloat = 0
    /// A second way through, for Skip where it sits under the blocker.
    var opening: CGRect?
    let onMiss: () -> Void

    var body: some View {
        let veil = SpotlightVeil(hole: hole ?? .zero, radius: radius)
        let held = TourBlockerShape(veil: veil, opening: opening)
        held.fill(Color.clear)
            .contentShape(held, eoFill: true)
            .onTapGesture(perform: onMiss)
            .accessibilityHidden(true)
    }
}

/// The veil with the opening cut out as well; drawn even-odd.
private struct TourBlockerShape: Shape {
    let veil: SpotlightVeil
    let opening: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = veil.path(in: rect)
        if let opening, !opening.isEmpty { path.addRect(opening) }
        return path
    }
}

/// Leaves the tour for the person's own Anchor, from wherever they are.
struct TourSkip: View {
    let tour: AnchorTour
    /// The sharp copy drawn over the frost, above the one in the top bar.
    var overFrost = false

    var body: some View {
        Button(TourCopy.skip) { tour.skip() }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AnchorIOSStyle.secondaryText)
            .buttonStyle(.glass)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier(overFrost ? "tour.skip.frost" : "tour.skip")
            .accessibilityHidden(overFrost)
    }
}

// MARK: The home

/// The tour's layer over the real portrait home. First the home is left
/// whole for a moment; then one pane of frost lies over it from step to
/// step, clear only where the step is: today's anchoring as its day counts
/// up, the sample cards as they float up under a line on what the library holds,
/// then the anchor button by itself, with the line
/// asking for a tap in the middle of the glass. After the first drop the
/// new card is left clear under its line, then under a small Mac where the
/// person opens an agent; for the turn the whole home frosts over; at the
/// very end, the closing line and Start.
struct TourCoach: View {
    let tour: AnchorTour
    let spots: [TourSpot: CGRect]
    /// The whole screen, safe areas included, which `spots` are measured in.
    let size: CGSize
    /// The turn is offered: the prompt arrives once the anchor catches.
    let inviting: Bool
    let gravity: DeviceGravityMonitor
    let onSideways: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var nudges = 0
    /// The first anchor has met the water; the frost comes in around its card.
    @State private var dropLanded = false

    @Environment(\.launchSplashShowing) private var covered

    /// The cards float in under the clear patch before it moves on.
    static let helloLength: TimeInterval = 4.2

    var body: some View {
        ZStack(alignment: .topLeading) {
            if frosted {
                TourFrost(hole: frostHole?.rect, radius: frostHole?.radius ?? 0, nudges: nudges)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }
            switch tour.stage {
            case .glance, .clock, .hello, .anchorButton:
                home
                    .transition(.opacity)
            case .anchored:
                if let button = spots[.anchorButton] {
                    TourFirstDrop(origin: CGPoint(x: button.midX, y: button.midY), size: size,
                                  card: ownCard?.rect, onLanded: { dropLanded = true })
                    .transition(.opacity)
                }
            case .agent:
                TourAgentStart(tour: tour, size: size, card: tour.ownTask.flatMap { spots[.homeTask($0)] },
                               skip: spots[.skip]) { nudges += 1 }
                    .transition(.opacity)
            case .ending:
                TourEnding(tour: tour)
                    .transition(.opacity)
            case .turn:
                if inviting {
                    TourTurnPrompt(gravity: gravity, onSideways: onSideways)
                        .frame(width: size.width, height: size.height)
                        .transition(.opacity)
                }
            default:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.08), value: tour.stage)
        .animation(AnchorMotion.panel, value: inviting)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.6), value: frosted)
        // The home is seen whole once the launch splash has gone; then
        // today's anchoring, then the cards, each for its beat.
        .task(id: TourBeat(stage: tour.stage, covered: covered)) {
            guard !covered else { return }
            let (length, next): (TimeInterval, () -> Void) = switch tour.stage {
            case .glance: (AnchorTour.glanceLength, tour.glanced)
            case .clock: (AnchorTour.clockLength, tour.sawClock)
            case .hello: (Self.helloLength, tour.greeted)
            default: (0, {})
            }
            guard length > 0 else { return }
            try? await Task.sleep(for: .seconds(length))
            guard !Task.isCancelled else { return }
            next()
        }
        .onChange(of: tour.stage) { dropLanded = false }
    }

    private var isButton: Bool { tour.stage == .anchorButton }

    /// One timed step of the home's hello.
    private struct TourBeat: Hashable {
        let stage: AnchorTour.Stage
        let covered: Bool
    }

    /// The frost is up on the home's own steps; the setup sheet, the desk and
    /// the dial bring their own.
    private var frosted: Bool {
        switch tour.stage {
        case .clock, .hello, .anchorButton, .agent, .turn, .ending: true
        case .anchored: dropLanded
        default: false
        }
    }

    private var frostHole: (rect: CGRect, radius: CGFloat)? {
        switch tour.stage {
        case .clock: spots[.clock].map { ($0.insetBy(dx: -14, dy: -8), 28) }
        case .hello: spots[.tasks].map { ($0.insetBy(dx: -6, dy: -6), 24) }
        case .anchorButton: button
        case .anchored, .agent: ownCard
        default: nil
        }
    }

    private var button: (rect: CGRect, radius: CGFloat)? {
        spots[.anchorButton].map { ($0.insetBy(dx: -8, dy: -8), ($0.width + 16) / 2) }
    }

    /// The card the first anchor brought into the list.
    private var ownCard: (rect: CGRect, radius: CGFloat)? {
        tour.ownTask.flatMap { spots[.homeTask($0)] }.map { ($0.insetBy(dx: -6, dy: -6), HomeTaskCard.radius + 6) }
    }

    /// Only the anchor button and Skip answer; a tap anywhere else brightens
    /// the light round the clear patch.
    private var home: some View {
        ZStack(alignment: .topLeading) {
            TourBlocker(hole: button?.rect, radius: button?.radius ?? 0, opening: spots[.skip]) { nudges += 1 }
            // Skip stays sharp over the frost, where it sits in the top bar;
            // VoiceOver keeps the one in the bar.
            if let skip = spots[.skip] {
                TourSkip(tour: tour, overFrost: true)
                    .frame(width: skip.width, height: skip.height)
                    .offset(x: skip.minX, y: skip.minY)
            }
            if isButton {
                caption
                    .transition(.opacity)
            }
            if tour.stage == .clock, let clock = spots[.clock] {
                spotLine(TourCopy.clock, y: clock.maxY + 70)
            }
            if tour.stage == .hello, let library = spots[.tasks] {
                spotLine(TourCopy.library, y: library.minY - 62)
            }
        }
    }

    /// A line beside the clear part, on the frost.
    private func spotLine(_ text: String, y: CGFloat) -> some View {
        TourCaption(text: text, centered: true)
            .frame(maxWidth: 340)
            .padding(.horizontal, 24)
            .frame(width: size.width)
            .position(x: size.width / 2, y: y)
            .transition(.opacity)
    }

    /// In the middle of the frost, over the dome: only the tap is asked for.
    private var caption: some View {
        TourCaption(text: TourCopy.anchorButton, centered: true)
            .frame(maxWidth: 340)
            .padding(.horizontal, 24)
            .frame(width: size.width)
            .position(x: size.width / 2, y: size.height * 0.42)
    }
}

// MARK: The first drop

/// The person's first anchor going down, made a moment of. The real drop
/// plays on the home as always; where it meets the water, rings run out
/// across the whole sea and the phone thumps; then the frost comes in over
/// everything but the new card, and the line rises above it.
struct TourFirstDrop: View {
    /// The anchor button's middle, where the anchor meets the water.
    let origin: CGPoint
    let size: CGSize
    /// The new card in the list, which the frost leaves clear.
    let card: CGRect?
    let onLanded: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var start = Date.now
    @State private var landed = 0
    @State private var caught = 0
    @State private var said = false

    /// The sheet's way down, then the anchor's fall.
    private static let contact = Double(AnchorDrop.lead.components.attoseconds) / 1e18
        + Double(AnchorDrop.lead.components.seconds) + AnchorDrop.contact

    var body: some View {
        ZStack(alignment: .topLeading) {
            TimelineView(.animation(paused: reduceMotion)) { context in
                rings(after: reduceMotion ? 2 : context.date.timeIntervalSince(start) - Self.contact)
            }
            .allowsHitTesting(false)
            words
                .frame(width: size.width)
                .position(x: size.width / 2, y: card.map { $0.minY - 120 } ?? size.height * 0.42)
                .opacity(said ? 1 : 0)
                .offset(y: said || reduceMotion ? 0 : 12)
                .blur(radius: said || reduceMotion ? 0 : 6)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.7, bounce: 0.15), value: said)
        }
        .frame(width: size.width, height: size.height)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: landed)
        .sensoryFeedback(.success, trigger: caught)
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(Self.contact))
            guard !Task.isCancelled else { return }
            AnchorSound.shared.play(.anchored)
            landed += 1
            try? await Task.sleep(for: .seconds(0.35))
            onLanded()
            try? await Task.sleep(for: .seconds(0.35))
            said = true
            try? await Task.sleep(for: .seconds(0.25))
            caught += 1
        }
        .accessibilityElement(children: .combine)
    }

    /// Rings across the sea from the anchor, flattened as seen from above,
    /// running past the edges, and a flash of shallow water where it went in.
    private func rings(after: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                let p = min(1, max(0, (after - Double(index) * 0.18) / 1.7))
                let eased = 1 - pow(1 - p, 3)
                Ellipse()
                    .stroke(AnchorIOSStyle.action.opacity(after < 0 || p >= 1 ? 0 : 0.45 * (1 - p)), lineWidth: 3 - 2 * p)
                    .frame(width: 70 + size.width * 2.4 * eased, height: 22 + size.width * 0.75 * eased)
                    .position(origin)
            }
            Circle()
                .fill(AnchorIOSStyle.cyan.opacity(after < 0 ? 0 : 0.25 * max(0, 1 - after / 0.6)))
                .frame(width: 90 + 260 * min(1, max(0, after) / 0.6), height: 90 + 260 * min(1, max(0, after) / 0.6))
                .position(origin)
        }
    }

    /// The new card under it says which task it was.
    private var words: some View {
        Text(TourCopy.firstAnchor)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(AnchorIOSStyle.heading)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
}

// MARK: The ending

/// The sample tasks have weighed anchor and the home frosts over. One line
/// on what Anchor is for, rising in the middle of the glass, and Start,
/// which hands over to their own Anchor and its connection card.
struct TourEnding: View {
    let tour: AnchorTour

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var shown = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Text(TourCopy.ending)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .appear(shown, after: 0.3, reduceMotion: reduceMotion)
            Spacer(minLength: 0)
            Button { tour.start() } label: {
                Text(TourCopy.start)
                    .font(.headline)
                    // The night tint is pale; dark ink keeps the label readable on it.
                    .foregroundStyle(colorScheme == .dark ? AnchorPalette.deepSea : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
            .tint(AnchorIOSStyle.action)
            .appear(shown, after: 1.1, reduceMotion: reduceMotion)
            .accessibilityIdentifier("tour.start")
        }
        .frame(maxWidth: 440)
        .padding(.horizontal, 24)
        .padding(.top, 120)
        .padding(.bottom, 54)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .task { shown = true }
    }
}

private extension View {
    /// Rises into place a beat after the line before it.
    func appear(_ shown: Bool, after delay: Double, reduceMotion: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .animation((reduceMotion ? Animation.easeOut(duration: 0.3) : .spring(duration: 0.8, bounce: 0.1)).delay(delay), value: shown)
    }
}

/// The cut's outline alone, in the pane's space, moving with the cut.
private struct TourCutOutline: Shape {
    var rect: CGRect
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(AnimatablePair(rect.width, rect.height), radius)) }
        set {
            rect = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first.first, height: newValue.second.first.second)
            radius = newValue.second.second
        }
    }

    func path(in _: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
    }
}

/// The whole screen with a rounded hole, filled even-odd. The hole moves
/// smoothly from one part of the screen to the next.
struct SpotlightVeil: Shape {
    var hole: CGRect
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>> {
        get { AnimatablePair(AnimatablePair(hole.minX, hole.minY), AnimatablePair(AnimatablePair(hole.width, hole.height), radius)) }
        set {
            hole = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first.first, height: newValue.second.first.second)
            radius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -200, dy: -200))
        guard !hole.isEmpty else { return path }
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

// MARK: Turning

/// After the drop the home frosts over: in the middle of the glass a phone
/// outline turns on its side over the line. If the screen cannot turn, a
/// quiet line under it asks about the lock and offers the desk here instead.
struct TourTurnPrompt: View {
    let gravity: DeviceGravityMonitor
    let onSideways: () -> Void

    @State private var waited = false

    var body: some View {
        VStack(spacing: 22) {
            TourPhoneTurn()
                .frame(width: 140, height: 140)
            TourCaption(text: TourCopy.turn, centered: true)
                .frame(maxWidth: 340)
            if showsLock { lock }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AnchorMotion.panel, value: showsLock)
        .task {
            try? await Task.sleep(for: .seconds(6))
            waited = true
        }
    }

    private var showsLock: Bool { waited || gravity.suggestsOrientationLock }

    private var lock: some View {
        VStack(spacing: 12) {
            Label(gravity.suggestsOrientationLock ? L10n.workInvitationLock : TourCopy.lockQuestion,
                  systemImage: "lock.rotation")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(TourCopy.openHere, action: onSideways)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glass)
                .tint(AnchorIOSStyle.action)
                .accessibilityIdentifier("tour.sideways")
        }
        .padding(.top, 18)
        .transition(.opacity.combined(with: .offset(y: 6)))
    }
}

/// A rounded phone outline that tips onto its left side, rests, and starts
/// again, over a dashed wake showing the way it turns. On the desk it turns
/// the other way, from its side back upright.
private struct TourPhoneTurn: View {
    var upright = false
    @AnchorReducedMotion private var reduceMotion

    private var from: Double { upright ? -90 : 0 }
    private var to: Double { upright ? 0 : -90 }

    /// One leg of the phone's tip-over animation.
    private struct Turn {
        var angle = 0.0
        var opacity = 0.0
    }

    var body: some View {
        ZStack {
            wake
            if reduceMotion {
                phone.rotationEffect(.degrees(to))
            } else {
                KeyframeAnimator(initialValue: Turn(angle: from), repeating: true) { turn in
                    phone
                        .rotationEffect(.degrees(turn.angle))
                        .opacity(turn.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.angle) {
                        LinearKeyframe(from, duration: 0.7)
                        CubicKeyframe(to, duration: 0.9)
                        LinearKeyframe(to, duration: 1.25)
                        LinearKeyframe(from, duration: 0.01)
                        LinearKeyframe(from, duration: 0.34)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1, duration: 0.3)
                        LinearKeyframe(1, duration: 2.1)
                        LinearKeyframe(0, duration: 0.4)
                        LinearKeyframe(0, duration: 0.4)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var phone: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(AnchorIOSStyle.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(AnchorIOSStyle.action, lineWidth: 3)
            }
            .overlay(alignment: .top) {
                Capsule().fill(AnchorIOSStyle.action.opacity(0.35)).frame(width: 18, height: 4).padding(.top, 7)
            }
            .frame(width: 62, height: 108)
            .shadow(color: AnchorIOSStyle.action.opacity(0.25), radius: 14, y: 6)
    }

    private var wake: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            // The phase stays within one dash (3 + 7): the renderer walks the
            // pattern from zero, so the raw clock (billions) stalled every frame.
            let phase = -(context.date.timeIntervalSinceReferenceDate * 14).truncatingRemainder(dividingBy: 10)
            Circle()
                .trim(from: 0.55, to: 0.8)
                .stroke(AnchorIOSStyle.action.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7],
                                           dashPhase: reduceMotion ? 0 : phase))
                .frame(width: 140, height: 140)
        }
    }
}

// MARK: The desk under the lock

/// The real desk, drawn sideways for a phone whose screen will not turn.
/// Turning the phone upright again, or the button, goes back.
struct TourSidewaysDesk: View {
    let tour: AnchorTour
    let projection: SessionProjection
    let gravity: DeviceGravityMonitor
    let onTask: (UUID) -> Void
    let onBack: () -> Void

    @State private var wasSideways = false

    var body: some View {
        GeometryReader { geometry in
            LandscapeAmbientDashboard(projection: projection, playsArrival: true, onTask: onTask, onManage: {})
                .tourDeskCoach(tour)
                // In the empty edge past the last folder, away from the island.
                .overlay(alignment: .bottomTrailing) {
                    Button(action: onBack) {
                        Image(systemName: "rectangle.portrait.rotate")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(AnchorIOSStyle.action)
                    .padding(.trailing, 6)
                    .padding(.bottom, 14)
                    .accessibilityLabel(TourCopy.backUpright)
                    .accessibilityIdentifier("tour.sideways.back")
                }
                .frame(width: geometry.size.height, height: geometry.size.width)
                .rotationEffect(.degrees(90))
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .onChange(of: gravity.angle) { _, angle in
            if abs(angle) > 1.2 { wasSideways = true } else if wasSideways, abs(angle) < 0.4 { onBack() }
        }
    }
}

// MARK: The desk

extension View {
    /// The tour's light over the desk, wherever the desk is drawn.
    @ViewBuilder
    func tourDeskCoach(_ tour: AnchorTour?) -> some View {
        if let tour {
            overlayPreferenceValue(TourSpotKey.self) { anchors in
                GeometryReader { proxy in
                    TourDeskCoach(tour: tour, spots: anchors.mapValues { proxy[$0] }, size: proxy.size)
                }
                .ignoresSafeArea()
            }
        } else {
            self
        }
    }
}

/// The tour on the real desk, under one pane of frost. The clear patch
/// passes over each folder while the line says what they are, then rests on
/// the folder of the task the person just dropped, where an agent has
/// started; then on the pet's nook until the pet is greeted. Then the
/// thesis's question arrives, its anchor dropping onto the card, and the
/// patch settles on that card, the one part that answers a tap; opened, the
/// recall card is the clear part. It is swiped down, then opened again and
/// swiped up, when a small Mac in the frost beside it catches the card and
/// opens the conversation. Last the whole desk frosts over while a friend
/// calls the person away. The line sits in the column left of the folders,
/// at its foot, over the frosted clock and pet room (at its head while the
/// pet is the clear part).
private struct TourDeskCoach: View {
    let tour: AnchorTour
    let spots: [TourSpot: CGRect]
    let size: CGSize

    @AnchorReducedMotion private var reduceMotion
    /// The folder the ring is on; past the last it rests on the person's own.
    @State private var lit = 0
    @State private var nudges = 0
    /// Where the open card last was, for its flight to the Mac once it has gone.
    @State private var lastCard: CGRect?
    @State private var sentAt: Date?
    @State private var greetings = 0

    /// The desk's clear patch.
    private struct Hole: Equatable {
        let rect: CGRect
        let radius: CGFloat
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if frosted {
                TourFrost(hole: hole?.rect, radius: hole?.radius ?? 0, nudges: nudges)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }
            if showsMac {
                TourMacCatch(card: tour.stage == .sending ? lastCard : nil, sentAt: sentAt,
                             reaching: tour.stage == .reading ? spots[.recallCard] : nil, tint: questionInk)
                    .frame(width: size.width, height: size.height)
                    .environment(\.tourMacPlace, macPlace)
                    .transition(.opacity)
            }
            switch tour.stage {
            case .desk, .waiting, .again:
                TourBlocker(hole: tour.stage == .desk ? nil : hole?.rect, radius: hole?.radius ?? 0) { nudges += 1 }
                column {
                    TourCaption(text: line)
                }
            case .pet:
                TourBlocker(hole: hole?.rect, radius: hole?.radius ?? 0) { nudges += 1 }
                if let hole {
                    // Anywhere in the clear part greets the pet, and it answers at once:
                    // square corners and a little past the edge, so a near miss still counts.
                    let zone = hole.rect.insetBy(dx: -10, dy: -10)
                    Color.clear
                        .frame(width: zone.width, height: zone.height)
                        .contentShape(.rect)
                        .gesture(DragGesture(minimumDistance: 0).onEnded { _ in greetPet() })
                        .offset(x: zone.minX, y: zone.minY)
                        .accessibilityHidden(true)
                }
                column(atTop: true) {
                    TourCaption(text: TourCopy.pet)
                }
            case .reading:
                // The open card keeps its own swipes; a tap beside it closes it too.
                if let card = spots[.recallCard] {
                    Group {
                        if tour.asks == .up {
                            TourGrip { CGSize(width: 0, height: -90 * $0) }
                                .position(x: card.midX, y: card.maxY - 40)
                        } else {
                            TourGrip { CGSize(width: 0, height: 90 * $0) }
                                .position(x: card.midX, y: card.minY + 34)
                        }
                    }
                    .id(tour.asks)
                    .transition(.opacity)
                }
                column {
                    TourCaption(text: tour.asks == .up ? TourCopy.recallUp : TourCopy.recall)
                }
            case .sending:
                TourBlocker {}
                column {
                    TourCaption(text: TourCopy.sent)
                }
            case .called:
                TourBlocker {}
                VStack(spacing: 16) {
                    TourPhoneTurn(upright: true)
                        .frame(width: 140, height: 140)
                        .scaleEffect(0.8)
                        .frame(width: 112, height: 112)
                    TourCaption(text: TourCopy.called, centered: true)
                        .frame(maxWidth: 420)
                }
                .padding(.horizontal, 60)
                .frame(width: size.width, height: size.height)
                .transition(.opacity)
                column {}
            default:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: greetings)
        .animation(AnchorMotion.panel, value: tour.stage)
        .animation(AnchorMotion.panel, value: showsMac)
        .onChange(of: spots[.recallCard]) { _, card in
            if let card { lastCard = card }
        }
        .onChange(of: tour.stage) { _, stage in
            sentAt = stage == .sending ? .now : nil
        }
        .task(id: tour.stage) {
            guard tour.stage == .desk else { return }
            guard !reduceMotion else {
                lit = DeskTaskLibrary.Metrics.slots
                return
            }
            lit = 0
            for step in 1...DeskTaskLibrary.Metrics.slots {
                try? await Task.sleep(for: .seconds(0.85))
                guard !Task.isCancelled else { return }
                lit = step
            }
        }
    }

    private func greetPet() {
        greetings += 1
        DeskPetLife.shared.tap()
        tour.pettedPet()
    }

    private var folders: [CGRect] {
        (0..<DeskTaskLibrary.Metrics.slots).compactMap { spots[.folder($0)] }
    }

    /// The desk's own steps; the dial's page has nothing behind it to frost.
    private var frosted: Bool { tour.stage >= .desk && tour.stage <= .called }

    /// The small Mac stands in the frost while the up swipe is asked for, and
    /// while it catches the card.
    private var showsMac: Bool {
        switch tour.stage {
        case .reading, .again: tour.asks == .up
        case .sending: true
        default: false
        }
    }

    /// The waiting task's own color, for its card and question on the Mac.
    private var questionInk: Color {
        tour.model.projection.hostedSessions.first { $0.id == tour.waitingTaskID }
            .map { DeskFolderPalette($0).ink } ?? AnchorIOSStyle.action
    }

    /// The Mac's place: the head of the left column, over the frosted clock.
    private var macPlace: CGPoint {
        let right = (folders.first?.minX ?? size.width * 0.36) - 12
        return CGPoint(x: (50 + right) / 2, y: max(84, size.height * 0.3))
    }

    private var hole: Hole? {
        switch tour.stage {
        case .desk:
            guard let first = folders.first else { return nil }
            if lit < folders.count { return Hole(rect: folders[lit].insetBy(dx: -6, dy: -6), radius: 21) }
            if let own = tour.ownTask.flatMap({ spots[.taskFolder($0)] }) {
                return Hole(rect: own.insetBy(dx: -6, dy: -6), radius: 21)
            }
            let all = folders.dropFirst().reduce(first) { $0.union($1) }
            return Hole(rect: all.insetBy(dx: -8, dy: -8), radius: 23)
        case .pet:
            return spots[.pet].map { Hole(rect: $0.insetBy(dx: -6, dy: -6), radius: 16) }
        case .waiting, .again:
            guard let card = spots[.frontCard(tour.waitingTaskID)] else { return nil }
            return Hole(rect: card.insetBy(dx: -6, dy: -6), radius: 21)
        case .reading:
            return spots[.recallCard].map { Hole(rect: $0.insetBy(dx: -4, dy: -4), radius: 28) }
        default:
            return nil
        }
    }

    /// What the folders are while the ring walks them; the person's own task
    /// once it rests; the question once it arrives.
    private var line: String {
        if tour.stage == .waiting { return TourCopy.waiting }
        if tour.stage == .again { return tour.asks == .up ? TourCopy.againUp : TourCopy.againDown }
        return lit < DeskTaskLibrary.Metrics.slots ? TourCopy.folders : TourCopy.ownTask
    }

    /// The column left of the folders, clear of the Dynamic Island's edge:
    /// the line at its foot, over the frosted pet room, Skip under it.
    private func column(atTop: Bool = false, @ViewBuilder _ content: () -> some View) -> some View {
        let edge: CGFloat = 50
        let right = (folders.first?.minX ?? size.width * 0.36) - 12
        return VStack(alignment: .leading, spacing: 8) {
            if !atTop { Spacer(minLength: 0) }
            content()
                .padding(.leading, edge)
            TourSkip(tour: tour)
                .padding(.leading, edge)
            if atTop { Spacer(minLength: 0) }
        }
        .padding(.top, atTop ? 28 : 0)
        .padding(.bottom, 12)
        .frame(width: max(200, right), height: size.height, alignment: .leading)
    }
}

extension EnvironmentValues {
    /// Where the desk's small Mac stands, in the desk coach's space.
    @Entry var tourMacPlace: CGPoint = .zero
}

/// The Mac beside the phone, drawn small in the frost at the head of the
/// left column. While the up swipe is asked for, a dotted line runs from the
/// open card up and over to it. Sent, the card flies up into its screen
/// and the conversation's window opens there, its question still lit.
private struct TourMacCatch: View {
    /// The card in flight, from where it last was; none while it waits.
    let card: CGRect?
    let sentAt: Date?
    /// The open card the dotted line runs from.
    let reaching: CGRect?
    /// The waiting task's color.
    let tint: Color

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.tourMacPlace) private var place

    private static let screen = CGSize(width: 132, height: 86)
    /// The card's flight, then the window opening on the screen.
    private static let flight = 0.55
    private static let opening = 0.45

    var body: some View {
        TimelineView(.animation(paused: reduceMotion && sentAt == nil)) { context in
            let now = context.date
            let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600)
            let since = sentAt.map { now.timeIntervalSince($0) } ?? -1
            let screen = CGRect(x: place.x - Self.screen.width / 2, y: place.y - Self.screen.height / 2,
                                width: Self.screen.width, height: Self.screen.height)
            ZStack(alignment: .topLeading) {
                if let reaching {
                    reach(from: reaching, to: screen, at: t)
                }
                laptop(screen: screen, window: reduceMotion && since >= 0 ? 1 : min(1, max(0, (since - Self.flight) / Self.opening)), at: t)
                if let card, since >= 0, since < Self.flight + 0.15 {
                    flying(card: card, into: screen, p: reduceMotion ? 1 : min(1, since / Self.flight))
                }
            }
            // Everything here is placed in the coach's space, from its top left.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A dotted line arching through the frost from the open card's edge to
    /// the Mac, its dots running toward the Mac; it never crosses the card.
    private func reach(from card: CGRect, to screen: CGRect, at t: TimeInterval) -> some View {
        let start = CGPoint(x: card.minX - 8, y: card.minY + 46)
        let end = CGPoint(x: screen.maxX + 10, y: screen.midY - 6)
        return Path { path in
            path.move(to: start)
            path.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2, y: max(6, min(start.y, end.y) - 34)))
        }
        .stroke(TourInk.guide.opacity(0.7),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7],
                                   // Within one dash (1 + 7), as the turn prompt's wake.
                                   dashPhase: reduceMotion ? 0 : (t * 16).truncatingRemainder(dividingBy: 8)))
    }

    private func laptop(screen: CGRect, window: Double, at t: TimeInterval) -> some View {
        let tint = AnchorIOSStyle.action
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AnchorIOSStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(tint, lineWidth: 2.5)
                }
                .overlay { self.window(window, at: t).padding(9) }
                .frame(width: screen.width, height: screen.height)
                .offset(x: screen.minX, y: screen.minY)
            Capsule()
                .fill(tint.opacity(0.85))
                .frame(width: screen.width + 26, height: 7)
                .offset(x: screen.minX - 13, y: screen.maxY + 3)
        }
        .shadow(color: tint.opacity(0.22), radius: 14, y: 6)
    }

    /// The conversation's window, growing out of the middle of the screen:
    /// a title bar, the lines of the exchange, and the question, breathing.
    private func window(_ p: Double, at t: TimeInterval) -> some View {
        let eased = 1 - pow(1 - p, 3)
        let breath = reduceMotion ? 1 : 0.6 + 0.4 * sin(t * 4)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(AnchorIOSStyle.secondaryText.opacity(0.35)).frame(width: 4, height: 4)
                }
            }
            ForEach(0..<2, id: \.self) { index in
                Capsule().fill(AnchorIOSStyle.secondaryText.opacity(0.22))
                    .frame(width: index == 0 ? 70 : 52, height: 4)
                    .opacity(min(1, max(0, (p - 0.3 - 0.15 * Double(index)) / 0.3)))
            }
            Capsule().fill(tint.opacity(0.75 * breath))
                .frame(width: 84, height: 6)
                .opacity(min(1, max(0, (p - 0.65) / 0.35)))
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AnchorIOSStyle.canvasTop, in: .rect(cornerRadius: 5, style: .continuous))
        .scaleEffect(0.3 + 0.7 * eased)
        .opacity(p > 0 ? 1 : 0)
    }

    /// The card, already small from its swipe, arcing up into the screen.
    private func flying(card: CGRect, into screen: CGRect, p: Double) -> some View {
        let eased = p * p * (3 - 2 * p)
        let from = CGPoint(x: card.midX, y: card.minY + card.height * 0.2)
        let to = CGPoint(x: screen.midX, y: screen.midY)
        let lift = -60 * sin(eased * .pi)
        let width = (card.width * 0.4) * (1 - eased) + screen.width * 0.5 * eased
        let height = width * 0.62
        return RoundedRectangle(cornerRadius: 12 - 6 * eased, style: .continuous)
            .fill(DeskStyle.card)
            .overlay {
                RoundedRectangle(cornerRadius: 12 - 6 * eased, style: .continuous)
                    .strokeBorder(tint.opacity(0.7), lineWidth: 1.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .frame(width: width, height: height)
            .position(x: from.x + (to.x - from.x) * eased, y: from.y + (to.y - from.y) * eased + lift)
            .opacity(p >= 1 ? 0 : 1)
    }
}

/// The anchor on a card that waits for the person, while the tour points at
/// it: it drops onto the card with a swing, then calls now and then with a
/// ring, as a dropped anchor sends rings across the water.
struct TourAnchorCall: ViewModifier {
    let calling: Bool
    let tint: Color

    @AnchorReducedMotion private var reduceMotion
    @State private var drops = 0

    /// Timing of the anchor's swing onto a waiting card.
    private struct Drop {
        var y: CGFloat = 0
        var scale: CGFloat = 1
        var swing: Double = 0
    }

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: Drop(), trigger: drops) { content, drop in
                content
                    .rotationEffect(.degrees(drop.swing), anchor: .top)
                    .scaleEffect(drop.scale)
                    .offset(y: drop.y)
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    MoveKeyframe(-16)
                    CubicKeyframe(0, duration: 0.32)
                    SpringKeyframe(0, duration: 0.4)
                }
                KeyframeTrack(\.scale) {
                    MoveKeyframe(1.9)
                    CubicKeyframe(1.25, duration: 0.32)
                    SpringKeyframe(1.25, duration: 0.6, spring: .bouncy)
                }
                KeyframeTrack(\.swing) {
                    MoveKeyframe(0)
                    LinearKeyframe(0, duration: 0.3)
                    CubicKeyframe(-16, duration: 0.18)
                    CubicKeyframe(10, duration: 0.24)
                    CubicKeyframe(-4, duration: 0.2)
                    CubicKeyframe(0, duration: 0.2)
                }
            }
            .background {
                if calling, !reduceMotion {
                    TimelineView(.animation) { context in
                        let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                        Circle()
                            .stroke(tint.opacity(0.55 * (1 - phase)), lineWidth: 1.5)
                            .scaleEffect(1 + 1.4 * phase)
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: calling, initial: true) { _, calling in
                if calling, !reduceMotion { drops += 1 }
            }
    }
}

// MARK: Away and back

/// The time away, in the person's hands: a dial they turn clockwise, a
/// minute a click under the finger. Past the first minute the Bluetooth link
/// to the Mac breaks; at five the phone counts as away; the agents' news
/// lands on the laptop as the minutes go by; at the end of the dial the phone
/// is back in range and the link joins again. First, if reminders were never
/// asked about, the system asks, with the line saying why.
struct TourAwayDial: View {
    let tour: AnchorTour

    @AnchorReducedMotion private var reduceMotion
    /// Where the dial is, in minutes; the tour hears whole minutes.
    @State private var minutes = 0.0
    @State private var lastAngle: Double?
    @State private var backAt: Date?
    /// When the line snapped, for its spark.
    @State private var breakAt: Date?
    /// Before the dial, the system asks about reminders, once ever.
    @State private var asksReminder = false
    /// The dial has been held; until then its knob shows the turn by itself.
    @State private var touched = false

    private static let diameter: CGFloat = 248
    private var total: Double { Double(AnchorTour.dialMinutes) }
    private var isBack: Bool { tour.stage == .back }

    var body: some View {
        VStack(spacing: 22) {
            TourCaption(text: line, centered: true)
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
            link
                .frame(height: 210, alignment: .top)
            dial
                // Room above for the marks just outside the ring.
                .padding(.top, 18)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // The light warms as the half hour passes, and cools again back at the desk.
            ZStack {
                AnchorIOSStyle.canvasTop
                Color(red: 1, green: 0.94, blue: 0.84).opacity(isBack ? 0 : 0.7 * minutes / total)
            }
            .ignoresSafeArea()
            .animation(AnchorMotion.panel, value: isBack)
        }
        .contentShape(.rect)
        .task {
            // Reminders matter from this moment on: away too long, Anchor calls the person back.
            let center = UNUserNotificationCenter.current()
            guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
            asksReminder = true
            try? await Task.sleep(for: .seconds(1.4))
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            asksReminder = false
        }
        .overlay(alignment: .topTrailing) {
            if !isBack {
                TourSkip(tour: tour).padding(.trailing, 12)
            }
        }
        .sensoryFeedback(.selection, trigger: tour.awayMinutes)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tour.awayMinutes >= AnchorTour.linkBreaksAt)
        .sensoryFeedback(.success, trigger: isBack)
        .onChange(of: tour.awayMinutes) { passed, now in
            if passed < AnchorTour.linkBreaksAt, now >= AnchorTour.linkBreaksAt {
                breakAt = .now
                AnchorSound.shared.play(.snap)
            } else if passed < AnchorTour.awayAt, now >= AnchorTour.awayAt {
                AnchorSound.shared.play(.away)
            }
        }
        .onChange(of: isBack) { _, back in
            guard back else { return }
            backAt = .now
            AnchorSound.shared.play(.rejoin)
        }
    }

    private var line: String {
        if isBack { return TourCopy.together }
        if asksReminder { return TourCopy.reminder }
        return tour.awayMinutes >= AnchorTour.awayAt ? TourCopy.apart : TourCopy.dial
    }

    // MARK: The scene

    /// Where things stand in the scene above the dial.
    private enum Scene {
        static let size = CGSize(width: 320, height: 210)
        static let mac = CGPoint(x: 62, y: 46)
        /// The phone's walk, from beside the laptop to the café table.
        static let start = CGPoint(x: 184, y: 52)
        static let bend = CGPoint(x: 262, y: 52)
        static let table = CGPoint(x: 244, y: 148)
        static let cup = CGPoint(x: 290, y: 156)
        static let notes = CGPoint(x: 8, y: 92)

        static func phone(_ walk: Double) -> CGPoint {
            let u = 1 - walk
            return CGPoint(x: u * u * start.x + 2 * u * walk * bend.x + walk * walk * table.x,
                           y: u * u * start.y + 2 * u * walk * bend.y + walk * walk * table.y)
        }
    }

    private static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }

    /// The laptop and the phone, and the line between them. As the dial
    /// turns, the phone walks off toward a café, its Bluetooth waves
    /// shrinking until the line snaps with a spark; a coffee steams at the
    /// end of the path; the laptop's agents keep filling their bars, and each
    /// thing they finish pops out of it onto the list. Back, the phone walks
    /// home, the line zips shut, and what landed flies into the phone.
    private var link: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let now = context.date
            // Periodic motion runs on a small clock, never the raw date.
            let t = now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 600)
            let home = backAt.map { min(1, now.timeIntervalSince($0) / 0.7) } ?? 0
            let collect = backAt.map { max(0, now.timeIntervalSince($0) - 0.7) } ?? 0
            let walk = min(1, minutes / Double(AnchorTour.awayAt)) * (1 - Self.ease(home))
            let phone = Scene.phone(walk)
            let joined = minutes < Double(AnchorTour.linkBreaksAt) || isBack
            let signal = isBack ? 1 : max(0, 1 - minutes / Double(AnchorTour.linkBreaksAt))
            ZStack(alignment: .topLeading) {
                walkway(walk).opacity(1 - home)
                cafe(at: t).opacity(walk > 0.7 ? 1 : 0).animation(AnchorMotion.panel, value: walk > 0.7)
                linkLine(from: CGPoint(x: Scene.mac.x + 46, y: Scene.mac.y), to: CGPoint(x: phone.x - 19, y: phone.y),
                         joined: joined, zip: isBack ? home : 1, strain: 1 - signal, at: now)
                spark(at: now)
                laptop(at: t).position(Scene.mac)
                waves(at: t, signal: signal).position(x: phone.x - 4, y: phone.y)
                phoneOutline.position(phone)
                notes(collect: collect, phone: phone)
                    .frame(width: 150, alignment: .topLeading)
                    .offset(x: Scene.notes.x, y: Scene.notes.y)
            }
            .frame(width: Scene.size.width, height: Scene.size.height, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }

    /// The dotted way to the café, laid only as far as the phone has walked.
    private func walkway(_ walk: Double) -> some View {
        Path { path in
            path.move(to: Scene.start)
            path.addQuadCurve(to: Scene.table, control: Scene.bend)
        }
        .trim(from: 0, to: walk)
        .stroke(AnchorIOSStyle.action.opacity(0.22), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))
    }

    /// A cup on the café table, steaming.
    private func cafe(at t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let rise = (t * 0.7 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 16))
                    path.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: 5, y: 11), control2: CGPoint(x: -5, y: 5))
                }
                .stroke(AnchorIOSStyle.action.opacity(reduceMotion ? 0.4 : 0.55 * (1 - rise)), lineWidth: 1.6)
                .frame(width: 1, height: 16)
                .offset(x: CGFloat(index) * 8 - 4, y: -20 - (reduceMotion ? 0 : 8 * rise))
            }
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.action)
        }
        .position(Scene.cup)
    }

    /// One line between the laptop and the phone. Close by it hangs slack;
    /// as the phone walks off it pulls taut and thin, then snaps, each half
    /// whipping back to its own end and gone. Coming back, it closes from the
    /// laptop to the phone like a zip.
    @ViewBuilder
    private func linkLine(from a: CGPoint, to b: CGPoint, joined: Bool, zip: Double, strain: Double, at now: Date) -> some View {
        let tint = AnchorIOSStyle.action
        if joined {
            let end = CGPoint(x: a.x + (b.x - a.x) * zip, y: a.y + (b.y - a.y) * zip)
            let sag = isBack ? 0 : 14 * (1 - strain)
            Path { path in
                path.move(to: a)
                path.addQuadCurve(to: end, control: CGPoint(x: (a.x + end.x) / 2, y: (a.y + end.y) / 2 + sag))
            }
            .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: isBack ? 3 : 2.6 - 1.2 * strain, lineCap: .round))
        } else if let breakAt, !reduceMotion, now.timeIntervalSince(breakAt) < 0.5 {
            let p = now.timeIntervalSince(breakAt) / 0.5
            let left = 0.5 * (1 - (1 - pow(1 - p, 3)))
            let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            Path { path in
                for (end, curl) in [(a, 1.0), (b, -1.0)] {
                    let tip = CGPoint(x: end.x + (middle.x - end.x) * left, y: end.y + (middle.y - end.y) * left)
                    path.move(to: end)
                    path.addQuadCurve(to: tip, control: CGPoint(x: (end.x + tip.x) / 2, y: (end.y + tip.y) / 2 + 10 * p * curl))
                }
            }
            .stroke(tint.opacity(0.75 * (1 - p)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// Where the line snapped, a burst of bits for a moment.
    private func spark(at now: Date) -> some View {
        let p = breakAt.map { now.timeIntervalSince($0) / 0.6 } ?? 1
        let origin = CGPoint(x: (Scene.mac.x + 46 + Scene.phone(0.2).x - 19) / 2,
                             y: (Scene.mac.y + Scene.phone(0.2).y) / 2)
        return ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi + 0.3
                Circle()
                    .fill(index.isMultiple(of: 2) ? AnchorIOSStyle.yellow : AnchorIOSStyle.action)
                    .frame(width: 4, height: 4)
                    .position(x: origin.x + cos(angle) * 26 * min(1, p), y: origin.y + sin(angle) * 26 * min(1, p))
                    .opacity(p < 1 && !reduceMotion ? 1 - p : 0)
            }
        }
    }

    /// A laptop whose screen shows its three agents' bars filling as the
    /// half hour passes, the front of each one shimmering while it works.
    private func laptop(at t: TimeInterval) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AnchorIOSStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(AnchorIOSStyle.action, lineWidth: 2.5)
                }
                .frame(width: 84, height: 56)
                .overlay {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            let fill = min(1, 0.18 + 0.1 * Double(index) + minutes / total * (0.85 - 0.12 * Double(index)))
                            let glow = reduceMotion ? 0.8 : 0.55 + 0.45 * sin((t * 3 + Double(index)).truncatingRemainder(dividingBy: 2 * .pi))
                            ZStack(alignment: .leading) {
                                Capsule().fill(AnchorIOSStyle.action.opacity(0.15))
                                Capsule().fill(AnchorIOSStyle.action.opacity(fill >= 1 ? 1 : glow))
                                    .frame(width: 56 * fill)
                            }
                            .frame(width: 56, height: 5)
                        }
                    }
                }
            Capsule()
                .fill(AnchorIOSStyle.action.opacity(0.85))
                .frame(width: 104, height: 6)
        }
        .shadow(color: AnchorIOSStyle.action.opacity(0.2), radius: 12, y: 6)
    }

    /// The phone's Bluetooth: arcs toward the laptop, fewer and fainter as
    /// it walks off, gone once the line breaks, back when it returns.
    private func waves(at t: TimeInterval, signal: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let radius = 24 + CGFloat(index) * 8
                let pulse = reduceMotion ? 1 : 0.6 + 0.4 * sin((t * 4 - Double(index)).truncatingRemainder(dividingBy: 2 * .pi))
                let shown = signal > Double(index) / 3
                Circle()
                    .trim(from: 0.43, to: 0.57)
                    .stroke(AnchorIOSStyle.action.opacity(shown ? (0.6 - 0.15 * Double(index)) * pulse : 0),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)
            }
        }
        .animation(AnchorMotion.micro, value: signal)
    }

    private var phoneOutline: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(AnchorIOSStyle.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(AnchorIOSStyle.action, lineWidth: 2.5)
            }
            .overlay(alignment: .top) {
                Capsule().fill(AnchorIOSStyle.action.opacity(0.35)).frame(width: 10, height: 3).padding(.top, 5)
            }
            .frame(width: 32, height: 56)
            .shadow(color: AnchorIOSStyle.action.opacity(0.2), radius: 10, y: 5)
    }

    /// Each conversation that finished or started while away, popping out of
    /// the laptop as it lands onto a pile, newest in front and the older ones
    /// peeking out under it. Back, they fly into the phone.
    private func notes(collect: TimeInterval, phone: CGPoint) -> some View {
        let count = tour.landed.count
        return ZStack(alignment: .topLeading) {
            ForEach(Array(tour.landed.enumerated()), id: \.element) { index, note in
                let depth = CGFloat(count - 1 - index)
                let p = Self.ease(min(1, max(0, (collect - Double(count - 1 - index) * 0.12) / 0.45)))
                let from = CGPoint(x: Scene.notes.x + 70, y: Scene.notes.y + 14 + depth * 7)
                HStack(spacing: 6) {
                    Image(systemName: note.done ? "checkmark.circle.fill" : "circle.dotted")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(note.done ? AnchorIOSStyle.success : AnchorIOSStyle.action)
                    Text(note.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .lineLimit(1)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(width: 142, alignment: .leading)
                .background(AnchorIOSStyle.surface, in: .capsule)
                .shadow(color: AnchorPalette.deepSea.opacity(0.08), radius: 6, y: 3)
                .scaleEffect(1 - 0.07 * depth, anchor: .top)
                .offset(y: depth * 7)
                .opacity(max(0, 1 - 0.3 * depth))
                .animation(.spring(duration: 0.45, bounce: 0.2), value: depth)
                .zIndex(Double(index))
                .scaleEffect(1 - 0.8 * p)
                .offset(x: (phone.x - from.x) * p, y: (phone.y - from.y) * p)
                .opacity(1 - p)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .offset(x: 40, y: -56).combined(with: .scale(scale: 0.3, anchor: .topLeading)).combined(with: .opacity),
                    removal: .opacity))
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.3), value: tour.landed)
    }

    // MARK: The dial

    private var dial: some View {
        // The middle of the ring, where the knob runs.
        let radius = Self.diameter / 2 - 8
        let fraction = minutes / total
        return ZStack {
            Circle()
                .stroke(AnchorIOSStyle.action.opacity(0.13), lineWidth: 16)
                .padding(8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(AnchorIOSStyle.action, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)
            ForEach(0..<AnchorTour.dialMinutes, id: \.self) { minute in
                let major = minute % 5 == 0
                Capsule()
                    .fill(minute == AnchorTour.awayAt ? AnchorIOSStyle.action
                          : AnchorIOSStyle.secondaryText.opacity(major ? 0.5 : 0.22))
                    .frame(width: major ? 3 : 1.5, height: major ? 10 : 6)
                    .offset(y: -(radius - 20))
                    .rotationEffect(.degrees(Double(minute) / total * 360))
            }
            if demoing {
                // Fast-forward, until the dial is held: turning it runs the time on.
                Image(systemName: "forward.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.action.opacity(0.5))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Text(clock)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AnchorIOSStyle.heading)
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
            // Until it is held, the knob turns a stretch by itself, a pale
            // arc filling behind it, and springs back.
            TimelineView(.animation(paused: reduceMotion || !demoing)) { context in
                let shown = demoing && !reduceMotion ? Self.demo(at: context.date.timeIntervalSinceReferenceDate) : 0
                ZStack {
                    Circle()
                        .trim(from: 0, to: shown / 360)
                        .stroke(AnchorIOSStyle.action.opacity(0.35), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(8)
                        .opacity(shown > 0.5 ? 1 : 0)
                    knob
                        .offset(y: -radius)
                        .rotationEffect(.degrees(fraction * 360 + shown))
                }
            }
            marks(radius: radius)
        }
        .animation(AnchorMotion.micro, value: demoing)
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(.circle)
        .gesture(turn)
        .allowsHitTesting(!isBack && !asksReminder)
        .accessibilityElement()
        .accessibilityLabel(TourCopy.dial)
        .accessibilityValue(clock)
        .accessibilityIdentifier("tour.dial")
        .accessibilityAdjustableAction { direction in
            if direction == .increment { advance(to: minutes + 5) }
        }
    }

    /// Minutes and seconds away.
    private var clock: String {
        let seconds = Int(minutes * 60)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var demoing: Bool { minutes == 0 && !touched && !isBack }

    /// The knob's turn by itself, in degrees: rest, a stretch clockwise, a
    /// hold, back, every three seconds.
    private static func demo(at t: TimeInterval) -> Double {
        let x = t.truncatingRemainder(dividingBy: 3)
        let reach = 30.0
        if x < 0.5 { return 0 }
        if x < 1.4 { return reach * ease((x - 0.5) / 0.9) }
        if x < 1.7 { return reach }
        if x < 2.3 { return reach * (1 - ease((x - 1.7) / 0.6)) }
        return 0
    }

    /// What happens where on the ring, just outside it: the link breaks at
    /// the first minute, coffee at five. Each lights as the knob passes it;
    /// the full turn brings the person back by itself.
    private func marks(radius: CGFloat) -> some View {
        let outside = radius + 30
        let places: [(minute: Int, symbol: String)] = [
            (AnchorTour.linkBreaksAt, "antenna.radiowaves.left.and.right.slash"),
            (AnchorTour.awayAt, "cup.and.saucer.fill"),
        ]
        return ZStack {
            ForEach(places, id: \.minute) { place in
                let angle = Double(place.minute) / total * 2 * .pi
                let reached = tour.awayMinutes >= place.minute
                Image(systemName: place.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(reached ? AnchorIOSStyle.onAction : AnchorIOSStyle.action)
                    .frame(width: 28, height: 28)
                    .background(reached ? AnchorIOSStyle.action : AnchorIOSStyle.surface, in: .circle)
                    .overlay { Circle().strokeBorder(AnchorIOSStyle.action.opacity(reached ? 0 : 0.3), lineWidth: 1) }
                    .shadow(color: AnchorIOSStyle.action.opacity(0.15), radius: 4, y: 2)
                    .scaleEffect(reached ? 1.12 : 1)
                    .animation(.spring(duration: 0.35, bounce: 0.5), value: reached)
                    .offset(x: outside * sin(angle), y: -outside * cos(angle))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var knob: some View {
        Circle()
            .fill(AnchorIOSStyle.surface)
            .overlay { Circle().strokeBorder(AnchorIOSStyle.action, lineWidth: 3) }
            .frame(width: 34, height: 34)
            .shadow(color: AnchorIOSStyle.action.opacity(0.3), radius: 6)
    }

    /// Clockwise only: time away does not run back.
    private var turn: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                touched = true
                let center = Self.diameter / 2
                let angle = atan2(drag.location.x - center, center - drag.location.y)
                defer { lastAngle = angle }
                guard let lastAngle else { return }
                var delta = angle - lastAngle
                if delta > .pi { delta -= 2 * .pi } else if delta < -.pi { delta += 2 * .pi }
                guard delta > 0 else { return }
                advance(to: minutes + delta / (2 * .pi) * total)
            }
            .onEnded { _ in
                lastAngle = nil
                // Let go within the last minute, and the dial finishes the turn.
                if minutes > total - 1 { advance(to: total) }
            }
    }

    private func advance(to value: Double) {
        minutes = min(total, value)
        tour.turnedDial(to: Int(minutes))
    }
}
#endif
