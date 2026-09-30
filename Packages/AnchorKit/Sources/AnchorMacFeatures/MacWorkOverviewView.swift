#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkOverviewView: View {
    let model: AnchorSessionModel
    let session: AnchorSession
    let onOpenProcess: (UUID) -> Void
    let onOpenTimeline: () -> Void

    @State private var showsRecentActivity = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.xLarge) {
                MacWorkHeaderView(
                    projection: model.projection
                )

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
                    onOpenProcess: onOpenProcess
                )

                DisclosureGroup(L10n.recentActivity, isExpanded: $showsRecentActivity) {
                    MacEventStrip(
                        events: Array(session.timeline.prefix(5)),
                        processes: session.processes,
                        onOpenTimeline: onOpenTimeline
                    )
                    .padding(.top, AnchorSpacing.small)
                }
                .font(.callout)
                .accessibilityIdentifier("mac.current.recent-activity")
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(.horizontal, AnchorSpacing.xLarge)
            .padding(.vertical, AnchorSpacing.large)
        }
        .background(.clear)
        .navigationTitle("")
        .accessibilityIdentifier("mac.current.screen")
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
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(AnchorStrings.value("home.task.library", default: "Task library"))
                .font(.headline)
                .foregroundStyle(AnchorPalette.brandDeep)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Array(model.projection.hostedSessions.reversed())) { task in
                    let isSelected = task.id == selectedSessionID
                    Button {
                        Task { await model.selectHostedTask(task.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.goal.title)
                                .font(.callout.weight(isSelected ? .semibold : .medium))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(task.status == .active ? MacWorkCopy.active : MacWorkCopy.draft)
                                .font(.caption)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                        .padding(12)
                        .background(
                            isSelected ? AnchorPalette.softBlue.opacity(0.5) : AnchorPalette.fluoriteSurface,
                            in: .rect(cornerRadius: 14)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? AnchorPalette.interaction : AnchorPalette.fluoriteBorder, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mac.hosted.task.\(task.id)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .accessibilityIdentifier("mac.hosted.task-library")
    }
}
#endif
