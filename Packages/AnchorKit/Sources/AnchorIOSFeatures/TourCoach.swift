#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

// MARK: Spots

/// The parts of the real home and desk the tour lights, in the order it lights them.
enum TourSpot: Hashable {
    case tasks, anchorButton
    /// A folder on the desk, by its place from the left.
    case folder(Int)
    /// The card in front of a task's folder.
    case frontCard(UUID)
}

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

// MARK: The pet's line

/// The tour's voice: the person's pet (the crab unless they chose another)
/// beside one short line, saying it aloud in its own chirping voice and
/// hopping while it talks. The speaker in the bubble turns the sound off.
struct TourPetLine: View {
    let text: String
    var act: DeskPetAct = .idle
    var pixel: CGFloat = 2.6
    /// The pet sits on top of the bubble instead of beside it, where room is narrow.
    var stacked = false

    @AppStorage(DeskPetKind.defaultsKey, store: ProfilePreferences.store) private var petKind = DeskPetKind.crab
    @AppStorage(TourSound.mutedKey) private var muted = false
    @State private var talkingUntil = Date.distantPast

    private var kind: DeskPetKind { petKind == .off ? .crab : petKind }

    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: 4) {
                    TourPet(kind: kind, act: act, talkingUntil: talkingUntil, pixel: pixel)
                        .padding(.leading, 6)
                    bubble
                }
            } else {
                HStack(alignment: .bottom, spacing: 2) {
                    TourPet(kind: kind, act: act, talkingUntil: talkingUntil, pixel: pixel)
                    bubble
                }
            }
        }
        .task(id: text) {
            // The line lands with its screen; the voice waits for it to settle.
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            talkingUntil = .now + TourSound.shared.say(text, as: kind)
        }
    }

    private var bubble: some View {
        HStack(alignment: .top, spacing: 4) {
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
            Button {
                muted.toggle()
                if muted { TourSound.shared.hush() }
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.secondaryText.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.top, -5)
            .accessibilityLabel(muted ? TourCopy.unmute : TourCopy.mute)
        }
        .padding(.leading, 15)
        .padding(.trailing, 6)
        .padding(.vertical, 12)
        .background(TourBubble(tailOnTop: stacked).fill(AnchorIOSStyle.surface))
        .shadow(color: AnchorPalette.deepSea.opacity(0.2), radius: 16, y: 7)
        .padding(.bottom, stacked ? 0 : 6)
        .animation(AnchorMotion.micro, value: text)
    }
}

/// A rounded bubble with a small rounded tail toward the pet: at its lower
/// left, or at its top left when the pet sits on top.
private struct TourBubble: Shape {
    var tailOnTop = false

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: 18, style: .continuous)
        if tailOnTop {
            path.move(to: CGPoint(x: rect.minX + 22, y: rect.minY + 2))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 30, y: rect.minY - 7),
                              control: CGPoint(x: rect.minX + 27, y: rect.minY - 1))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 42, y: rect.minY + 2),
                              control: CGPoint(x: rect.minX + 33, y: rect.minY + 1))
        } else {
            path.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 22))
            path.addQuadCurve(to: CGPoint(x: rect.minX - 6, y: rect.maxY - 6),
                              control: CGPoint(x: rect.minX + 1, y: rect.maxY - 10))
            path.addQuadCurve(to: CGPoint(x: rect.minX + 12, y: rect.maxY - 2),
                              control: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        }
        path.closeSubpath()
        return path
    }
}

