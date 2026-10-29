#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct PortraitDashboard: View {
    let projection: SessionProjection
    let auxiliaryToolbarLabel: String?
    let auxiliaryToolbarAction: (() -> Void)?
    let transitionNamespace: Namespace.ID
    let onRoute: (AnchorRoute) -> Void
    let onSheet: (AnchorSheet) -> Void
    let onTask: (UUID) -> Void
    /// The wordless invitation to turn into the landscape work desk, if any.
    var invitation: WorkInvitationHarbor.Mode? = nil
    var onInvitationEnd: () -> Void = {}
    var anchorDrops = 0
    var anchorWeighs = 0
    var gravity = DeviceGravityMonitor()
    /// The task just anchored, floating until its anchor catches.
    var settlingTaskID: UUID? = nil
    /// The task whose anchor last caught, and a count that changes each time.
    var settledTaskID: UUID? = nil
    var anchorSettles = 0
    /// A fourth anchor was asked for: the note above the anchor button says why not.
    var showsCapNote = false
    var onCapNoteDismiss: () -> Void = {}
    var onCompleteTask: (UUID) async -> Bool = { _ in false }
    /// Today's anchoring and tokens; the tour brings a day of its own.
    var log: AnchoringLog = .shared
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        ZStack {
            HomeWater()
            ScrollView {
                VStack(spacing: 0) {
                    HomeGreeting(tasks: projection.hostedSessions, log: log)
                        .padding(.leading, 24)
                        .padding(.top, 17)
                    VStack(spacing: 0) {
                        HomeAnchoringPanel(log: log)
                            .padding(.top, 30)
                        tasks
                            .tourSpot(.tasks)
                            .padding(.horizontal, 22)
                            .padding(.top, 30)
                    }
                    .frame(maxWidth: .infinity)
                    .background(alignment: .top) { HomeDome() }
                    .padding(.top, 21)
                }
                .padding(.bottom, 12)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // The mockup's water runs clean under the bars; nothing frosts it.
            .scrollEdgeEffectHidden(true, for: .all)
            .accessibilityIdentifier("workspace.screen")
            if let invitation {
                // Behind the anchor button, which floats on the water.
                VStack {
                    Spacer()
                    WorkInvitationHarbor(mode: invitation, gravity: gravity, onEnd: onInvitationEnd)
                        .id(invitation)
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.opacity)
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            HarborTopBar(connection: projection.connection,
                auxiliaryLabel: auxiliaryToolbarLabel, onProfile: { onRoute(.profile) },
                onSettings: { onSheet(.account) }, onAuxiliary: auxiliaryToolbarAction,
                onConnection: { onSheet(.connections) }, freshness: projection.freshness)
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                if showsCapNote {
                    HomeTaskCapNote(onDismiss: onCapNoteDismiss)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                }
                HarborAnchorButton(
                    isInviting: invitation == .inviting,
                    drops: anchorDrops,
                    weighs: anchorWeighs,
                    gravity: gravity,
                    action: { onSheet(.setup) }
                )
                .tourSpot(.anchorButton)
            }
            .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: showsCapNote)
            // The mockup sets the button lower, over the home indicator's band.
            .padding(.top, 8).padding(.bottom, -15)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: showsCapNote) {
            guard showsCapNote else { return }
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { onCapNoteDismiss() }
        }
    }

    private var tasks: some View {
        HomeTaskLibrary(tasks: projection.hostedSessions,
                        settlingTaskID: settlingTaskID, settledTaskID: settledTaskID, anchorSettles: anchorSettles,
                        onComplete: onCompleteTask)
    }
}

/// A new task's card in the moment after its anchor drops: lifted and pale while
/// the anchor falls, then settled with one ring of its color as the anchor catches.
struct DropSettle: ViewModifier {
    let floating: Bool
    let settles: Int
    let isSettled: Bool
    let tint: Color
    let reduceMotion: Bool
    var cornerRadius = AnchorIOSStyle.cardRadius

    func body(content: Content) -> some View {
        content
            .opacity(floating ? 0.55 : 1)
            .scaleEffect(floating && !reduceMotion ? 0.97 : 1)
            .offset(y: floating && !reduceMotion ? -10 : 0)
            .keyframeAnimator(initialValue: 0.0, trigger: settles) { content, ring in
                content.overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(tint, lineWidth: 2.5)
                        .opacity(isSettled ? ring : 0)
                        .allowsHitTesting(false)
                }
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(1.0)
                    LinearKeyframe(1.0, duration: 0.25)
                    LinearKeyframe(0.0, duration: 0.9, timingCurve: .easeIn)
                }
            }
    }
}

func eventSymbol(_ kind: ProcessEventKind) -> String {
    switch kind {
    case .created: "plus"
    case .progress: "arrow.up.right"
    case .outputReady: "sparkles"
    case .decisionRequired: "exclamationmark.bubble.fill"
    case .decisionResolved: "checkmark.bubble.fill"
    case .completed: "checkmark.circle.fill"
    case .failed: "xmark.octagon.fill"
    case .note: "bookmark.fill"
    case .presence: "person.wave.2.fill"
    case .connection: "network"
    }
}
#endif
