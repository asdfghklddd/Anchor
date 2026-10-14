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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        ZStack {
            HarborBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HomeTideCard(tasks: projection.hostedSessions, connection: projection.connection, onTask: onTask)
                    HStack {
                        Text(AnchorStrings.value("home.task.library", default: "Task library"))
                            .font(.title2.bold()).foregroundStyle(AnchorIOSStyle.heading)
                        Spacer()
                        Button { onSheet(.hostedTasks) } label: {
                            HStack(spacing: 4) {
                                Circle().fill(projection.hostedSessions.isEmpty ? AnchorIOSStyle.border : AnchorIOSStyle.success)
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
                    } else {
                        taskGrid
                    }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
                .frame(maxWidth: 760).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            HarborTopBar(connection: projection.connection, unreadCount: projection.unreadNotificationsCount,
                auxiliaryLabel: auxiliaryToolbarLabel, onProfile: { onRoute(.profile) },
                onNotifications: { onSheet(.notifications) }, onAuxiliary: auxiliaryToolbarAction,
                onConnection: { onSheet(.connections) })
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
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

    private var taskGrid: some View {
        let tasks = projection.hostedSessions
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return HStack(alignment: .top, spacing: 10) {
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: 10) {
                    ForEach(Array(tasks.enumerated()).filter { $0.offset % columns == column }, id: \.element.id) { index, task in
                        Button { onTask(task.id) } label: {
                            HostedTaskCard(task: task, height: dynamicTypeSize.isAccessibilitySize ? 190 : (index % 4 == 0 || index % 4 == 3 ? 100 : 212))
                        }
                        .buttonStyle(AnchorPressButtonStyle())
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
