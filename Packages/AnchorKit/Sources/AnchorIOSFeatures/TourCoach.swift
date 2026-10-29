#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

// MARK: Spots

/// The parts of the real home and desk the tour lights, in the order it lights them.
enum TourSpot: Hashable {
    case tasks, anchoring, anchorButton
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

// MARK: The coach

/// The tour's layer over the real portrait home: a dim with one part left
/// bright and a short line beside it, then the turn prompt once the anchor
/// is down. The home under it stays real and visible throughout.
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
            case .tasks, .anchoring, .anchorButton:
                if let hole {
                    spotlight(hole: hole, in: size)
                        .transition(.opacity)
                }
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
    }

    private var spot: TourSpot? {
        switch tour.stage {
        case .tasks: .tasks
        case .anchoring: .anchoring
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
            bubble(below: hole.rect.midY < size.height * 0.5, hole: hole.rect, in: size)
                .allowsHitTesting(false)
        }
        // At the button, only the button itself answers; elsewhere a tap
        // sends a ripple toward it. The first two stops take taps in `TourTapLayer`.
        .contentShape(veil, eoFill: true)
        .onTapGesture { nudges += 1 }
        .allowsHitTesting(isButton)
    }

    private func bubble(below: Bool, hole: CGRect, in size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(line)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .fixedSize(horizontal: false, vertical: true)
            if tour.stage != .anchorButton {
                Text(TourCopy.tapToContinue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.action)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: min(330, size.width - 48), alignment: .leading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 18, style: .continuous))
        .shadow(color: AnchorPalette.deepSea.opacity(0.22), radius: 18, y: 8)
        .id(tour.stage)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: below ? -6 : 6)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: below ? .top : .bottom)
        .padding(below ? .top : .bottom, below ? hole.maxY + 14 : size.height - hole.minY + 14)
        .accessibilityHidden(tour.stage != .anchorButton)
    }

    private var line: String {
        switch tour.stage {
        case .tasks: TourCopy.tasks
        case .anchoring: TourCopy.anchoring
        default: TourCopy.anchorButton
        }
    }

    /// The home darkens a little, never so much that it stops reading as itself.
    static let dim = AnchorPalette.deepSea.opacity(0.36)
}

/// Takes a tap anywhere on the stops that move on with a tap: the first two
/// on the home, both on the desk. It sits apart from the coach, which is
/// rebuilt each time the clock ticks, so no tap is lost.
struct TourTapLayer: View {
    let tour: AnchorTour

    var body: some View {
        if let line {
            Color.clear
                .contentShape(.rect)
                .ignoresSafeArea()
                .onTapGesture { tour.next() }
                .accessibilityElement()
                .accessibilityLabel(line)
                .accessibilityHint(TourCopy.tapToContinue)
                .accessibilityAddTraits(.isButton)
        }
    }