/// The pet drawn alone, eight steps a second: blinking now and then, and
/// hopping a pixel with each beat while it talks.
struct TourPet: View {
    let kind: DeskPetKind
    var act: DeskPetAct = .idle
    var talkingUntil = Date.distantPast
    var pixel: CGFloat = 2.6

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        let look = DeskPetLook.of(kind)
        TimelineView(.periodic(from: .now, by: 0.125)) { context in
            let tick = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate * 8)
            let talking = !reduceMotion && context.date < talkingUntil
            Canvas { canvas, size in
                let columns = Int(size.width / pixel)
                let rows = Int(size.height / pixel)
                DeskPetRenderer(look: look, kind: kind, context: canvas,
                                left: max(0, (columns - look.width) / 2),
                                ground: rows - 1 - (talking && tick % 2 == 0 ? 1 : 0), pixel: pixel)
                    .draw(DeskPetFrame(act: act, progress: tick % 16, length: 16, tick: tick,
                                       blink: !talking && tick % 29 == 0, still: reduceMotion))
            }
        }
        .frame(width: CGFloat(look.width + 2) * pixel, height: CGFloat(look.height + 5) * pixel)
        .accessibilityHidden(true)
    }
}

// MARK: The home

/// The tour's layer over the real portrait home: a dim with one part left
/// bright and the pet's line beside it, the cheer when the anchor is down,
/// then the turn prompt. The home under it stays real and visible throughout.
struct TourCoach: View {
    let tour: AnchorTour
    let spots: [TourSpot: CGRect]
    /// The whole screen, safe areas included, which `spots` are measured in.
    let size: CGSize
    /// The harbor invitation is up: the turn prompt arrives with it, after the anchor catches.
    let inviting: Bool
    let gravity: DeviceGravityMonitor
    let onSideways: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var nudges = 0

    var body: some View {
        ZStack {
            switch tour.stage {
            case .hello, .anchorButton:
                if let hole {
                    spotlight(hole: hole, in: size)
                        .transition(.opacity)
                }
            case .anchored:
                TourCheer(count: tour.model.projection.hostedSessions.count)
                    .transition(.opacity)
            case .turn:
                if inviting {
                    TourTurnPrompt(gravity: gravity, onSideways: onSideways)
                        .transition(.opacity)
                }
            default:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.08), value: tour.stage)
        .animation(AnchorMotion.panel, value: inviting)
        .task(id: tour.stage) {
            // Hello is said once; then the light moves on to the anchor.
            guard tour.stage == .hello else { return }
            let length = TourBabble.length(of: TourBabble.syllables(of: TourCopy.hello))
            try? await Task.sleep(for: .seconds(max(2.6, length + 1.1)))
            guard !Task.isCancelled else { return }
            tour.greeted()
        }
    }

    private var spot: TourSpot? {
        switch tour.stage {
        case .hello: .tasks
        case .anchorButton: .anchorButton
        default: nil
        }
    }

    private var hole: Hole? {
        guard let spot, let frame = spots[spot] else { return nil }
        return spot == .anchorButton
            ? Hole(rect: frame.insetBy(dx: -9, dy: -9), radius: (frame.width + 18) / 2)
            : Hole(rect: frame.insetBy(dx: -6, dy: -6), radius: 22)
    }

    private struct Hole: Equatable {
        let rect: CGRect
        let radius: CGFloat
    }

    // MARK: Spotlight

    private func spotlight(hole: Hole, in size: CGSize) -> some View {
        let veil = SpotlightVeil(hole: hole.rect, radius: hole.radius)
        let isButton = tour.stage == .anchorButton
        return ZStack(alignment: .topLeading) {
            veil
                .fill(Self.dim, style: FillStyle(eoFill: true))
                // Hello takes a tap anywhere as "go on"; at the button, a tap
                // beside it sends a ripple toward it.
                .contentShape(isButton ? AnyShape(veil) : AnyShape(Rectangle()), eoFill: isButton)
                .onTapGesture { if isButton { nudges += 1 } else { tour.greeted() } }
            RoundedRectangle(cornerRadius: hole.radius, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .shadow(color: AnchorIOSStyle.action.opacity(0.45), radius: 10)
                .frame(width: hole.rect.width, height: hole.rect.height)
                .offset(x: hole.rect.minX, y: hole.rect.minY)
                .allowsHitTesting(false)
            if isButton {
                TourRipple(trigger: nudges)
                    .frame(width: hole.rect.width, height: hole.rect.height)
                    .offset(x: hole.rect.minX, y: hole.rect.minY)
                    .allowsHitTesting(false)
            }
            line(below: hole.rect.midY < size.height * 0.5, hole: hole.rect, in: size)
        }
    }

    private func line(below: Bool, hole: CGRect, in size: CGSize) -> some View {
        TourPetLine(text: tour.stage == .hello ? TourCopy.hello : TourCopy.anchorButton,
                    act: tour.stage == .hello ? .wave : .idle)
            .frame(maxWidth: min(340, size.width - 36), alignment: .leading)
            .id(tour.stage)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: below ? -8 : 8)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
            .padding(below ? .top : .bottom, below ? hole.maxY + 10 : size.height - hole.minY + 10)
    }

