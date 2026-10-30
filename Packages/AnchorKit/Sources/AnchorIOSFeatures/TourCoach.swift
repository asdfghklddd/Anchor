#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UserNotifications

// MARK: Spots

/// The parts of the real home and desk the tour lights, in the order it lights them.
enum TourSpot: Hashable {
    case tasks, anchorButton
    /// A folder on the desk, by its place from the left.
    case folder(Int)
    /// A task's folder on the desk.
    case taskFolder(UUID)
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

// MARK: Hints

/// The tour's line: large, plain and left-aligned, in the same place on
/// each screen, saying what to do and what it makes happen. When the screen
/// moves on by itself, the new line arrives under the one before, which
/// shrinks and stays, so nothing read halfway is lost.
struct TourCaption: View {
    let text: String
    /// The line said just before on this screen.
    var earlier: String? = nil

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let earlier {
                Text(earlier)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(earlier)
                    .transition(.opacity)
            }
            Text(text)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(text)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 10)))
        }
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.1), value: text)
    }
}

/// A light wash under a caption, so the line reads over the real screen
/// without darkening it: a short fade, then solid behind the words, and a
/// fade out at the bottom when something the person needs sits just below.
/// Keep the caption at least `fade` below the wash's top.
struct TourScrim: View {
    var fadesOut = false

    static let fade: CGFloat = 40

