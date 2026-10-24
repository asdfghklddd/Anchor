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
    @ScaledMetric(relativeTo: .body) private var detailScaled: CGFloat = 17
    @ScaledMetric(relativeTo: .title2) private var emptyPromptScaled: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var freshnessScaled: CGFloat = 15

    @State private var contacts = 0
    @State private var settled = true
    @State private var keepAwake = DeskKeepAwake()
    /// Results already on the board; only ones that arrive later swell.
    @State private var seenResults: Set<ResultKey>?
    @State private var swellsByConversation: [UUID: Int] = [:]
    @State private var swellTone = AnchorStateTone.attention.ink
    @AppStorage(DeskPetKind.defaultsKey, store: ProfilePreferences.store) private var petKind = DeskPetKind.crab
    /// When the board came up; the pet sleeps only after a long quiet since then.
    @State private var boardSince = Date()
    /// News that arrived while the board is up, for the pet to react to.
    @State private var petSignals = DeskPetSignals()

    // Desk sizes may grow with Dynamic Type but never shrink below these.
    private var clockSize: CGFloat { max(68, clockScaled) }
    private var detailSize: CGFloat { max(17, detailScaled) }
    private var emptyPromptSize: CGFloat { max(24, emptyPromptScaled) }
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
                                library(now: context.date)
                                status(now: context.date)
                            }
                            .padding(16)
                        }
                    } else {
                        // The Figma desk is drawn on the whole 874 × 402 screen and scaled to fit others.
                        let scale = min(geometry.size.width / Self.canvas.width, geometry.size.height / Self.canvas.height)
                        desk(now: context.date)
                            .frame(width: Self.canvas.width, height: Self.canvas.height, alignment: .topLeading)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: Self.canvas.width * scale, height: Self.canvas.height * scale,
                                   alignment: .topLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea(edges: dynamicTypeSize.isAccessibilitySize ? [] : .all)
        .background { DeskBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: contacts)
        .onAppear {
            boardSince = .now
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
        let statuses = arrived.compactMap { key in
            tasks.first { $0.id == key.task }?.taskProcesses.first { $0.id == key.process }?.status
        }
        if statuses.contains(.failed) { petSignals.failures += 1 }
        else if statuses.contains(.needsDecision) { petSignals.questions += 1 }
        else { petSignals.results += 1 }
    }

    // MARK: The Figma desk

    static let canvas = CGSize(width: 874, height: 402)
    private static let ink = Color(anchorHex: 0x26599D)
    private static let quietInk = Color(anchorHex: 0x8F8F8F)

    /// Every part at its Figma place: the clock and date top left, the pet
    /// below them, the conversation count at the foot, the folders on the right.
    private func desk(now: Date) -> some View {
        ZStack(alignment: .topLeading) {
            DeskClockText(text: Self.time(now), color: Self.ink)
                .accessibilityIdentifier("ambient.time")
                .offset(x: 27, y: 41)
            HStack(spacing: 12) {
                Text(now.formatted(.dateTime.weekday(.wide).locale(AnchorStrings.interfaceLocale)))
                Text(now.formatted(.dateTime.month().day().locale(AnchorStrings.interfaceLocale)))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Self.ink)
            .lineLimit(1)
            .frame(width: 242, alignment: .trailing)
            .offset(y: 103)
            if petKind != .off {
                DeskPet(kind: petKind, mood: petMood(now: now), signals: petSignals,
                        hour: Calendar.current.component(.hour, from: now))
                    .frame(width: 236)
                    .offset(x: 15, y: 339 - DeskPet.height)
            }
            if case .behind = projection.freshness, !tasks.isEmpty {
                Label(SyncText.line(for: projection.freshness, now: now), systemImage: SyncText.symbol(for: projection.freshness))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Self.quietInk)
                    .lineLimit(2)
                    .frame(width: 150, alignment: .leading)
                    .offset(x: 24, y: 358)
                    .accessibilityIdentifier("ambient.freshness")
            }
            Button(action: onManage) {
                Text(DeskText.conversationCount(conversationCount))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Self.quietInk)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .frame(width: 243, alignment: .trailing)
            .offset(y: 350)
            .accessibilityLabel(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
            .accessibilityValue(DeskText.conversationCount(conversationCount))
            .accessibilityIdentifier("ambient.tasks.manage")
            DeskTaskLibrary(tasks: tasks, now: now, swells: swellsByConversation, swellTone: swellTone,
                            settled: settled, onTask: onTask)
                .offset(x: 290, y: 32)
        }
    }

    private var conversationCount: Int {
        tasks.reduce(0) { $0 + TaskConversationStack.conversations(of: $1).count }
    }

    /// "21:27": the desk always shows a 24-hour clock, as the design does.
    private static func time(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    // MARK: The pet (left, under the clock)

    /// Typing while any agent runs; asleep after 20 minutes with no run and no news.
    private func petMood(now: Date) -> DeskPetMood {
        let processes = tasks.flatMap(\.taskProcesses)
        if processes.contains(where: { $0.status == .running || $0.status == .queued }) { return .working }
        let lastNews = max(processes.map(\.updatedAt).max() ?? .distantPast, boardSince)
        return now.timeIntervalSince(lastNews) > 20 * 60 ? .quiet : .yourMove
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

    @ViewBuilder
    private func library(now: Date) -> some View {
        if tasks.isEmpty {
            Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                // An empty desk is water and an invitation, not an empty white card.
                .font(.system(size: emptyPromptSize, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
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
/// The desk's water: the Figma gradient from near white on the left to light cyan on the right.
private struct DeskBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(anchorHex: 0xF9FCFE), Color(anchorHex: 0xD4F7FF)],
                       startPoint: .leading, endPoint: .trailing)
            .ignoresSafeArea()
    }
}
#endif
