#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacCodexCandidateList: View {
    let candidates: [CodexTaskCandidate]
    let isTracking: (CodexTaskCandidate) -> Bool
    let onTrack: (CodexTaskCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.sourceSetupCodexRecentTasks)
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                Text(L10n.sourceSetupCodexRecentTasksDetail)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(candidates) { candidate in
                candidateRow(candidate)
            }
        }
        .padding(.leading, 52)
        .accessibilityIdentifier("mac.sources.setup.codex.candidates")
    }

    private func candidateRow(_ candidate: CodexTaskCandidate) -> some View {
        let tracking = isTracking(candidate)
        return HStack(alignment: .center, spacing: AnchorSpacing.small) {
            Image(systemName: activitySymbol(candidate.activity))
                .foregroundStyle(activityTint(candidate.activity))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.workspaceName ?? L10n.sourceSetupCodex)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AnchorPalette.ink)
                Text(candidate.modifiedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(activityLabel(candidate.activity))

            Spacer(minLength: AnchorSpacing.small)

            Text(activityLabel(candidate.activity))
                .font(.caption.weight(.semibold))
                .foregroundStyle(activityTint(candidate.activity))

            Button(tracking ? L10n.sourceSetupCodexTracked : L10n.sourceSetupCodexTrack) {
                onTrack(candidate)
            }
            .disabled(tracking)
            .controlSize(.large)
            .accessibilityIdentifier("mac.sources.setup.codex.track.\(candidate.id)")
        }
        .padding(AnchorSpacing.small)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 14, style: .continuous))
    }

    private func activityLabel(_ activity: CodexTaskActivity) -> String {
        switch activity {
        case .running: L10n.sourceSetupTaskRunning
        case .completed: L10n.sourceSetupTaskCompleted
        case .interrupted: L10n.sourceSetupTaskInterrupted
        case .unknown: L10n.unknown
        }
    }

    private func activitySymbol(_ activity: CodexTaskActivity) -> String {
        switch activity {
        case .running: "circle.fill"
        case .completed: "checkmark.circle.fill"
        case .interrupted: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func activityTint(_ activity: CodexTaskActivity) -> Color {
        switch activity {
        case .running: AnchorPalette.mintInk
        case .completed: AnchorPalette.link
        case .interrupted: AnchorPalette.sourceInk("coral")
        case .unknown: AnchorPalette.secondaryInk
        }
    }
}
#endif
