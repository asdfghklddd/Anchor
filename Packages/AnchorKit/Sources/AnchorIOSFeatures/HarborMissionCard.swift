#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborMissionCard: View {
    let session: AnchorSession?
    let onEdit: () -> Void
    let onFinish: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Label(L10n.currentAnchorMap, systemImage: "scope")
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                    .lineLimit(1)

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Button(action: onEdit) {
                        missionActionIcon(session == nil ? "plus" : "pencil")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(AnchorPalette.interaction)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel(session == nil ? L10n.establishAnchor : L10n.editGoal)
                    .accessibilityIdentifier("goal.edit.button")

                    if session != nil {
                        Button(action: onFinish) {
                            missionActionIcon("checkmark")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .tint(AnchorPalette.brandDeep)
                        .frame(width: 44, height: 44)
                        .accessibilityLabel(L10n.finish)
                        .accessibilityIdentifier("mission.finish.button")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(session?.goal.title ?? L10n.emptyTitle)
                    .font(.title2.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .accessibilityIdentifier("goal.title")

                Text(goalNote)
                    .font(.subheadline)
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("goal.note")
            }

            Label(taskStatus, systemImage: needsAttention ? "exclamationmark.bubble.fill" : "circle.fill")
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(
                    needsAttention ? AnchorPalette.attention.opacity(0.22) : AnchorPalette.softBlue.opacity(0.55),
                    in: .capsule
                )

            Divider().overlay(AnchorPalette.fluoriteBorder)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { missionMetadata }
                VStack(alignment: .leading, spacing: 8) { missionMetadata }
            }
            .font(.caption)
            .foregroundStyle(AnchorPalette.secondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluoriteSurface(
            border: needsAttention ? AnchorPalette.attention.opacity(0.48) : AnchorPalette.fluoriteBorder,
            cornerRadius: 18,
            elevated: true
        )
    }

    @ViewBuilder
    private var missionMetadata: some View {
        Label(L10n.routesRunning(runningCount), systemImage: "waveform.path.ecg")
            .accessibilityIdentifier("mission.flow.summary")
        Label(L10n.startedAt(startTime), systemImage: "timer")
            .accessibilityIdentifier("mission.metadata")
        Label(L10n.anchoredCount(anchorCount), systemImage: "mappin")
            .accessibilityIdentifier("mission.metadata")
    }

    private func missionActionIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.subheadline.bold())
            .frame(width: 18, height: 18)
    }

    private var runningCount: Int {
        processes.lazy.filter { $0.status == .running }.count
    }

    private var taskStatus: String {
        TaskStatusPresentation.text(for: session)
    }

    private var needsAttention: Bool {
        processes.contains { $0.status == .needsDecision || $0.status == .blocked }
    }

    private var goalNote: String {
        guard let goal = session?.goal else { return L10n.emptyDetail }
        return goal.note.isEmpty ? goal.completionCriteria : goal.note
    }

    private var startTime: String {
        session?.startedAt.formatted(date: .omitted, time: .shortened) ?? "—"
    }

    private var processes: [AnchorProcess] {
        session?.processes ?? []
    }

    private var anchorCount: Int {
        session.map { max(1, $0.notes.count) } ?? 0
    }
}
#endif
