#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The landscape desk board, read from about 60 cm on its stand (D05). On the
/// left, a large clock and the date; on the right, the task library: each
/// task's conversations stacked under its name, the one in front reading the
/// person's latest request and the agent's latest reply. How current this
/// copy is sits under the clock. Motion follows real work only: a result that
/// arrives swells its card once, and on arrival the columns settle in.
struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    /// Settle the columns in with one haptic: true only when work just turned
    /// from portrait to landscape.
    var playsArrival = false
    /// Opens a task's details.
    let onTask: (UUID) -> Void
    let onManage: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var clockScaled: CGFloat = 68
    @ScaledMetric(relativeTo: .title) private var titleScaled: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var detailScaled: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var freshnessScaled: CGFloat = 15

    @State private var contacts = 0
    @State private var settled = true
    @State private var keepAwake = DeskKeepAwake()
    /// Results already on the board; only ones that arrive later swell.
    @State private var seenResults: Set<ResultKey>?
    @State private var swellsByConversation: [UUID: Int] = [:]
    @State private var swellTone = AnchorStateTone.attention.ink

    // Desk sizes may grow with Dynamic Type but never shrink below these.
    private var clockSize: CGFloat { max(68, clockScaled) }
    private var titleSize: CGFloat { max(24, titleScaled) }
    private var detailSize: CGFloat { max(17, detailScaled) }
    private var freshnessSize: CGFloat { max(15, freshnessScaled) }

    private var tasks: [AnchorSession] { projection.hostedSessions }

    private struct ResultKey: Hashable {
        let task: UUID
        let process: UUID
        let at: Date
    }

    private var resultKeys: Set<ResultKey> {
        Set(tasks.flatMap { task in task.resultsToLookAt.map { ResultKey(task: task.id, process: $0.id, at: $0.updatedAt) } })
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.everyMinute) { context in
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                clock(now: context.date)
                                libraryTitle
                                library(now: context.date)
                                status(now: context.date)
                            }
                            .padding(16)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 0) {
                                clock(now: context.date)
                                Spacer(minLength: 8)
                                status(now: context.date)
                            }
                            .padding(.bottom, 8)
                            // Wide enough for the clock at full size (68pt rounded heavy).
                            .frame(width: max(0, geometry.size.width * 0.27), alignment: .leading)
                            VStack(alignment: .leading, spacing: 8) {
                                libraryTitle
                                library(now: context.date)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background { HarborBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: contacts)
        .onAppear {
            keepAwake.start()
            if playsArrival, !tasks.isEmpty { playArrival() }
        }
        .onDisappear { keepAwake.stop() }
        .onChange(of: resultKeys, initial: true) { _, keys in noteResults(keys) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.screen")
    }

    /// A result that arrives while the board is up swells its card once;
    /// what was already there when the board appeared is not news.
    private func noteResults(_ keys: Set<ResultKey>) {
        guard let seen = seenResults else {
            seenResults = keys
            return
        }
        let arrived = keys.subtracting(seen)
        seenResults = seen.union(keys)
        guard let newest = arrived.max(by: { $0.at < $1.at }),
              let task = tasks.first(where: { $0.id == newest.task }) else { return }
        swellTone = TaskNextAction(task: task).map { PlanCopy.symbol(for: $0).color } ?? AnchorStateTone.attention.ink
        swellsByConversation[newest.process, default: 0] += 1
    }

    // MARK: The clock (left)

    private func clock(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                // Rounded tabular digits (D05): the minutes change without the line shifting.
                .font(.system(size: clockSize, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AnchorIOSStyle.heading)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .accessibilityIdentifier("ambient.time")
            Text(now.formatted(.dateTime.month().day().weekday(.wide).locale(AnchorStrings.interfaceLocale)))
                .font(.system(size: detailSize, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// The way to the tasks, and how current this copy is.
    private func status(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            manageButton
            if !tasks.isEmpty {
                Label(SyncText.line(for: projection.freshness, now: now), systemImage: SyncText.symbol(for: projection.freshness))
                    .font(.system(size: freshnessSize, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("ambient.freshness")
            }
        }
    }

    private var manageButton: some View {
        Button(action: onManage) {
            HStack(spacing: 5) {
                Text("\(tasks.count)").monospacedDigit()
                HarborAnchorGlyph(color: AnchorIOSStyle.secondaryText, lineWidth: 1.6)
                    .frame(width: 16, height: 16)
            }
            .font(.system(size: detailSize, weight: .semibold))
            .foregroundStyle(AnchorIOSStyle.secondaryText)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
        }
        .accessibilityLabel(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
        .accessibilityIdentifier("ambient.tasks.manage")
    }

    // MARK: The task library (right)

    private var libraryTitle: some View {
        Text(DeskText.library)
            .font(.system(size: titleSize, weight: .heavy))
            .foregroundStyle(AnchorIOSStyle.heading)
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func library(now: Date) -> some View {
        if tasks.isEmpty {
            Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                .font(.system(size: detailSize, weight: .medium))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
                .padding(20)
                .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.heroRadius))
                .accessibilityIdentifier("ambient.task.library")
        } else {
            DeskTaskLibrary(tasks: tasks, now: now, swells: swellsByConversation, swellTone: swellTone,
                            settled: settled, onTask: onTask)
        }
    }

    // MARK: Arrival

    /// Turning to the desk settles the columns in with one haptic.
    /// Content is readable from the first frame (D10).
    private func playArrival() {
        guard !reduceMotion else {
            contacts += 1
            return
        }
        settled = false
        Task { @MainActor in
            // One frame unsettled, so the columns have somewhere to rise from.
            try? await Task.sleep(for: .milliseconds(16))
            settled = true
            contacts += 1
        }
    }
}
#endif