    /// The home darkens a little, never so much that it stops reading as itself.
    static let dim = AnchorPalette.deepSea.opacity(0.36)
}

/// The whole screen with a rounded hole, filled even-odd. The hole moves
/// smoothly from one part of the home to the next.
private struct SpotlightVeil: Shape {
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
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: radius, height: radius), style: .continuous)
        return path
    }
}

/// Rings spreading from the anchor button, like water around a dropped
/// anchor; a tap outside the button sends one more right away.
private struct TourRipple: View {
    let trigger: Int
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        if reduceMotion {
            Circle().stroke(Color.white.opacity(0.6), lineWidth: 2)
        } else {
            ZStack {
                ring(delay: 0)
                ring(delay: 1.2)
            }
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                SpringKeyframe(1.12, duration: 0.18)
                SpringKeyframe(1.0, duration: 0.4)
            }
        }
    }

    private func ring(delay: Double) -> some View {
        TimelineView(.animation) { context in
            let phase = (context.date.timeIntervalSinceReferenceDate + delay).truncatingRemainder(dividingBy: 2.4) / 2.4
            Circle()
                .stroke(Color.white.opacity(0.75 * (1 - phase)), lineWidth: 2)
                .scaleEffect(1 + 0.55 * phase)
        }
    }
}

// MARK: The cheer

/// The anchor is down, and the tour makes a moment of it, as a game does at
/// the end of a lesson: a big anchor plunges into the middle of the screen,
/// the water splashes up and rings out to the edges, the screen jolts, the
/// word lands, and the pet cheers how many tasks are anchored now.
struct TourCheer: View {
    let count: Int

    @AnchorReducedMotion private var reduceMotion
    @State private var start = Date.now
    @State private var hits = 0
    @State private var cheers = 0

