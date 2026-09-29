#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborMissionCard: View {
    let session: AnchorSession?
    let availability: ProjectionAvailability
    let onEdit: () -> Void
    let onFinish: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Anchors")
                    .font(.headline.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .accessibilityIdentifier("workspace.screen")
                Spacer(minLength: 0)
                Button(action: onEdit) {
                    Image(systemName: session == nil ? "plus" : "pencil")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(session == nil ? L10n.establishAnchor : L10n.editGoal)
                .accessibilityIdentifier("goal.edit.button")
                if session != nil {
                    Button(action: onFinish) {
                        Image(systemName: "checkmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(L10n.finish)
                    .accessibilityIdentifier("mission.finish.button")
                }
            }
            .font(.subheadline)
            .tint(AnchorIOSStyle.heading)
            .buttonStyle(AnchorPressButtonStyle())

            if !processes.isEmpty {
                HomeAnchorChart(tasks: session.map { [$0] } ?? [])
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session?.goal.title ?? L10n.emptyTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(AnchorIOSStyle.heading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .accessibilityIdentifier("goal.title")
                Text(goalNote)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .accessibilityIdentifier("goal.note")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { missionMetadata }
                VStack(alignment: .leading, spacing: 6) { missionMetadata }
            }
            .font(.caption2)
            .foregroundStyle(AnchorPalette.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 16))
        .shadow(color: AnchorIOSStyle.heading.opacity(0.06), radius: 14, y: 6)
    }

    @ViewBuilder
    private var missionMetadata: some View {
        Label(routesSummary, systemImage: availability.isLive ? "waveform.path.ecg" : "clock")
            .accessibilityIdentifier("mission.flow.summary")
        Label(L10n.startedAt(startTime), systemImage: "timer")
            .accessibilityIdentifier("mission.metadata")
        Label(L10n.anchoredCount(anchorCount), systemImage: "mappin")
            .accessibilityIdentifier("mission.metadata")
    }

    private var runningCount: Int {
        processes.lazy.filter { $0.status == .running }.count
    }

    private var routesSummary: String {
        let summary = L10n.routesRunning(runningCount)
        return availability.isLive ? summary : "\(L10n.currentSnapshot) · \(summary)"
    }

    private var goalNote: String {
        guard let goal = session?.goal else { return L10n.emptyDetail }
        return goal.note.isEmpty ? goal.completionCriteria : goal.note
    }

    private var startTime: String {
        session?.startedAt.formatted(date: .omitted, time: .shortened) ?? "—"
    }

    private var processes: [AnchorProcess] {
        session?.taskProcesses ?? []
    }

    private var anchorCount: Int {
        session.map { max(1, $0.notes.count) } ?? 0
    }
}
#endif
