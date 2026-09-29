#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacHistoryTrackView: View {
    let projection: SessionProjection
    let onOpenCurrentWork: () -> Void

    @State private var searchText = ""
    @State private var selectedSnapshot: ContextSnapshot?
    @State private var cardFrames: [UUID: CGRect] = [:]

    private var snapshots: [ContextSnapshot] {
        MacHistorySnapshotQuery.filtered(
            projection.session?.snapshots ?? [],
            query: searchText
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.xLarge) {
                if let session = projection.session {
                    MacHistoryCurrentTaskCard(
                        session: session,
                        onOpenCurrentWork: onOpenCurrentWork
                    )
                }

                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    Text(L10n.historyTrail)
                        .font(.title2.bold())
                        .foregroundStyle(AnchorPalette.ink)

                    historyContent
                }
            }
            .frame(maxWidth: 1120, alignment: .leading)
            .padding(.horizontal, AnchorSpacing.xLarge)
            .padding(.vertical, AnchorSpacing.large)
        }
        .background(.clear)
        .navigationTitle(L10n.history)
        .searchable(text: $searchText, prompt: L10n.historySearch)
        .sheet(item: $selectedSnapshot, content: MacSnapshotDetailView.init)
        .accessibilityIdentifier("mac.history.screen")
    }

    @ViewBuilder
    private var historyContent: some View {
        if snapshots.isEmpty, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ContentUnavailableView.search(text: searchText)
                .frame(maxWidth: .infinity, minHeight: 280)
                .fluoriteSurface(cornerRadius: 18)
        } else if snapshots.isEmpty {
            ContentUnavailableView(
                projection.session == nil ? L10n.emptyTitle : L10n.historyNoSnapshots,
                systemImage: "clock.arrow.circlepath",
                description: Text(
                    projection.session == nil
                        ? L10n.historyEmptyDetail
                        : L10n.historyNoSnapshotsDetail
                )
            )
            .frame(maxWidth: .infinity, minHeight: 280)
            .fluoriteSurface(cornerRadius: 18)
        } else {
            ZStack {
                MacHistoryConnectorPath(
                    orderedIDs: snapshots.map(\.id),
                    frames: cardFrames
                )

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 390), spacing: AnchorSpacing.large),
                    ],
                    alignment: .leading,
                    spacing: AnchorSpacing.large
                ) {
                    ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                        MacHistorySnapshotCard(
                            index: index + 1,
                            snapshot: snapshot,
                            action: { selectedSnapshot = snapshot }
                        )
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: MacHistoryCardFramePreferenceKey.self,
                                    value: [
                                        snapshot.id: proxy.frame(in: .named("mac.history.track")),
                                    ]
                                )
                            }
                        }
                    }
                }
            }
            .coordinateSpace(name: "mac.history.track")
            .onPreferenceChange(MacHistoryCardFramePreferenceKey.self) { frames in
                cardFrames = frames
            }
        }
    }
}

private struct MacHistoryCurrentTaskCard: View {
    let session: AnchorSession
    let onOpenCurrentWork: () -> Void

    var body: some View {
        Button(action: onOpenCurrentWork) {
            AnchorCard(tint: AnchorPalette.seafoam) {
                HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                    Image(systemName: "scope")
                        .font(.title3.bold())
                        .foregroundStyle(AnchorPalette.mintInk)
                        .frame(width: 42, height: 42)
                        .background(AnchorPalette.seafoam.opacity(0.18), in: .circle)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        Text(L10n.currentWork)
                            .font(.caption.bold())
                            .foregroundStyle(AnchorPalette.interaction)
                            .textCase(.uppercase)
                        Text(session.goal.title)
                            .font(.title2.bold())
                            .foregroundStyle(AnchorPalette.ink)
                        Text(
                            L10n.startedAt(
                                session.startedAt.formatted(date: .abbreviated, time: .shortened)
                            )
                        )
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                    Spacer(minLength: AnchorSpacing.medium)
                    Label(L10n.processCount(session.processes.count), systemImage: "arrow.up.right")
                        .font(.callout.bold())
                        .foregroundStyle(AnchorPalette.brandDeep)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L10n.openDetails)
        .accessibilityIdentifier("mac.history.current")
    }
}

private struct MacHistorySnapshotCard: View {
    let index: Int
    let snapshot: ContextSnapshot
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                Text(index, format: .number)
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .frame(width: 36, height: 36)
                    .background(AnchorPalette.softBlue.opacity(0.76), in: .circle)

                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(snapshot.goalTitle)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(snapshot.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    if let latestNote = snapshot.latestNote, !latestNote.isEmpty {
                        Text(latestNote)
                            .font(.callout)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .lineLimit(2)
                    }
                    Label(
                        L10n.processAttentionSummary(
                            processes: snapshot.processes.count,
                            attention: snapshot.openDecisionIDs.count
                        ),
                        systemImage: "arrow.up.right"
                    )
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.callout.bold())
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .accessibilityHidden(true)
            }
            .padding(AnchorSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
            .background(
                isHovering
                    ? AnchorPalette.softBlue.opacity(0.30)
                    : AnchorPalette.fluoriteSurface,
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isHovering
                            ? AnchorPalette.aiBlue.opacity(0.52)
                            : AnchorPalette.fluoriteBorder,
                        lineWidth: isHovering ? 1.5 : 1
                    )
            }
            .shadow(
                color: AnchorPalette.brandDeep.opacity(isHovering ? 0.08 : 0.04),
                radius: isHovering ? 12 : 7,
                y: isHovering ? 6 : 4
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover(perform: updateHover)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L10n.openDetails)
        .accessibilityIdentifier("mac.history.snapshot")
    }

    private func updateHover(_ hovering: Bool) {
        withAnimation(reduceMotion ? nil : AnchorMotion.micro) {
            isHovering = hovering
        }
    }
}

private struct MacHistoryConnectorPath: View {
    let orderedIDs: [UUID]
    let frames: [UUID: CGRect]

    var body: some View {
        Canvas { context, _ in
            let points = orderedIDs.compactMap { id -> CGPoint? in
                guard let frame = frames[id] else { return nil }
                return CGPoint(x: frame.midX, y: frame.midY)
            }
            guard points.count > 1 else { return }

            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [
                        AnchorPalette.aiBlue.opacity(0.44),
                        AnchorPalette.periwinkle.opacity(0.30),
                    ]),
                    startPoint: points[0],
                    endPoint: points[points.count - 1]
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 7])
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MacHistoryCardFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}
#endif