    /// The anchor meets the water.
    private static let impact: TimeInterval = 0.42
    private static let drops: [(angle: Double, speed: Double, size: CGFloat)] = (0..<18).map { index in
        let spread = Double(index) / 17
        let wobble = Double((index * 7) % 5) / 5
        return (angle: -.pi * (0.1 + 0.8 * spread), speed: 330 + 300 * wobble, size: 6 + CGFloat((index * 3) % 5))
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let water = CGPoint(x: size.width / 2, y: size.height * 0.44)
            TimelineView(.animation(paused: reduceMotion)) { context in
                let t = reduceMotion ? 1.6 : context.date.timeIntervalSince(start)
                ZStack {
                    AnchorIOSStyle.canvasTop.opacity(0.97 * min(1, t / 0.2))
                    rings(at: t, around: water, in: size)
                    splash(at: t, from: water)
                    anchor(at: t, water: water, in: size)
                    words(at: t)
                        .position(x: size.width / 2, y: water.y + 150)
                }
                .offset(x: shake(at: t))
            }
        }
        .ignoresSafeArea()
        .contentShape(.rect)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: hits)
        .sensoryFeedback(.success, trigger: cheers)
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(reduceMotion ? 0 : Self.impact))
            guard !Task.isCancelled else { return }
            TourSound.shared.play(.anchored)
            hits += 1
            try? await Task.sleep(for: .seconds(0.45))
            cheers += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(TourCopy.anchored) \(TourCopy.anchoredCount(count))")
    }

    private func since(_ t: TimeInterval) -> TimeInterval { max(0, t - Self.impact) }

    /// Falling under gravity, squashing on the water, then bobbing as it settles.
    private func anchor(at t: TimeInterval, water: CGPoint, in size: CGSize) -> some View {
        let fall = min(1, t / Self.impact)
        let after = since(t)
        let y = t < Self.impact
            ? -size.height * 0.15 + (water.y - 40 + size.height * 0.15) * fall * fall
            : water.y - 40 + 14 * sin(after * 9) * exp(-after * 4)
        let squash = t < Self.impact ? 0 : 0.22 * exp(-after * 9) * cos(after * 26)
        return HarborAnchorGlyph(color: AnchorIOSStyle.action, lineWidth: 9)
            .frame(width: 128, height: 128)
            .scaleEffect(x: 1 + squash, y: 1 - squash, anchor: .bottom)
            .shadow(color: AnchorIOSStyle.action.opacity(0.35), radius: 18, y: 8)
            .position(x: water.x, y: y)
    }

    /// Rings across the water, flattened as seen from above, reaching the edges.
    private func rings(at t: TimeInterval, around water: CGPoint, in size: CGSize) -> some View {
        let after = since(t)
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let p = min(1, max(0, (after - Double(index) * 0.13) / 1.15))
                let eased = 1 - pow(1 - p, 3)
                Ellipse()
                    .stroke(AnchorIOSStyle.action.opacity(t < Self.impact ? 0 : 0.5 * (1 - p)), lineWidth: 4 - 2 * p)
                    .frame(width: 60 + size.width * 1.5 * eased, height: 18 + size.width * 0.45 * eased)
                    .position(x: water.x, y: water.y + 26)
            }
            Circle()
                .fill(AnchorIOSStyle.cyan.opacity(t < Self.impact ? 0 : 0.22 * max(0, 1 - after / 0.7)))
                .frame(width: 120 + 500 * min(1, after / 0.7), height: 120 + 500 * min(1, after / 0.7))
                .position(water)
        }
    }

    /// Drops thrown up from where the anchor went in, falling back as they fade.
    private func splash(at t: TimeInterval, from water: CGPoint) -> some View {
        let after = since(t)
        return Canvas { context, _ in
            guard t >= Self.impact, after < 1.1 else { return }
            for drop in Self.drops {
                let x = water.x + cos(drop.angle) * drop.speed * after
                let y = water.y + 20 + sin(drop.angle) * drop.speed * after + 900 * after * after
                let fade = max(0, 1 - after / 1.1)
                let rect = CGRect(x: x - drop.size / 2, y: y - drop.size / 2, width: drop.size, height: drop.size * 1.25)
                context.fill(Path(ellipseIn: rect), with: .color(AnchorIOSStyle.cyan.opacity(fade)))
            }
        }
        .allowsHitTesting(false)
    }

    /// The word lands with a bounce, then the pet cheers under it.
    private func words(at t: TimeInterval) -> some View {
        // A spring from a third of its size, overshooting once.
        let p = min(1, max(0, (t - 0.55) / 0.6))
        let pop = 1 - 0.7 * exp(-6 * p) * cos(9 * p)
        let pet = min(1, max(0, (t - 0.9) / 0.3))
        return VStack(spacing: 18) {
            Text(TourCopy.anchored)
                .font(.system(size: 50, weight: .heavy, design: .rounded))
                .foregroundStyle(AnchorIOSStyle.heading)
                .scaleEffect(pop)
                .opacity(min(1, p * 4))
            TourPetLine(text: TourCopy.anchoredCount(count), act: .celebrate, pixel: 3.2)
                .fixedSize()
                .opacity(pet)
                .offset(y: 16 * (1 - pet))
        }
    }

    private func shake(at t: TimeInterval) -> CGFloat {
        let after = since(t)
        guard t >= Self.impact, after < 0.35 else { return 0 }
        return CGFloat(sin(after * 70) * 7 * (1 - after / 0.35))
    }
}

// MARK: Turning

/// After the drop: the home softens, and a phone outline turns on its side
/// above the pet's line saying what waits there. If the screen cannot turn,
/// a quiet line says why and offers the desk here instead.
struct TourTurnPrompt: View {
    let gravity: DeviceGravityMonitor
    let onSideways: () -> Void

