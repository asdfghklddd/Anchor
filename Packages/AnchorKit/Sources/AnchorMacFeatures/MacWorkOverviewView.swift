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
        .navigationTitle(L10n.currentWork)
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
#endif
