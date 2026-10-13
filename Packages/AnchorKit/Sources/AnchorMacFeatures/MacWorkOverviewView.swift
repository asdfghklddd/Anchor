#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkOverviewView: View {
    let model: AnchorSessionModel
    let session: AnchorSession
    let onOpenProcess: (UUID) -> Void
    let onOpenTimeline: () -> Void
    var onOpenSettings: (() -> Void)?

    @AnchorReducedMotion private var reduceMotion
    @State private var showsRecentActivity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacMetrics.pageSpacing) {
                MacWorkHeaderView(
                    projection: model.projection,
                    onOpenSettings: onOpenSettings
                )
                .padding(.bottom, 2)

                if model.projection.hostedSessions.count > 1 {
                    MacHostedTaskLibrary(model: model, selectedSessionID: session.id)
                }

                if session.status == .completed {
                    MacCompletionBanner(
                        session: session,
                        onResume: resumeSession
                    )
                }

                if session.presence == .away || session.presence == .returning {
                    MacReturnMemoryView(
                        session: session,
                        projection: model.projection,
                        onOpenProcess: onOpenProcess,
                        onContinue: continueWorking
                    )
                } else if session.presence != .atDesk {
                    MacWorkPresenceBanner(
                        presence: session.presence,
                        summary: session.returnSummary,
                        onContinue: continueWorking
                    )
                }

                MacWorkGoalSummaryCard(
                    session: session,
                    progress: model.projection.overallProgress,
                    onOpenTimeline: onOpenTimeline
                )

                if session.status != .completed, showsPriorityAction {
                    MacPriorityCard(session: session, onOpenProcess: onOpenProcess)
                }

                MacWorkProcessList(
                    processes: session.processes,
                    onOpenProcess: onOpenProcess,
                    onOpenSources: onOpenSettings
                )

                recentActivity
            }
            .frame(maxWidth: MacMetrics.contentWidth, alignment: .leading)
            .padding(.horizontal, MacMetrics.pageInset)
            .padding(.bottom, MacMetrics.pageInset)
        }
        .background(.clear)
        .navigationTitle("")
        .accessibilityIdentifier("mac.current.screen")
    }

    /// Collapsed by default and never opened by background events (D09); the header
    /// row is the disclosure control, and the full timeline stays one click away.
    private var recentActivity: some View {
        MacCard(insetContent: false) {
            VStack(spacing: 0) {
                HStack(spacing: AnchorSpacing.small) {
                    Button(action: toggleRecentActivity) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .rotationEffect(.degrees(showsRecentActivity ? 90 : 0))
                                .accessibilityHidden(true)
                            MacCardTitle(L10n.recentActivity, symbol: "waveform.path.ecg")
                            Spacer(minLength: 0)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(showsRecentActivity ? L10n.navigationExpanded : L10n.navigationCollapsed)
                    .accessibilityIdentifier("mac.current.recent-activity")

                    Button(L10n.timeline, systemImage: "arrow.right", action: onOpenTimeline)
                        .buttonStyle(.borderless)
                        .font(.callout)
                        .accessibilityIdentifier("mac.timeline.open")
                }
                .padding(.horizontal, MacMetrics.cardPadding)
                .padding(.vertical, 12)

                if showsRecentActivity {
                    MacEventStrip(
                        events: Array(session.timeline.prefix(5)),
                        processes: session.processes
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    private func toggleRecentActivity() {
        withAnimation(reduceMotion ? nil : AnchorMotion.panel) {
            showsRecentActivity.toggle()
        }
    }

    private var showsPriorityAction: Bool {
        !model.projection.openDecisions.isEmpty || session.processes.contains { process in
            process.requiresAttention
        }
    }

    private func continueWorking() {
        Task { await model.continueWorking() }
    }

    private func resumeSession() {
        Task { await model.send(.resumeSession) }
    }
}

struct MacHostedTaskLibrary: View {
    let model: AnchorSessionModel
    let selectedSessionID: UUID?

    var body: some View {
        MacCard(
            AnchorStrings.value("home.task.library", default: "Task library"),
            symbol: "square.grid.2x2"
        ) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Array(model.projection.hostedSessions.reversed())) { task in
                    MacHostedTaskTile(
                        task: task,
                        isSelected: task.id == selectedSessionID,
                        action: { Task { await model.selectHostedTask(task.id) } }
                    )
                }
            }
        }
        .accessibilityIdentifier("mac.hosted.task-library")
    }
}

private struct MacHostedTaskTile: View {
    let task: AnchorSession
    let isSelected: Bool
    let action: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var isHovering = false

    private var needsAttention: Bool {
        task.processes.contains(where: \.requiresAttention)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.goal.title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)
            .padding(10)
            .background(background, in: .rect(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? AnchorPalette.interaction : AnchorPalette.fluoriteBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(AnchorPressButtonStyle())
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : AnchorMotion.micro) { isHovering = hovering }
        }
        .help(task.goal.title)
        .accessibilityIdentifier("mac.hosted.task.\(task.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: Color {
        if isSelected { return AnchorPalette.softBlue.opacity(0.42) }
        return isHovering ? AnchorPalette.softBlue.opacity(0.22) : AnchorPalette.canvas.opacity(0.55)
    }

    private var statusText: String {
        if needsAttention { return MacWorkCopy.metricAttention }
        return task.status == .active ? MacWorkCopy.active : MacWorkCopy.draft
    }

    private var statusColor: Color {
        if needsAttention { return AnchorPalette.sand }
        return task.status == .active ? AnchorPalette.mintInk : AnchorPalette.secondaryInk
    }
}
#endif
