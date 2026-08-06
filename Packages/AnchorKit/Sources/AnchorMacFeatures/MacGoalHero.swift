#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacGoalHero: View {
    let session: AnchorSession
    let progress: Double?

    private var runningCount: Int {
        session.processes.filter { $0.status == .running }.count
    }

    var body: some View {
        HarborHeroSurface {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AnchorSpacing.large) {
                        goalCopy
                        Spacer(minLength: AnchorSpacing.large)
                        MacAnchorMap(processes: session.processes, progress: progress)
                    }

                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        goalCopy
                        HStack {
                            Spacer(minLength: 0)
                            MacAnchorMap(processes: session.processes, progress: progress)
                            Spacer(minLength: 0)
                        }
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.16))

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: AnchorSpacing.large) {
                        heroMetrics
                        Spacer(minLength: AnchorSpacing.medium)
                        statusLabelView
                    }

                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        heroMetrics
                        statusLabelView
                    }
                }
            }
            .padding(AnchorSpacing.xLarge)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(L10n.currentAnchorMap), \(session.goal.title), \(progressLabel), \(statusLabel)")
        )
    }

    private var goalCopy: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(L10n.currentAnchorMap)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
                .textCase(.uppercase)
            Text(session.goal.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("mac.current.goal")
            Text(session.goal.completionCriteria)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            if !session.goal.note.isEmpty {
                Text(session.goal.note)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(4)
            }
        }
    }

    private var heroMetrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AnchorSpacing.large) {
                progressMetric
                routesMetric
                focusMetric
            }

            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                progressMetric
                routesMetric
                focusMetric
            }
        }
    }

    private var progressMetric: some View {
        MacHeroMetric(
            title: L10n.overallProgress,
            value: progressText,
            symbol: "chart.line.uptrend.xyaxis"
        )
    }

    private var routesMetric: some View {
        MacHeroMetric(
            title: L10n.routesRunning(runningCount),
            value: Text("\(runningCount)"),
            symbol: "point.3.connected.trianglepath.dotted"
        )
    }

    private var focusMetric: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            MacHeroMetric(
                title: L10n.focusTime,
                value: Text(L10n.focusDuration(focusMinutes(at: context.date))),
                symbol: "timer"
            )
        }
    }

    private var statusLabelView: some View {
        Label(statusLabel, systemImage: statusSymbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(statusTint)
    }

    private func focusMinutes(at date: Date) -> Int {
        max(0, Int(date.timeIntervalSince(session.startedAt) / 60))
    }

    private var progressLabel: String {
        guard let progress else { return L10n.unknown }
        return progress.formatted(.percent.precision(.fractionLength(0)))
    }

    private var progressText: Text {
        guard let progress else { return Text(L10n.unknown) }
        return Text(progress, format: .percent.precision(.fractionLength(0)))
    }

    private var statusLabel: String {
        switch session.status {
        case .completed, .archived: L10n.completed
        case .draft, .active: L10n.live
        }
    }

    private var statusSymbol: String {
        switch session.status {
        case .completed, .archived: "checkmark.seal.fill"
        case .draft, .active: "circle.fill"
        }
    }

    private var statusTint: Color {
        AnchorPalette.seafoam
    }
}

private struct MacHeroMetric: View {
    let title: String
    let value: Text
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                value
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.white)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
        } icon: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AnchorPalette.seafoam)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.10), in: .circle)
        }
    }
}

private struct MacAnchorMap: View {
    let processes: [AnchorProcess]
    let progress: Double?

    private let offsets: [CGSize] = [
        CGSize(width: -82, height: -58),
        CGSize(width: 82, height: -50),
        CGSize(width: -88, height: 58),
        CGSize(width: 88, height: 62),
    ]

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                .frame(width: 184, height: 184)
            Circle()
                .stroke(AnchorPalette.seafoam.opacity(0.24), lineWidth: 1)
                .frame(width: 124, height: 124)
            Circle()
                .fill(AnchorPalette.seafoam.opacity(0.08))
                .frame(width: 104, height: 104)

            ForEach(Array(processes.prefix(4).enumerated()), id: \.element.id) { index, process in
                VStack(spacing: 3) {
                    SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 34)
                    progressLabel(for: process)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.white.opacity(0.82))
                }
                .offset(offsets[index])
            }

            AnchorMark(size: 62)
            progressText
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(AnchorPalette.deepSea)
                .offset(y: 21)
        }
        .frame(width: 250, height: 190)
        .accessibilityHidden(true)
    }

    private func progressLabel(for process: AnchorProcess) -> Text {
        guard let progress = process.progress else {
            return Text(L10n.unknown)
        }
        return Text(progress, format: .percent.precision(.fractionLength(0)))
    }

    private var progressText: Text {
        guard let progress else { return Text(L10n.unknown) }
        return Text(progress, format: .percent.precision(.fractionLength(0)))
    }
}
#endif