    @State private var waited = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            TourPhoneTurn()
                .frame(width: 150, height: 150)
            TourPetLine(text: TourCopy.turn)
                .frame(maxWidth: 320)
            lock
                .frame(height: 96, alignment: .top)
            Spacer(minLength: 0)
            // The harbor and its hanging anchor stay clear below.
            Color.clear.frame(height: WorkInvitationHarbor.height)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(stops: [.init(color: AnchorIOSStyle.canvasTop.opacity(0.8), location: 0),
                                   .init(color: AnchorIOSStyle.canvasTop.opacity(0.72), location: 0.62),
                                   .init(color: AnchorIOSStyle.canvasTop.opacity(0), location: 0.8)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .animation(AnchorMotion.panel, value: showsLock)
        .task {
            try? await Task.sleep(for: .seconds(6))
            waited = true
        }
    }

    private var showsLock: Bool { waited || gravity.suggestsOrientationLock }

    @ViewBuilder private var lock: some View {
        if showsLock {
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
            .transition(.opacity.combined(with: .offset(y: 6)))
        }
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
            Circle()
                .trim(from: 0.55, to: 0.8)
                .stroke(AnchorIOSStyle.action.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7],
                                           dashPhase: reduceMotion ? 0 : -context.date.timeIntervalSinceReferenceDate * 14))
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

/// The tour on the real desk. The light passes over each folder, then holds
/// them all; then it settles on the homework's front card as its question
/// arrives, and only that card answers a tap. Last, a friend calls the
/// person away.
private struct TourDeskCoach: View {
    let tour: AnchorTour
    let spots: [TourSpot: CGRect]
    let size: CGSize

    @AnchorReducedMotion private var reduceMotion
    /// The folder the light is on; past the last it holds them all.
    @State private var lit = 0

    private struct Hole: Equatable {
        let rect: CGRect
        let radius: CGFloat
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch tour.stage {
            case .desk, .waiting:
                if let hole {
                    spotlight(hole)
                        .transition(.opacity)
                }
            case .called:
                TourCalledAway()
                    .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.06), value: hole)
        .animation(AnchorMotion.panel, value: tour.stage)
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

    private var folders: [CGRect] {
        (0..<DeskTaskLibrary.Metrics.slots).compactMap { spots[.folder($0)] }
    }

    private var holdsAll: Bool { lit >= folders.count }

    private var hole: Hole? {
        switch tour.stage {
        case .desk:
            guard let first = folders.first else { return nil }
            if !holdsAll { return Hole(rect: folders[lit].insetBy(dx: -6, dy: -6), radius: 21) }
            let all = folders.dropFirst().reduce(first) { $0.union($1) }
            return Hole(rect: all.insetBy(dx: -8, dy: -8), radius: 23)
        case .waiting:
            guard let card = spots[.frontCard(tour.waitingTaskID)] else { return nil }
            return Hole(rect: card.insetBy(dx: -6, dy: -6), radius: 21)
        default:
            return nil
        }
    }

    /// While the folders are shown the desk takes no taps; once the question
    /// is lit, a tap reaches only the card under the light.
    private func spotlight(_ hole: Hole) -> some View {
        let veil = SpotlightVeil(hole: hole.rect, radius: hole.radius)
        let waiting = tour.stage == .waiting
        return ZStack(alignment: .topLeading) {
            veil
                .fill(TourCoach.dim, style: FillStyle(eoFill: true))
                .contentShape(waiting ? AnyShape(veil) : AnyShape(Rectangle()), eoFill: waiting)
                .onTapGesture {}
            RoundedRectangle(cornerRadius: hole.radius, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .shadow(color: AnchorIOSStyle.action.opacity(0.45), radius: 10)
                .frame(width: hole.rect.width, height: hole.rect.height)
                .offset(x: hole.rect.minX, y: hole.rect.minY)
                .allowsHitTesting(false)
            if waiting || holdsAll {
                line(beside: hole.rect)
            }
        }
    }

    /// The pet's line beside the light, on whichever side has more room.
    private func line(beside hole: CGRect) -> some View {
        let gap: CGFloat = 12
        // The Dynamic Island takes one edge when the phone lies sideways.
        let edge: CGFloat = 58
        let leftRoom = hole.minX - gap - edge
        let rightRoom = size.width - hole.maxX - gap - edge
        let onLeft = leftRoom >= rightRoom
        let width = min(300, max(onLeft ? leftRoom : rightRoom, 200))
        let x = onLeft ? hole.minX - gap - width / 2 : hole.maxX + gap + width / 2
        let waiting = tour.stage == .waiting
        return TourPetLine(text: waiting ? TourCopy.waiting : TourCopy.folders, act: waiting ? .think : .idle,
                           pixel: 2.2, stacked: true)
            .frame(width: width)
            .id(tour.stage)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: onLeft ? 8 : -8)))
            .position(x: x, y: min(max(hole.midY, 90), size.height - 90))
    }
}