    var body: some View {
        let wash = AnchorIOSStyle.canvasTop
        VStack(spacing: 0) {
            LinearGradient(colors: [wash.opacity(0), wash], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fade)
            wash
            if fadesOut {
                LinearGradient(colors: [wash, wash.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 18)
            }
        }
        .allowsHitTesting(false)
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
                .stroke(AnchorIOSStyle.action, lineWidth: 2)
                .shadow(color: AnchorIOSStyle.action.opacity(0.35), radius: 8)
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
                .stroke(AnchorIOSStyle.action.opacity(0.5 * (1 - phase)), lineWidth: 2)
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
                .overlay { Circle().strokeBorder(AnchorIOSStyle.action, lineWidth: 2.5) }
                .frame(width: size, height: size)
                .shadow(color: AnchorIOSStyle.action.opacity(0.3), radius: 6)
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
    let onMiss: () -> Void

    var body: some View {
        let veil = SpotlightVeil(hole: hole ?? .zero, radius: radius)
        veil.fill(Color.clear)
            .contentShape(veil, eoFill: true)
            .onTapGesture(perform: onMiss)
            .accessibilityHidden(true)
    }
}

/// Leaves the tour for the person's own Anchor, from wherever they are.
struct TourSkip: View {
    let tour: AnchorTour

    var body: some View {
        Button(TourCopy.skip) { tour.skip() }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(AnchorIOSStyle.secondaryText.opacity(0.8))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .accessibilityIdentifier("tour.skip")
    }
}

// MARK: The home

/// The tour's layer over the real portrait home, which stays bright and
/// real throughout. The sample cards float up under a ring and the first
/// line; once they land, the ring moves to the anchor button by itself and
/// the line asking for a tap arrives. The button answers all along. The
/// first drop is made a moment of, then the turn prompt; at the very end,
/// the closing line and Start.
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

    /// The cards float in, and the first line is read, before the ring moves on.
    static let helloLength: TimeInterval = 4.2

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch tour.stage {
            case .hello, .anchorButton:
                home
                    .transition(.opacity)
            case .anchored:
                if let button = spots[.anchorButton] {
                    TourFirstDrop(origin: CGPoint(x: button.midX, y: button.midY), size: size,
                                  title: tour.ownTask.flatMap { id in
                                      tour.model.projection.hostedSessions.first { $0.id == id }?.goal.title
                                  })
                    .transition(.opacity)
                }
            case .ending:
                TourEnding(tour: tour)
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
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.08), value: tour.stage)
        .animation(AnchorMotion.panel, value: inviting)
        .task(id: tour.stage) {
            guard tour.stage == .hello else { return }
            try? await Task.sleep(for: .seconds(Self.helloLength))
            guard !Task.isCancelled else { return }
            tour.greeted()
        }
    }

    private var isButton: Bool { tour.stage == .anchorButton }

    private var button: (rect: CGRect, radius: CGFloat)? {
        spots[.anchorButton].map { ($0.insetBy(dx: -8, dy: -8), ($0.width + 16) / 2) }
    }

    private var ring: (rect: CGRect, radius: CGFloat)? {
        if isButton { return button }
        return spots[.tasks].map { ($0.insetBy(dx: -6, dy: -6), 26) }
    }

    /// Only the anchor button answers; a tap anywhere else nudges the ring.
    private var home: some View {
        ZStack(alignment: .topLeading) {
            TourBlocker(hole: button?.rect, radius: button?.radius ?? 0) { nudges += 1 }
            if let ring {
                TourHalo(radius: ring.radius, nudges: nudges)
                    .frame(width: ring.rect.width, height: ring.rect.height)
                    .offset(x: ring.rect.minX, y: ring.rect.minY)
            }
            caption
        }
    }

    /// Just above the anchor button, on a wash that fades out before it.
    private var caption: some View {
        let below = spots[.anchorButton].map { size.height - $0.minY + 14 } ?? 140
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            TourCaption(text: isButton ? TourCopy.anchorButton : TourCopy.hello,
                        earlier: isButton ? TourCopy.hello : nil)
                .frame(maxWidth: 440)
                .padding(.horizontal, 26)
                .padding(.top, TourScrim.fade + 8)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .background { TourScrim(fadesOut: true) }
                .padding(.bottom, below)
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: The first drop

/// The person's first anchor going down, made a moment of. The real drop
/// plays on the home as always; where it meets the water, rings run out
/// across the whole sea, the phone thumps, and the line says so over the
/// dome while the new card settles in the list below.
struct TourFirstDrop: View {
    /// The anchor button's middle, where the anchor meets the water.
    let origin: CGPoint
    let size: CGSize
    let title: String?

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
                .position(x: size.width / 2, y: size.height * 0.36)
                .opacity(said ? 1 : 0)
                .scaleEffect(said || reduceMotion ? 1 : 0.92)
                .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.25), value: said)
        }
        .frame(width: size.width, height: size.height)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: landed)
        .sensoryFeedback(.success, trigger: caught)
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(Self.contact))
            guard !Task.isCancelled else { return }
            TourSound.shared.play(.anchored)
            landed += 1
            try? await Task.sleep(for: .seconds(0.3))
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

    private var words: some View {
        VStack(spacing: 8) {
            Text(TourCopy.firstAnchor)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AnchorIOSStyle.heading)
            if let title {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
        .padding(.vertical, 30)
        .background {
            // A patch of still water over the dome, soft at its edges.
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(AnchorIOSStyle.canvasTop)
                .blur(radius: 16)
        }
    }
}

// MARK: The ending

/// The sample tasks have weighed anchor and the sea is empty. One line on
/// what Anchor is for, what the person did in the tour, and Start, which
/// hands over to their own Anchor and its connection card.
struct TourEnding: View {
    let tour: AnchorTour