    private var line: String? {
        switch tour.stage {
        case .tasks: TourCopy.tasks
        case .anchoring: TourCopy.anchoring
        case .desk: TourCopy.folders
        case .waiting: TourCopy.waiting
        default: nil
        }
    }
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

// MARK: Turning

/// After the drop: the home softens, and a phone outline turns on its side
/// above one line saying what waits there. If the screen cannot turn, a
/// quiet line says why and offers the desk here instead.
struct TourTurnPrompt: View {
    let gravity: DeviceGravityMonitor
    let onSideways: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var waited = false

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)
            TourPhoneTurn()
                .frame(width: 150, height: 150)
            Text(TourCopy.turn)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AnchorIOSStyle.text)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 290)
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
    let onBack: () -> Void

    @State private var wasSideways = false

    var body: some View {
        GeometryReader { geometry in
            LandscapeAmbientDashboard(projection: projection, playsArrival: true, onTask: { _ in }, onManage: {})
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
    /// The tour's light and taps over the desk, wherever the desk is drawn.
    @ViewBuilder
    func tourDeskCoach(_ tour: AnchorTour?) -> some View {
        if let tour {
            overlayPreferenceValue(TourSpotKey.self) { anchors in
                GeometryReader { proxy in
                    TourDeskCoach(tour: tour, spots: anchors.mapValues { proxy[$0] }, size: proxy.size)
                }
                .ignoresSafeArea()
            }
            .overlay { TourTapLayer(tour: tour) }
        } else {
            self
        }
    }
}

/// The tour on the real desk. The light passes over each folder, then holds
/// them all; then it settles on the homework's front card as its question
/// arrives. Last, a friend calls the person away.
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

    private func spotlight(_ hole: Hole) -> some View {
        ZStack(alignment: .topLeading) {
            SpotlightVeil(hole: hole.rect, radius: hole.radius)
                .fill(TourCoach.dim, style: FillStyle(eoFill: true))
            RoundedRectangle(cornerRadius: hole.radius, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                .shadow(color: AnchorIOSStyle.action.opacity(0.45), radius: 10)
                .frame(width: hole.rect.width, height: hole.rect.height)
                .offset(x: hole.rect.minX, y: hole.rect.minY)
            if tour.stage == .waiting || holdsAll {
                bubble(beside: hole.rect)
            }
        }
        .allowsHitTesting(false)
    }

    /// The line beside the light, on whichever side has more room.
    private func bubble(beside hole: CGRect) -> some View {
        let gap: CGFloat = 14
        // The Dynamic Island takes one edge when the phone lies sideways.
        let edge: CGFloat = 58
        let leftRoom = hole.minX - gap - edge
        let rightRoom = size.width - hole.maxX - gap - edge
        let onLeft = leftRoom >= rightRoom
        let width = min(280, max(onLeft ? leftRoom : rightRoom, 150))
        let x = onLeft ? hole.minX - gap - width / 2 : hole.maxX + gap + width / 2
        return TourLine(text: tour.stage == .waiting ? TourCopy.waiting : TourCopy.folders, hint: TourCopy.tapToContinue)
            .frame(width: width)
            .id(tour.stage)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(x: onLeft ? 8 : -8)))
            .position(x: x, y: min(max(hole.midY, 90), size.height - 90))
            .accessibilityHidden(true)
    }
}

/// One short line on a light card, with how to move on under it.
private struct TourLine: View {
    let text: String
    var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(text)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .fixedSize(horizontal: false, vertical: true)
            if let hint {
                Text(hint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.action)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 18, style: .continuous))
        .shadow(color: AnchorPalette.deepSea.opacity(0.22), radius: 18, y: 8)
    }
}

