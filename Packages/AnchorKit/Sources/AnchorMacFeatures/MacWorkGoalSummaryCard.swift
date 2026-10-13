#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkGoalSummaryCard: View {
    let session: AnchorSession
    let progress: Double?
    let onOpenTimeline: () -> Void

    @AnchorReducedMotion private var reduceMotion

    private var attentionCount: Int {
        session.processes.filter(\.requiresAttention).count
    }

    private var runningCount: Int {
        session.processes.filter { $0.status == .running }.count
    }

    private var completedCount: Int {
        session.processes.filter { $0.status == .completed }.count
    }

    var body: some View {
        MacCard(
            L10n.currentWork,
            symbol: "scope",
            tint: attentionCount > 0 ? AnchorPalette.sand : nil,
            accessory: { timelineButton }
        ) {
            // Goal on the left, the numbers that answer "how is it going" on the right.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: AnchorSpacing.large) {
                    goal
                    Spacer(minLength: 0)
                    metrics
                }
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    goal
                    metrics
                }
            }
        }
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: [runningCount, attentionCount, completedCount])
        .accessibilityIdentifier("mac.current.goal-summary")
    }

    private var goal: some View {
        HStack(alignment: .top, spacing: 14) {
            AnchorMark(size: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.small) {
                    Text(session.goal.title)
                        .font(.title3.bold())
                        .foregroundStyle(AnchorPalette.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    sessionStatus
                }
                if !session.goal.completionCriteria.isEmpty {
                    Text(session.goal.completionCriteria)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(session.goal.completionCriteria)
                }
                progressSummary
                    .padding(.top, 2)
            }
            .frame(minWidth: 260, alignment: .leading)
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            MacStatTile(
                value: "\(runningCount)",
                label: MacWorkCopy.metricRunning,
                symbol: "circle.dotted",
                tint: AnchorPalette.interaction,
                emphasized: runningCount > 0
            )
            MacStatTile(
                value: "\(attentionCount)",
                label: MacWorkCopy.metricAttention,
                symbol: "exclamationmark.circle.fill",
                tint: AnchorPalette.sourceInk("sand"),
                emphasized: attentionCount > 0
            )
            MacStatTile(
                value: "\(completedCount)",
                label: MacWorkCopy.metricDone,
                symbol: "checkmark.circle.fill",
                tint: AnchorPalette.mintInk,
                emphasized: false
            )
        }
        .fixedSize()
    }

    private var sessionStatus: some View {
        // Session completion is explicit; process averages never imply goal acceptance.
        Text(statusLabel)
            .font(.caption.bold())
            .foregroundStyle(AnchorPalette.interaction)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AnchorPalette.softBlue.opacity(0.34), in: .capsule)
            .fixedSize()
    }

    private var statusLabel: String {
        switch session.status {
        case .draft: MacWorkCopy.draft
        case .active: MacWorkCopy.active
        case .completed: MacWorkCopy.completed
        case .archived: MacWorkCopy.archived
        }
    }

    private var timelineButton: some View {
        Button(L10n.viewFullTimeline, systemImage: "arrow.right", action: onOpenTimeline)
            .buttonStyle(.borderless)
            .font(.callout)
    }

    @ViewBuilder
    private var progressSummary: some View {
        // Missing progress stays unknown; it must not look like measured zero progress.
        if let progress {
            HStack(spacing: AnchorSpacing.small) {
                ProgressView(value: progress, total: 1)
                    .tint(AnchorPalette.interaction)
                    .frame(maxWidth: 220)
                    .accessibilityLabel(MacWorkCopy.reportedProgress)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AnchorPalette.ink)
            }
            .help(MacWorkCopy.reportedProgress)
        } else {
            Label(MacWorkCopy.progressUnavailable, systemImage: "minus.circle")
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
        }
    }
}
#endif
