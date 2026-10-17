#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkOverviewView: View {
    let model: AnchorSessionModel
    let session: AnchorSession
    /// Every recent Codex conversation; `nil` until Codex is connected.
    var conversations: [CodexConversationSummary]?
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

                MacGlanceCard(
                    tasks: model.projection.hostedSessions,
                    connection: model.projection.connection,
                    selectedTaskID: session.id,
                    onSelectTask: { id in Task { await model.selectHostedTask(id) } }
                )

                if let conversations {
                    MacCodexConversationsCard(conversations: conversations)
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
#endif
