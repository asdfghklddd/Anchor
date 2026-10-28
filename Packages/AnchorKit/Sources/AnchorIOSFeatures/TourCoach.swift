#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

// MARK: Spots

/// The parts of the real home the tour lights, in the order it lights them.
enum TourSpot: Hashable {
    case tasks, anchoring, anchorButton
}

struct TourSpotKey: PreferenceKey {
    static let defaultValue: [TourSpot: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourSpot: Anchor<CGRect>], nextValue: () -> [TourSpot: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks a part of the home the tour can light.
    func tourSpot(_ spot: TourSpot) -> some View {
        anchorPreference(key: TourSpotKey.self, value: .bounds) { [spot: $0] }
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
            case .setup, .desk, .leaving, .finished:
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
    private static let dim = AnchorPalette.deepSea.opacity(0.36)
}

/// Takes a tap anywhere on the first two stops. It sits apart from the coach,
/// which is rebuilt each time the home's clock ticks, so no tap is lost.
struct TourTapLayer: View {
    let tour: AnchorTour

    var body: some View {
        if tour.stage < .anchorButton {
            Color.clear
                .contentShape(.rect)
                .ignoresSafeArea()
                .onTapGesture { tour.next() }
                .accessibilityElement()
                .accessibilityLabel(tour.stage == .tasks ? TourCopy.tasks : TourCopy.anchoring)
                .accessibilityHint(TourCopy.tapToContinue)
                .accessibilityAddTraits(.isButton)
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
/// again, over a dashed wake showing the way it turns.
private struct TourPhoneTurn: View {
    @AnchorReducedMotion private var reduceMotion

    private struct Turn {
        var angle = 0.0
        var opacity = 0.0
    }

    var body: some View {
        ZStack {
            wake
            if reduceMotion {
                phone.rotationEffect(.degrees(-90))
            } else {
                KeyframeAnimator(initialValue: Turn(), repeating: true) { turn in
                    phone
                        .rotationEffect(.degrees(turn.angle))
                        .opacity(turn.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.angle) {
                        LinearKeyframe(0, duration: 0.7)
                        CubicKeyframe(-90, duration: 0.9)
                        LinearKeyframe(-90, duration: 1.25)
                        LinearKeyframe(0, duration: 0.01)
                        LinearKeyframe(0, duration: 0.34)
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
    let projection: SessionProjection
    let gravity: DeviceGravityMonitor
    let onBack: () -> Void

    @State private var wasSideways = false

    var body: some View {
        GeometryReader { geometry in
            LandscapeAmbientDashboard(projection: projection, playsArrival: true, onTask: { _ in }, onManage: {})
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
#endif
