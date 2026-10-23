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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        ZStack {
            HarborBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HomeTideCard(tasks: projection.hostedSessions, freshness: projection.freshness, onTask: onTask)
                    HStack {
                        Text(AnchorStrings.value("home.task.library", default: "Task library"))
                            .font(.title2.bold()).foregroundStyle(AnchorIOSStyle.heading)
                        Spacer()
                        Button { onSheet(.hostedTasks) } label: {
                            HStack(spacing: 4) {
                                // Neutral: green belongs to "done" (D02), and a count is not a state.
                                Circle().fill(AnchorIOSStyle.border)
                                .frame(width: 7, height: 7)
                                Text("\(projection.hostedSessions.count)")
                                HarborAnchorGlyph(color: AnchorIOSStyle.secondaryText, lineWidth: 1.2)
                                    .frame(width: 12, height: 12)
                            }
                            .font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
                            .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
                    }
                    .padding(.top, 20)
                    if projection.hostedSessions.isEmpty {
                        Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                            .font(.subheadline).foregroundStyle(AnchorIOSStyle.secondaryText)
                            .multilineTextAlignment(.center).padding(20)
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 16))
                            .accessibilityIdentifier("workspace.empty.processes")
                            // Fades as the first anchor drops, so the drop isn't fighting a jump.
                            .transition(.opacity)
                    } else {
                        // The first card's own drop choreography brings it in.
                        taskGrid.transition(.asymmetric(insertion: .identity, removal: .opacity))
                    }
                    let recap = TodayRecap(open: projection.hostedSessions, archived: projection.archivedSessions, now: .now)
                    if !recap.isEmpty {
                        TodayRecapCard(recap: recap, onTask: onTask)
                            .padding(.top, 16)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                    }
                }
                .animation(AnchorMotion.micro, value: projection.hostedSessions.isEmpty)
                .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: showsRecap)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            // Cards fade under the anchor button instead of meeting a hard band; the top
            // keeps the system's firmer edge, which keeps the name and link status readable.
            .scrollEdgeEffectStyle(.soft, for: .bottom)
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
                onConnection: { onSheet(.connections) })
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            HarborAnchorButton(
                isInviting: invitation == .inviting,
                drops: anchorDrops,
                weighs: anchorWeighs,
                gravity: gravity,
                action: { onSheet(.setup) }
            )
            .padding(.top, 8).padding(.bottom, 4)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// The day's recap shows once something happened today.
    private var showsRecap: Bool {
        !TodayRecap(open: projection.hostedSessions, archived: projection.archivedSessions, now: .now).isEmpty
    }

    private var taskGrid: some View {
        let tasks = projection.hostedSessions
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return HStack(alignment: .top, spacing: 10) {
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: 10) {
                    ForEach(Array(tasks.enumerated()).filter { $0.offset % columns == column }, id: \.element.id) { index, task in
                        Button { onTask(task.id) } label: {
                            HostedTaskCard(task: task, height: dynamicTypeSize.isAccessibilitySize ? 190 : (index % 4 == 0 || index % 4 == 3 ? 100 : 212),
                                           isCurrent: tasks.count > 1 && task.id == projection.session?.id)
                        }
                        .buttonStyle(AnchorPressButtonStyle())
                        .modifier(DropSettle(
                            floating: task.id == settlingTaskID, settles: anchorSettles,
                            isSettled: task.id == settledTaskID, tint: HostedTaskAppearance.tint(task),
                            reduceMotion: reduceMotion))
                        .accessibilityIdentifier("hosted.task.\(task.id)")
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
                    }
                }.frame(maxWidth: .infinity)
            }
        }
        // Only membership changes animate; ordinary refreshes keep cards still.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: tasks.map(\.id))
    }
}

/// A new task's card in the moment after its anchor drops: lifted and pale while
/// the anchor falls, then settled with one ring of its color as the anchor catches.
private struct DropSettle: ViewModifier {
    let floating: Bool
    let settles: Int
    let isSettled: Bool
    let tint: Color
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(floating ? 0.55 : 1)
            .scaleEffect(floating && !reduceMotion ? 0.97 : 1)
            .offset(y: floating && !reduceMotion ? -10 : 0)
            .keyframeAnimator(initialValue: 0.0, trigger: settles) { content, ring in
                content.overlay {
                    RoundedRectangle(cornerRadius: AnchorIOSStyle.cardRadius)
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
