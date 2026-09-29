#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkGoalSummaryCard: View {
    let session: AnchorSession
    let progress: Double?
    let onOpenTimeline: () -> Void

    private var attentionCount: Int {
        session.processes.filter { $0.status == .needsDecision }.count
    }

    var body: some View {
        AnchorCard(tint: attentionCount > 0 ? AnchorPalette.sand : AnchorPalette.aiBlue) {
            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        cardTitle
                        Spacer(minLength: AnchorSpacing.medium)
                        timelineButton
                    }
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        cardTitle
                        timelineButton
                    }
                }
                HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                    AnchorMark(size: 52)
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.small) {
                                goalTitle
                                sessionStatus
                            }
                            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                                goalTitle
                                sessionStatus
                            }
                        }
                        if !session.goal.completionCriteria.isEmpty {
                            Text(session.goal.completionCriteria)
                                .font(.callout)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        progressSummary
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityIdentifier("mac.current.goal-summary")
    }

    private var goalTitle: some View {
        Text(session.goal.title)
            .font(.title2.bold())
            .foregroundStyle(AnchorPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var sessionStatus: some View {
        // Session completion is explicit; process averages never imply goal acceptance.
        Text(statusLabel)
            .font(.caption.bold())
            .foregroundStyle(AnchorPalette.interaction)
            .padding(.horizontal, AnchorSpacing.small)
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

    private var cardTitle: some View {
        Label(L10n.currentWork, systemImage: "scope")
            .font(.callout.bold())
            .foregroundStyle(AnchorPalette.interaction)
    }

    private var timelineButton: some View {
        Button(L10n.viewFullTimeline, systemImage: "arrow.right", action: onOpenTimeline)
            .buttonStyle(.borderless)
            .font(.callout)
    }

    private var progressSummary: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            // Missing progress stays unknown; it must not look like measured zero progress.
            if let progress {
                ProgressView(value: progress, total: 1) {
                    Text(MacWorkCopy.reportedProgress)
                } currentValueLabel: {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                }
                .tint(AnchorPalette.interaction)
            } else {
                Label(MacWorkCopy.progressUnavailable, systemImage: "minus.circle")
            }
        }
        .font(.caption)
        .foregroundStyle(AnchorPalette.secondaryInk)
    }
}
#endif