/// A friend asks the person down for coffee: the desk softens, and a phone
/// outline comes up off its side beside the pet's line. Picking the phone
/// up is how they go; the desk under it waits.
private struct TourCalledAway: View {
    var body: some View {
        HStack(spacing: 24) {
            TourPhoneTurn(upright: true)
                .frame(width: 130, height: 130)
            TourPetLine(text: TourCopy.called, act: .coffee)
                .frame(maxWidth: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnchorIOSStyle.canvasTop.opacity(0.84))
        .contentShape(.rect)
    }
}

// MARK: Away and back

/// The time away, in the person's hands: a dial they turn clockwise, a
/// minute a tick. Past the first minute the Bluetooth link to the Mac
/// breaks; at five the phone counts as away; the agents' news lands on the
/// laptop as the minutes go by; at the end of the dial the phone is back in
/// range and the link joins again.
struct TourAwayDial: View {
    let tour: AnchorTour

    @AnchorReducedMotion private var reduceMotion
    /// Where the dial is, in minutes; the tour hears whole minutes.
    @State private var minutes = 0.0
    @State private var lastAngle: Double?
    @State private var backAt: Date?

    private static let diameter: CGFloat = 248
    private var total: Double { Double(AnchorTour.dialMinutes) }
    private var isBack: Bool { tour.stage == .back }

    var body: some View {
        VStack(spacing: 22) {
            TourPetLine(text: line, act: isBack ? .happy : (tour.awayMinutes >= AnchorTour.awayAt ? .coffee : .idle))
                .frame(maxWidth: 340, alignment: .leading)
                .frame(maxWidth: .infinity)
            link
                .frame(height: 210, alignment: .top)
            dial
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnchorIOSStyle.canvasTop.ignoresSafeArea())
        .contentShape(.rect)
        .sensoryFeedback(.selection, trigger: tour.awayMinutes)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tour.awayMinutes >= AnchorTour.linkBreaksAt)
        .sensoryFeedback(.success, trigger: isBack)
        .onChange(of: tour.awayMinutes) { passed, now in
            if passed < AnchorTour.linkBreaksAt, now >= AnchorTour.linkBreaksAt {
                TourSound.shared.play(.snap)
            } else if passed < AnchorTour.awayAt, now >= AnchorTour.awayAt {
                TourSound.shared.play(.away)
            } else if now < AnchorTour.dialMinutes {
                TourSound.shared.play(.tick)
            }
        }
        .onChange(of: isBack) { _, back in
            guard back else { return }
            backAt = .now
            TourSound.shared.play(.rejoin)
        }
    }

    private var line: String {
        if isBack { return TourCopy.together }
        return tour.awayMinutes >= AnchorTour.awayAt ? TourCopy.apart : TourCopy.dial
    }

    // MARK: The link

