#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborMissionCard: View {
    let session: AnchorSession?
    let onEdit: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HarborHeroSurface(cornerRadius: 26) {
            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                            missionCopy
                            HarborMissionOrbit(processes: processes)
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        HStack(alignment: .top, spacing: AnchorSpacing.small) {
                            missionCopy
                            HarborMissionOrbit(processes: processes)
                        }
                    }
                }

                missionFlow
            }
            .padding(14)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 390 : 230)
    }

    private var missionCopy: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.currentAnchorMap)
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.oceanHighlight)
                    Text(session?.goal.title ?? L10n.emptyTitle)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .accessibilityIdentifier("goal.title")
                }
                Spacer(minLength: 0)
                Button(action: onEdit) {
                    Image(systemName: session == nil ? "plus" : "pencil")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(session == nil ? L10n.establishAnchor : L10n.editGoal)
                .accessibilityIdentifier("goal.edit.button")
            }

            Text(goalNote)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .accessibilityIdentifier("goal.note")

            HStack(alignment: .firstTextBaseline) {
                Label(L10n.routesRunning(runningCount), systemImage: "circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.oceanHighlight)
                Spacer(minLength: 6)
                Text(overallProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.title.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.warmYellow)
            }

            HStack(spacing: AnchorSpacing.medium) {
                Label(L10n.startedAt(startTime), systemImage: "timer")
                    .accessibilityIdentifier("mission.metadata")
                Label(L10n.anchoredCount(anchorCount), systemImage: "mappin")
                    .accessibilityIdentifier("mission.metadata")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.90))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missionFlow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(L10n.processFlow)
                    .accessibilityIdentifier("mission.flow.label")
                Spacer()
                Text(session == nil ? "—" : L10n.parallelEfficiency)
                    .bold()
                    .accessibilityIdentifier("mission.flow.efficiency")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.90))

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 5
            ) {
                ForEach(processes.prefix(4)) { process in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AnchorPalette.sourceMark(process.sourceTone))
                            .frame(width: 19, height: 19)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(.white.opacity(0.42), lineWidth: 1)
                            }
                            .accessibilityHidden(true)
                            .accessibilityIdentifier("mission.flow.source")
                        GeometryReader { proxy in
                            Capsule()
                                .fill(.white.opacity(0.08))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(AnchorPalette.source(process.sourceTone))
                                        .frame(width: proxy.size.width * (process.progress ?? 0))
                                }
                        }
                        .frame(height: 8)
                        Text(process.progress ?? 0, format: .percent.precision(.fractionLength(0)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 29, alignment: .trailing)
                            .accessibilityIdentifier("mission.flow.progress")
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityRespondsToUserInteraction(false)
        .accessibilityLabel(L10n.overallProgress)
        .accessibilityValue(Text(overallProgress, format: .percent.precision(.fractionLength(0))))
        .accessibilityIdentifier("mission.flow.summary")
    }

    private var runningCount: Int {
        processes.lazy.filter { $0.status == .running }.count
    }

    private var overallProgress: Double {
        let values = processes.compactMap(\.progress)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
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