    @AnchorReducedMotion private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            Text(TourCopy.ending)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .appear(shown, after: 0, reduceMotion: reduceMotion)
            Text(TourCopy.endingStats(conversations: tour.conversationsMoved, minutes: AnchorTour.dialMinutes))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .appear(shown, after: 0.5, reduceMotion: reduceMotion)
            Button { tour.start() } label: {
                Text(TourCopy.start)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
            .tint(AnchorIOSStyle.action)
            .padding(.top, 30)
            .appear(shown, after: 1.0, reduceMotion: reduceMotion)
            .accessibilityIdentifier("tour.start")
        }
        .frame(maxWidth: 440, alignment: .leading)
        .padding(.horizontal, 26)
        .padding(.bottom, 54)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // The dome and its clock stay in view; the emptied list goes under still water.
            LinearGradient(stops: [.init(color: AnchorIOSStyle.canvasTop.opacity(0), location: 0.25),
                                   .init(color: AnchorIOSStyle.canvasTop, location: 0.56),
                                   .init(color: AnchorIOSStyle.canvasTop, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
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

/// After the drop: a phone outline turns on its side over the line saying
/// what waits there, in the same place above the harbor as the lines
/// before. If the screen cannot turn, a quiet line says why and offers the
/// desk here instead.
struct TourTurnPrompt: View {
    let gravity: DeviceGravityMonitor
    let onSideways: () -> Void

    @State private var waited = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                TourPhoneTurn()
                    .frame(width: 140, height: 140)
                    .scaleEffect(0.7)
                    .frame(width: 98, height: 98)
                TourCaption(text: TourCopy.turn)
                if showsLock { lock }
            }
            .frame(maxWidth: 440, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, TourScrim.fade)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            .background { TourScrim(fadesOut: true) }
            // The harbor and its hanging anchor stay clear below.
            Color.clear.frame(height: WorkInvitationHarbor.height)
        }
        .animation(AnchorMotion.panel, value: showsLock)
        .task {
            try? await Task.sleep(for: .seconds(6))
            waited = true
        }
    }

    private var showsLock: Bool { waited || gravity.suggestsOrientationLock }

    private var lock: some View {
        HStack(spacing: 12) {
            Label(gravity.suggestsOrientationLock ? L10n.workInvitationLock : TourCopy.lockQuestion,
                  systemImage: "lock.rotation")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(TourCopy.openHere, action: onSideways)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glass)
                .tint(AnchorIOSStyle.action)
                .accessibilityIdentifier("tour.sideways")
        }
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

/// The tour on the real desk, which stays bright. The ring passes over each
/// folder while the line says what they are, then rests on the folder of
/// the task the person just dropped, where an agent has started. Then the
/// homework's question arrives on its own and the ring settles on its front
/// card, the one part that answers a tap. Last, a friend calls the person
/// away. The line sits in the column left of the folders, at its foot.
private struct TourDeskCoach: View {
    let tour: AnchorTour
    let spots: [TourSpot: CGRect]
    let size: CGSize

    @AnchorReducedMotion private var reduceMotion
    /// The folder the ring is on; past the last it rests on the person's own.
    @State private var lit = 0
    @State private var nudges = 0

    private struct Hole: Equatable {
        let rect: CGRect
        let radius: CGFloat
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch tour.stage {
            case .desk, .waiting:
                TourBlocker(hole: tour.stage == .waiting ? hole?.rect : nil, radius: hole?.radius ?? 0) { nudges += 1 }
                if let hole {
                    TourHalo(radius: hole.radius, nudges: nudges)
                        .frame(width: hole.rect.width, height: hole.rect.height)
                        .offset(x: hole.rect.minX, y: hole.rect.minY)
                        .transition(.opacity)
                }
                column {
                    TourCaption(text: line, earlier: earlierLine)
                }
            case .called:
                TourBlocker {}
                column {
                    TourPhoneTurn(upright: true)
                        .frame(width: 110, height: 110)
                        .frame(maxWidth: .infinity)
                    TourCaption(text: TourCopy.called)
                }
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
        case .waiting:
            guard let card = spots[.frontCard(tour.waitingTaskID)] else { return nil }
            return Hole(rect: card.insetBy(dx: -6, dy: -6), radius: 21)
        default:
            return nil
        }
    }

    /// What the folders are while the ring walks them; the person's own task
    /// once it rests; the question once it arrives.
    private var line: String {
        if tour.stage == .waiting { return TourCopy.waiting }
        return lit < DeskTaskLibrary.Metrics.slots ? TourCopy.folders : TourCopy.ownTask
    }

    private var earlierLine: String? {
        if tour.stage == .waiting { return TourCopy.ownTask }
        return lit < DeskTaskLibrary.Metrics.slots ? nil : TourCopy.folders
    }

    /// The column left of the folders, clear of the Dynamic Island's edge:
    /// the line at its foot on a light wash, Skip under it.
    private func column(@ViewBuilder _ content: () -> some View) -> some View {
        let edge: CGFloat = 58
        let right = (folders.first?.minX ?? size.width * 0.36) - 16
        return VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 14) { content() }
                .padding(.top, TourScrim.fade + 24)
                .padding(.leading, edge)
                .padding(.trailing, 4)
                .background { TourScrim() }
            TourSkip(tour: tour)
                .padding(.leading, edge - 12)
        }
        .padding(.bottom, 6)
        .frame(width: max(200, right), height: size.height, alignment: .leading)
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

    private static let diameter: CGFloat = 248
    private var total: Double { Double(AnchorTour.dialMinutes) }
    private var isBack: Bool { tour.stage == .back }

    var body: some View {
        VStack(spacing: 22) {
            TourCaption(text: line)
                .frame(maxWidth: 340, alignment: .leading)
                .frame(maxWidth: .infinity)
            link
                .frame(height: 210, alignment: .top)
            dial
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
                TourSound.shared.play(.snap)
            } else if passed < AnchorTour.awayAt, now >= AnchorTour.awayAt {
                TourSound.shared.play(.away)
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
                walkway.opacity(min(1, minutes * 2) * (1 - home))
                cafe(at: t).opacity(walk > 0.7 ? 1 : 0).animation(AnchorMotion.panel, value: walk > 0.7)
                linkLine(from: CGPoint(x: Scene.mac.x + 46, y: Scene.mac.y), to: CGPoint(x: phone.x - 19, y: phone.y),
                         joined: joined, zip: isBack ? home : 1, at: t)
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

    /// The dotted way to the café.
    private var walkway: some View {
        Path { path in
            path.move(to: Scene.start)
            path.addQuadCurve(to: Scene.table, control: Scene.bend)
        }
        .stroke(AnchorIOSStyle.action.opacity(0.28), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 6]))
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

    @ViewBuilder
    private func linkLine(from a: CGPoint, to b: CGPoint, joined: Bool, zip: Double, at t: TimeInterval) -> some View {
        let tint = AnchorIOSStyle.action
        if joined {
            // Coming back, the line closes from the laptop to the phone like a zip.
            Path { path in
                path.move(to: a)
                path.addLine(to: CGPoint(x: a.x + (b.x - a.x) * zip, y: a.y + (b.y - a.y) * zip))
            }
            .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: isBack ? 3 : 2, lineCap: .round,
                                                           dash: [5, 6],
                                                           // Within one dash (5 + 6), as the turn prompt's wake.
                                                           dashPhase: reduceMotion ? 0 : -(t * 22).truncatingRemainder(dividingBy: 11)))
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

    /// Each conversation that finished or started while away, newest last,
    /// popping out of the laptop as it lands. Back, they fly into the phone.
    private func notes(collect: TimeInterval, phone: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(tour.landed.enumerated()), id: \.element) { index, note in
                let p = Self.ease(min(1, max(0, (collect - Double(index) * 0.12) / 0.45)))
                let from = CGPoint(x: Scene.notes.x + 70, y: Scene.notes.y + 12 + CGFloat(index) * 29)
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
            Text(clock)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AnchorIOSStyle.heading)
            knob
                .offset(y: -radius)
                .rotationEffect(.degrees(fraction * 360))
            if minutes == 0 {
                // A ring on the knob glides a stretch clockwise round the dial.
                TourGrip { p in
                    let angle = p * .pi / 3
                    return CGSize(width: radius * sin(angle), height: radius * (1 - cos(angle)))
                }
                .offset(y: -radius)
                .transition(.opacity)
            }
        }
        .animation(AnchorMotion.micro, value: minutes == 0)
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(.circle)
        .gesture(turn)
        .allowsHitTesting(!isBack && !asksReminder)
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