    /// The laptop and the phone, and the line between them: joined at first,
    /// stretched and broken once the phone walks off, joined again at the end.
    /// What the agents finish lands under the laptop.
    private var link: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let home = backAt.map { min(1, context.date.timeIntervalSince($0) / 0.6) } ?? 0
            let drift = min(1, minutes / Double(AnchorTour.linkBreaksAt)) * (1 - home)
            let joined = minutes < Double(AnchorTour.linkBreaksAt) || home >= 1
            let mac = CGPoint(x: 64, y: 50)
            let phone = CGPoint(x: 186 + 70 * drift, y: 54 + 14 * drift)
            ZStack(alignment: .topLeading) {
                linkLine(from: CGPoint(x: mac.x + 46, y: mac.y), to: CGPoint(x: phone.x - 19, y: phone.y),
                         joined: joined, at: t)
                laptop(at: t).position(mac)
                phoneOutline.position(phone)
                notes
                    .frame(width: 150, alignment: .topLeading)
                    .offset(x: 8, y: 92)
            }
            .frame(width: 300, height: 210, alignment: .topLeading)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func linkLine(from a: CGPoint, to b: CGPoint, joined: Bool, at t: TimeInterval) -> some View {
        let tint = AnchorIOSStyle.action
        if joined {
            Path { path in
                path.move(to: a)
                path.addLine(to: b)
            }
            .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: isBack ? 3 : 2, lineCap: .round,
                                                           dash: [5, 6], dashPhase: reduceMotion ? 0 : -t * 22))
        } else {
            // Each half pulled back toward its own end.
            let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            Path { path in
                path.move(to: a)
                path.addLine(to: CGPoint(x: a.x + (middle.x - a.x) * 0.45, y: a.y + (middle.y - a.y) * 0.45))
                path.move(to: b)
                path.addLine(to: CGPoint(x: b.x + (middle.x - b.x) * 0.45, y: b.y + (middle.y - b.y) * 0.45))
            }
            .stroke(tint.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 6]))
        }
    }

    /// A laptop whose screen shows three dots taking turns: the agents at work.
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
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            let phase = (t * 1.6 - Double(index) * 0.33).truncatingRemainder(dividingBy: 1)
                            Circle()
                                .fill(AnchorIOSStyle.action)
                                .frame(width: 7, height: 7)
                                .opacity(reduceMotion ? 0.7 : 0.3 + 0.7 * max(0, sin(phase * .pi)))
                        }
                    }
                }
            Capsule()
                .fill(AnchorIOSStyle.action.opacity(0.85))
                .frame(width: 104, height: 6)
        }
        .shadow(color: AnchorIOSStyle.action.opacity(0.2), radius: 12, y: 6)
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

    /// Each conversation that finished or started while away, newest last.
    private var notes: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(tour.landed, id: \.self) { note in
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
                .background(AnchorIOSStyle.surface, in: .capsule)
                .shadow(color: AnchorPalette.deepSea.opacity(0.08), radius: 6, y: 3)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -8)).combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.3), value: tour.landed)
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
            Text(clock)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AnchorIOSStyle.heading)
            knob
                .offset(y: -radius)
                .rotationEffect(.degrees(fraction * 360))
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(.circle)
        .gesture(turn)
        .allowsHitTesting(!isBack)
        .accessibilityElement()
        .accessibilityLabel(TourCopy.dial)
        .accessibilityValue(clock)
        .accessibilityAdjustableAction { direction in
            if direction == .increment { advance(to: minutes + 5) }
        }
    }

    /// Minutes and seconds away.
    private var clock: String {
        let seconds = Int(minutes * 60)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// The knob breathes until the dial is first turned.
    private var knob: some View {
        TimelineView(.animation(paused: reduceMotion || minutes > 0)) { context in
            let pulse = minutes > 0 || reduceMotion ? 0 : (1 + sin(context.date.timeIntervalSinceReferenceDate * 4)) / 2
            Circle()
                .fill(AnchorIOSStyle.surface)
                .overlay { Circle().strokeBorder(AnchorIOSStyle.action, lineWidth: 3) }
                .frame(width: 34, height: 34)
                .shadow(color: AnchorIOSStyle.action.opacity(0.3 + 0.3 * pulse), radius: 6 + 8 * pulse)
                .scaleEffect(1 + 0.12 * pulse)
        }
    }

    /// Clockwise only: time away does not run back.
    private var turn: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
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