/// A friend asks the person down for coffee: the desk softens, and a phone
/// outline comes up off its side beside the one line. Picking the phone up
/// is how they go; the desk under it waits.
private struct TourCalledAway: View {
    var body: some View {
        HStack(spacing: 28) {
            TourPhoneTurn(upright: true)
                .frame(width: 130, height: 130)
            Text(TourCopy.called)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.heading)
                .lineSpacing(3)
                .frame(maxWidth: 300, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnchorIOSStyle.canvasTop.opacity(0.84))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Away and back

/// The Bluetooth link to the Mac, drawn as a laptop and a phone joined by a
/// line. Walking away, the phone drifts off, the line stretches and breaks,
/// and five minutes pass while the laptop's dots keep working. Coming back,
/// the phone drifts home and the line joins again.
struct TourLinkScene: View {
    enum Mode { case apart, together }

    let mode: Mode

    /// Walking away: when the line breaks, and when the away screen takes over.
    static let breaksAt: TimeInterval = 2.5
    static let apartLength: TimeInterval = 4.8
    /// Coming back: the whole scene.
    static let togetherLength: TimeInterval = 1.9
    /// Coming back: when the line joins.
    private static let joinsAt: TimeInterval = 1.2
    /// Walking away waits this long first, while the anchor is weighed on the home.
    private static let weighs: TimeInterval = 1.0

    @AnchorReducedMotion private var reduceMotion
    @State private var start = Date.now
    @State private var links = 0

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? (mode == .apart ? Self.apartLength : Self.togetherLength)
                : context.date.timeIntervalSince(start)
            ZStack {
                LinearGradient(colors: [AnchorIOSStyle.canvasTop, AnchorIOSStyle.canvasTop.opacity(0.94)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                scene(at: t)
            }
            .opacity(opacity(at: t))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .sensoryFeedback(mode == .apart ? .impact(weight: .light, intensity: 0.6) : .success, trigger: links)
        .task {
            start = .now
            try? await Task.sleep(for: .seconds(mode == .apart ? Self.breaksAt : Self.joinsAt))
            links += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .apart ? TourCopy.apart : TourCopy.together)
    }

    private func opacity(at t: TimeInterval) -> Double {
        switch mode {
        case .apart: min(1, max(0, (t - Self.weighs) / 0.35))
        case .together: min(1, t / 0.3)
        }
    }

    /// How far the phone has drifted from the laptop, 0 to 1.
    private func drift(at t: TimeInterval) -> Double {
        switch mode {
        case .apart:
            let p = min(1, max(0, (t - Self.weighs - 0.35) / (Self.breaksAt - Self.weighs - 0.35)))
            return p * p * (3 - 2 * p)
        case .together:
            let p = min(1, max(0, (t - 0.3) / (Self.joinsAt - 0.3)))
            return 1 - p * p * (3 - 2 * p)
        }
    }

    private func isLinked(at t: TimeInterval) -> Bool {
        mode == .apart ? t < Self.breaksAt : t >= Self.joinsAt
    }

    private func scene(at t: TimeInterval) -> some View {
        let drift = drift(at: t)
        let mac = CGPoint(x: 70, y: 70)
        let phone = CGPoint(x: 196 + 70 * drift, y: 74 + 14 * drift)
        let lineStart = CGPoint(x: mac.x + 46, y: mac.y)
        let lineEnd = CGPoint(x: phone.x - 19, y: phone.y)
        return VStack(spacing: 22) {
            ZStack {
                link(from: lineStart, to: lineEnd, at: t)
                laptop(at: t).position(mac)
                phoneOutline.position(phone)
            }
            .frame(width: 300, height: 140)
            VStack(spacing: 14) {
                if mode == .apart { clock(at: t) }
                Text(mode == .apart ? TourCopy.apart : TourCopy.together)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 290)
                    .opacity(captionOpacity(at: t))
            }
            .frame(height: 110, alignment: .top)
        }
    }

    private func captionOpacity(at t: TimeInterval) -> Double {
        let from = mode == .apart ? Self.breaksAt + 0.1 : Self.joinsAt
        return min(1, max(0, (t - from) / 0.3))
    }

    /// The link: a dashed line with data moving along it while joined. When
    /// it breaks, each half pulls back toward its own end and fades.
    @ViewBuilder
    private func link(from a: CGPoint, to b: CGPoint, at t: TimeInterval) -> some View {
        let tint = AnchorIOSStyle.action
        if isLinked(at: t) {
            let pulse = mode == .together ? max(0, 1 - (t - Self.joinsAt) / 0.5) : 0
            Path { path in
                path.move(to: a)
                path.addLine(to: b)
            }
            .stroke(tint.opacity(0.75), style: StrokeStyle(lineWidth: 2 + 2 * pulse, lineCap: .round,
                                                           dash: [5, 6], dashPhase: -t * 22))
        } else if mode == .apart {
            let p = min(1, (t - Self.breaksAt) / 0.4)
            let middle = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            Path { path in
                path.move(to: a)
                path.addLine(to: CGPoint(x: middle.x - (middle.x - a.x) * p - 6, y: middle.y - (middle.y - a.y) * p))
                path.move(to: b)
                path.addLine(to: CGPoint(x: middle.x + (b.x - middle.x) * p + 6, y: middle.y + (b.y - middle.y) * p))
            }
            .stroke(tint.opacity(0.75 * (1 - p)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 6]))
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

    /// Five minutes going by once the line breaks: a ring filling and the time counting up.
    private func clock(at t: TimeInterval) -> some View {
        let p = min(1, max(0, (t - Self.breaksAt) / 1.4))
        let seconds = Int((p * 300).rounded())
        return HStack(spacing: 8) {
            ZStack {
                Circle().stroke(AnchorIOSStyle.action.opacity(0.18), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: p)
                    .stroke(AnchorIOSStyle.action, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AnchorIOSStyle.heading)
        }
        .opacity(t >= Self.breaksAt ? 1 : 0)
    }
}
#endif
