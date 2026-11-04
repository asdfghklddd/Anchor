#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

/// The desk's task library (任务进程库), laid out as the Figma desk: a folder
/// per task in its tab color, the task's name on the folder's tab, and up to
/// three of its conversations filed inside. The card in front reads the
/// person's latest request and the agent's latest reply; behind it each card
/// shows its name and how long the agent has worked in it. A conversation that
/// failed, is stuck or waits for the person (the old red light) takes the
/// task's color and an anchor and comes to the front on its own; any other
/// card stays white wherever it sits. Tapping a card behind, or pulling it
/// down, brings it to the front, lifting toward the light as it goes, and it
/// lands with a light tap. Fewer than three tasks leave dashed empty slots.
struct DeskTaskLibrary: View {
    let tasks: [AnchorSession]
    let now: Date
    /// Results that arrived while the board is up, by conversation: each swells its card once.
    var swells: [UUID: Int] = [:]
    var swellTone: Color = AnchorStateTone.attention.ink
    /// False while the anchor falls on arrival; the columns settle in after it sets.
    var settled = true
    /// Opens a task's details.
    let onTask: (UUID) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var nameScaled: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var requestScaled: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var replyScaled: CGFloat = 14

    /// The card the person brought to the front, per task.
    @State private var picks: [UUID: TaskConversationStack.Pick] = [:]
    /// How many times each conversation was brought to the front: each lifts it once.
    @State private var lifts: [UUID: Int] = [:]
    @State private var landings = 0
    /// How far each card behind is being pulled down, by conversation.
    @State private var pulls: [UUID: CGFloat] = [:]
    /// Each tab's measured width, so the folder's outline can follow it.
    @State private var tabWidths: [UUID: CGFloat] = [:]
    /// A card pulled this far comes to the front.
    private static let pullToFront: CGFloat = 28

    /// The conversation opened over the library, and the folder it grew from.
    private struct Recall: Equatable {
        let task: UUID
        let conversation: UUID
        let folder: Int
        let seen: Set<String>
    }

    @State private var recall: Recall?
    /// How far the open card is being swiped: down closes it, up sends it to the Mac.
    @State private var recallSwipe: CGFloat = 0
    @State private var recallNotice: String?
    @State private var sentToMac = 0
    @Environment(\.openConversationOnMac) private var openOnMac
    /// The tour's pretend Mac opens whatever it is sent, and its cards leave no memory behind.
    @Environment(\.anchorTour) private var tour
    /// The tour is pointing at the waiting card: its anchor drops in and calls.
    private var tourCalls: Bool { tour.map { $0.stage == .waiting || $0.stage == .again } ?? false }
    /// A swipe this far, or flung this fast, closes the card or sends it.
    private static let recallSwipeDistance: CGFloat = 70
    private static let recallFling: CGFloat = 220
    private static let recallPop = Animation.spring(response: 0.42, dampingFraction: 0.66)

    /// Figma metrics, in points on the 874 × 402 desk. The folders are narrower
    /// than the Figma so the library clears the Dynamic Island on either edge.
    enum Metrics {
        static let slots = 3
        static let folder = CGSize(width: 164, height: 343)
        static let folderSpacing: CGFloat = 10
        static let width = folder.width * CGFloat(slots) + folderSpacing * CGFloat(slots - 1)
        /// The tab's height; the first card starts where it ends.
        static let tab: CGFloat = 32
        static let card = CGSize(width: 158, height: 205)
        static let cardInset: CGFloat = 3
        /// How much of each card behind shows: its name and its time.
        static let peek: CGFloat = 51.5
        static let radius: CGFloat = 15
        static let empty = CGRect(x: 1, y: 46, width: 159, height: 297)
    }

    private static let slide = Animation.spring(response: 0.44, dampingFraction: 0.82)

    // Accessibility sizes list everything at these sizes instead.
    private var nameSize: CGFloat { max(17, nameScaled) }
    private var requestSize: CGFloat { max(15, requestScaled) }
    private var replySize: CGFloat { max(14, replyScaled) }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleList
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: Metrics.folderSpacing) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            folder(task)
                                .tourSpot(.folder(index))
                                .tourSpot(.taskFolder(task.id))
                                .opacity(settled ? 1 : 0.4)
                                .offset(y: settled ? 0 : 8)
                                .animation(reduceMotion ? .easeOut(duration: 0.16)
                                    : AnchorMotion.continuity.delay(Double(index) * 0.04), value: settled)
                        }
                        ForEach(tasks.count..<max(tasks.count, Metrics.slots), id: \.self) { _ in emptySlot }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollDisabled(tasks.count <= Metrics.slots)
                // Shadows may spill past the edges unless the folders scroll.
                .scrollClipDisabled(tasks.count <= Metrics.slots)
                .scrollIndicators(.hidden)
                .frame(width: Metrics.width, height: Metrics.folder.height, alignment: .topLeading)
                .opacity(recall == nil ? 1 : 0.35)
                .overlay { recallLayer }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: landings)
        .sensoryFeedback(.success, trigger: sentToMac)
        // Folders follow real membership changes; ordinary refreshes keep them still.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: tasks.map(\.id))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.task.library")
    }

    // MARK: A task's folder

    private func folder(_ task: AnchorSession) -> some View {
        let stack = TaskConversationStack(task: task, pick: picks[task.id])
        let palette = DeskFolderPalette(task)
        return ZStack(alignment: .topLeading) {
            DeskFolderShape(tabWidth: tabWidths[task.id] ?? 72, tabHeight: Metrics.tab, radius: Metrics.radius)
                .fill(palette.folder)
                // The folder's one glow: clean and in its own color.
                .shadow(color: palette.glow.opacity(0.22), radius: 14, y: 2)
            tab(task, palette: palette)

            Group {
                if stack.cards.isEmpty {
                    noConversationsCard
                } else {
                    cards(stack, of: task, palette: palette)
                }
            }
            .padding(.horizontal, Metrics.cardInset)
            .padding(.top, Metrics.tab)
            .frame(width: Metrics.folder.width, height: Metrics.folder.height, alignment: .topLeading)
            // The cards cast onto each other; their shadows never muddy the water outside.
            .clipShape(DeskFolderShape(tabWidth: tabWidths[task.id] ?? 72, tabHeight: Metrics.tab, radius: Metrics.radius))
        }
        .frame(width: Metrics.folder.width, height: Metrics.folder.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    /// The task's name on its folder's tab, as wide as the name (up to about
    /// twelve characters); tapping it opens the task.
    /// On the desk the folder's outline draws the tab; standing alone (the
    /// accessibility list) it draws its own.
    private func tab(_ task: AnchorSession, palette: DeskFolderPalette, standalone: Bool = false) -> some View {
        Button { onTask(task.id) } label: {
            Text(task.goal.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 7)
                .padding(.top, 5)
                .padding(.bottom, standalone ? 7 + 10 : 7)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { tabWidths[task.id] = $0 }
                .background {
                    if standalone {
                        UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12, style: .continuous)
                            .fill(palette.folder)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .frame(maxWidth: Metrics.folder.width, alignment: .leading)
        .accessibilityLabel(task.goal.title)
        .accessibilityHint(DeskText.openTask)
        .accessibilityIdentifier("hosted.task.\(task.id)")
    }

    /// The cards filed in the folder, the front one last and lowest.
    private func cards(_ stack: TaskConversationStack, of task: AnchorSession, palette: DeskFolderPalette) -> some View {
        ZStack(alignment: .top) {
            // A new turn of a conversation keeps its card.
            ForEach(Array(stack.cards.enumerated()), id: \.element.conversationKey) { index, process in
                let isFront = process.conversationKey == stack.front?.conversationKey
                card(process, of: task, palette: palette, isFront: isFront)
                    // Marked before it moves into place, so the mark moves with it.
                    .tourSpot(isFront ? TourSpot.frontCard(task.id) : nil)
                    .offset(y: (CGFloat(index) * Metrics.peek).rounded() + (pulls[process.conversationKey] ?? 0))
                    .highPriorityGesture(pull(process, of: task), including: isFront ? .none : .all)
                    .zIndex(Double(index))
                    .transition(reduceMotion ? .opacity
                        : .asymmetric(insertion: .offset(y: 36).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(width: Metrics.card.width, alignment: .top)
        // Cards move when the stack's order changes, not on every refresh.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : Self.slide, value: stack.cards.map(\.conversationKey))
    }

    private func card(_ process: AnchorProcess, of task: AnchorSession, palette: DeskFolderPalette,
                      isFront: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
        let isRed = process.needsRescue
        let worked = DeskDuration.text(workedTime(process, in: task))
        return Button {
            if isFront { openRecall(process, of: task) } else { bringToFront(process, of: task) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Ten characters always fit: the whole row, or beside the anchor a little smaller.
                Text(process.title)
                    .font(.system(size: 14))
                    .foregroundStyle(DeskStyle.text)
                    .lineLimit(1)
                    .minimumScaleFactor(isRed ? 0.78 : 1)
                    .padding(.trailing, isRed ? 31 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 20)
                Text(worked)
                    .font(.system(size: 11))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .padding(.top, -2)
                if isFront { exchange(process) }
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.top, 10)
            .frame(width: Metrics.card.width, height: Metrics.card.height, alignment: .topLeading)
            .overlay(alignment: .topTrailing) {
                if isRed {
                    DeskCardAnchor()
                        .fill(palette.ink)
                        .frame(width: 20, height: 20)
                        .modifier(TourAnchorCall(calling: isFront && tourCalls, tint: palette.ink))
                        .padding(.top, 10)
                        .padding(.trailing, 11)
                        .accessibilityHidden(true)
                }
            }
            .background(isRed ? palette.front : DeskStyle.card, in: shape)
            .contentShape(shape)
        }
        .buttonStyle(AnchorPressButtonStyle())
        // Each card glows in its task's color and casts up onto the card behind.
        .background {
            shape.fill(DeskStyle.card)
                .shadow(color: palette.glow.opacity(0.2), radius: 20, y: 2)
                .shadow(color: palette.cast.opacity(0.3), radius: 11, y: -2)
        }
        .overlay {
            ResultSwell(trigger: swells[process.id, default: 0], tone: swellTone,
                        cornerRadius: Metrics.radius, reduceMotion: reduceMotion)
        }
        .modifier(CardLift(trigger: lifts[process.id, default: 0], radius: Metrics.radius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(process.title)
        .accessibilityValue([isRed ? DeskText.needsYou : nil, worked, isFront ? spokenExchange(process) : nil]
            .compactMap { $0 }.joined(separator: "\n"))
        .accessibilityHint(isFront ? DeskText.recallHint : DeskText.showConversation)
        .accessibilityAddTraits(isFront ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("ambient.conversation.\(process.id)")
    }

    /// The person's latest request over the agent's latest reply.
    private func exchange(_ process: AnchorProcess) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(process.request ?? "")
                .font(.system(size: 11))
                .lineSpacing(2.3)
                .foregroundStyle(DeskStyle.text)
                .lineLimit(4)
                .frame(width: 130, height: 61, alignment: .topLeading)
            Text(reply(for: process))
                .font(.system(size: 10))
                .lineSpacing(2)
                .foregroundStyle(DeskFolderPalette.replyInk)
                .lineLimit(6)
                .frame(width: 124, height: 84, alignment: .topLeading)
                .padding(.top, 9)
        }
        .padding(.top, 3)
    }

    private var noConversationsCard: some View {
        Text(DeskText.noConversations)
            .font(.system(size: 11))
            .foregroundStyle(DeskFolderPalette.replyInk)
            .padding(12)
            .frame(width: Metrics.card.width, height: Metrics.card.height, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                    .fill(DeskStyle.card)
                    .shadow(color: .black.opacity(0.12), radius: 11, y: -2)
            }
    }

    /// A slot with no task: a dashed outline the size of a folder's cards.
    private var emptySlot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous)
                .strokeBorder(DeskFolderPalette.replyInk, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            Text(DeskText.noOtherTask)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(DeskFolderPalette.replyInk)
        }
        .frame(width: Metrics.empty.width, height: Metrics.empty.height)
        .padding(.leading, Metrics.empty.minX)
        .padding(.top, Metrics.empty.minY)
        .frame(width: Metrics.folder.width, height: Metrics.folder.height, alignment: .topLeading)
        .accessibilityElement(children: .combine)
    }

    /// What the agent last answered; while a turn runs, how long it has been
    /// going, since an older reply would not answer the request above it.
    private func reply(for process: AnchorProcess) -> String {
        if let reply = process.latestReply { return reply }
        switch process.status {
        case .running, .queued:
            let start = process.events.first { $0.kind == .created }?.occurredAt ?? process.updatedAt
            return PlanText.running(since: start, now: now)
        case .needsDecision:
            return PlanText.waitingForReply
        default:
            return DeskText.noReply
        }
    }

    private func spokenExchange(_ process: AnchorProcess) -> String {
        [process.request.map { "\(DeskText.you): \($0)" }, "\(DeskText.reply): \(reply(for: process))"]
            .compactMap { $0 }
            .joined(separator: "\n")
    }

    /// Pulling a card behind down past a short distance brings it to the front.
    private func pull(_ process: AnchorProcess, of task: AnchorSession) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in pulls[process.conversationKey] = max(0, value.translation.height) * 0.6 }
            .onEnded { value in
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : Self.slide) {
                    pulls[process.conversationKey] = nil
                    if value.translation.height > Self.pullToFront { bringToFront(process, of: task) }
                }
            }
    }

    /// The agent's working time in the conversation: what the Mac counted, or,
    /// from a Mac that does not count it, the conversation's turns added up here.
    private func workedTime(_ process: AnchorProcess, in task: AnchorSession) -> TimeInterval {
        if let worked = process.workedTime(at: now) { return worked }
        return task.taskProcesses.filter { $0.conversationKey == process.conversationKey }.reduce(0) { total, turn in
            let start = turn.events.first { $0.kind == .created }?.occurredAt ?? turn.updatedAt
            let end = turn.status == .running ? now : turn.updatedAt
            return total + max(0, end.timeIntervalSince(start))
        }
    }

    private func bringToFront(_ process: AnchorProcess, of task: AnchorSession) {
        picks[task.id] = TaskConversationStack.Pick(conversation: process.conversationKey, at: .now)
        guard !reduceMotion else {
            landings += 1
            return
        }
        lifts[process.id, default: 0] += 1
        Task { @MainActor in
            // The tap comes when the card lands, not when it leaves.
            try? await Task.sleep(for: .milliseconds(300))
            landings += 1
        }
    }

    // MARK: The open card

    /// The open card over the library, grown out of its folder; tapping beside it closes it.
    @ViewBuilder
    private var recallLayer: some View {
        if let recall, let task = tasks.first(where: { $0.id == recall.task }),
           let process = TaskConversationStack.conversations(of: task).first(where: { $0.conversationKey == recall.conversation }) {
            ZStack(alignment: .top) {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { closeRecall() }
                    .accessibilityHidden(true)
                DeskRecallCard(process: process, task: task, palette: DeskFolderPalette(task),
                               worked: DeskDuration.text(workedTime(process, in: task)),
                               fallbackReply: reply(for: process), seenPath: recall.seen,
                               onTask: { onTask(task.id) })
                    .tourSpot(.recallCard)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("desk.recall")
                    .offset(y: recallSwipe)
                    .gesture(recallSwipeGesture)
                    .accessibilityAction(named: DeskText.recallOpenOnMac) { sendRecallToMac() }
                    .accessibilityAction(.escape) { closeRecall() }
                    .transition(reduceMotion ? .opacity
                        : .scale(scale: 0.3, anchor: UnitPoint(x: (CGFloat(recall.folder) + 0.5) / CGFloat(Metrics.slots), y: 0.3))
                            .combined(with: .opacity))
            }
            .id(recall.conversation)
        }
        if let recallNotice {
            Text(recallNotice)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DeskStyle.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(DeskStyle.card, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .offset(y: -6)))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private var recallSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                // Down follows the finger; up a little ahead of it, toward the Mac.
                let dy = value.translation.height
                recallSwipe = dy > 0 ? dy : dy * 1.1
            }
            .onEnded { value in
                let dy = value.translation.height
                let flung = value.predictedEndTranslation.height
                if dy < -Self.recallSwipeDistance || flung < -Self.recallFling {
                    sendRecallToMac()
                } else if dy > Self.recallSwipeDistance || flung > Self.recallFling {
                    closeRecall()
                } else {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.16) : Self.slide) { recallSwipe = 0 }
                }
            }
    }

    private func openRecall(_ process: AnchorProcess, of task: AnchorSession) {
        let folder = tasks.firstIndex { $0.id == task.id } ?? 0
        let next = Recall(task: task.id, conversation: process.conversationKey, folder: min(folder, Metrics.slots - 1),
                          seen: DeskRecallMemory.seen(process.conversationKey))
        recallSwipe = 0
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : Self.recallPop) { recall = next }
        landings += 1
        tour?.opened(task.id)
    }

    /// Puts the card back into its folder; what it showed counts as seen.
    private func closeRecall() {
        guard let recall else { return }
        rememberSeen(recall)
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : Self.slide) {
            self.recall = nil
            recallSwipe = 0
        }
        tour?.closedTask(sentToMac: false)
    }

    /// The card flies up toward the Mac and the conversation opens there.
    private func sendRecallToMac() {
        guard let recall else { return }
        rememberSeen(recall)
        let conversation = recall.conversation
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .easeIn(duration: 0.22)) {
            recallSwipe = reduceMotion ? 0 : -Metrics.folder.height * 1.4
            self.recall = nil
        }
        tour?.closedTask(sentToMac: true)
        Task { @MainActor in
            let opened = tour != nil ? true : await openOnMac(conversation)
            if opened { sentToMac += 1 }
            withAnimation(.easeOut(duration: 0.2)) {
                recallNotice = opened ? DeskText.recallOpened : DeskText.recallNotConnected
            }
            recallSwipe = 0
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.3)) { recallNotice = nil }
        }
    }

    private func rememberSeen(_ recall: Recall) {
        guard tour == nil, let task = tasks.first(where: { $0.id == recall.task }),
              let path = TaskConversationStack.conversations(of: task)
                .first(where: { $0.conversationKey == recall.conversation })?.digest?.path else { return }
        DeskRecallMemory.remember(path, for: recall.conversation)
    }

    // MARK: Accessibility sizes

    /// Large text gets no overlap: each task's conversations as full cards, newest first.
    private var accessibleList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(tasks) { task in
                let stack = TaskConversationStack(task: task)
                VStack(alignment: .leading, spacing: 0) {
                    tab(task, palette: DeskFolderPalette(task), standalone: true)
                    VStack(alignment: .leading, spacing: 10) {
                        if stack.cards.isEmpty { noConversationsCard }
                        ForEach(stack.cards.reversed()) { process in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(process.title)
                                    .font(.system(size: nameSize, weight: .medium))
                                    .foregroundStyle(AnchorIOSStyle.text)
                                if let request = process.request {
                                    Text(request)
                                        .font(.system(size: requestSize, weight: .medium))
                                        .foregroundStyle(AnchorIOSStyle.text)
                                }
                                Text(reply(for: process))
                                    .font(.system(size: replySize))
                                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: Metrics.radius, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, -10)
                }
            }
        }
    }
}

/// The anchor on a card that needs the person, from the owner's mockup: a ring
/// with a small eye, a straight shank and no stock, and a round bowl whose two
/// short flukes turn inward. Measured on a unit square.
struct DeskCardAnchor: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: origin.x + x * side, y: origin.y + y * side) }

        let ringCenter = point(0.5, 0.164)
        var ring = Path()
        ring.addArc(center: ringCenter, radius: 0.108 * side, startAngle: .zero, endAngle: .degrees(360), clockwise: false)

        var shank = Path()
        shank.move(to: point(0.5, 0.272))
        shank.addLine(to: point(0.5, 0.945))

        var bowl = Path()
        bowl.move(to: point(0.18, 0.5))
        bowl.addLine(to: point(0.055, 0.5))
        bowl.addArc(center: point(0.5, 0.5), radius: 0.445 * side, startAngle: .degrees(180), endAngle: .zero, clockwise: true)
        bowl.addLine(to: point(0.82, 0.5))

        var anchor = Path()
        anchor.addPath(ring.strokedPath(StrokeStyle(lineWidth: 0.112 * side)))
        anchor.addPath(shank.strokedPath(StrokeStyle(lineWidth: 0.092 * side)))
        anchor.addPath(bowl.strokedPath(StrokeStyle(lineWidth: 0.115 * side, lineCap: .round, lineJoin: .round)))
        return anchor
    }
}

/// A folder with its tab as one outline: the tab's rounded top rises from
/// the folder's left edge, and its right side curves into the folder's top,
/// so the two never meet at a notch.
struct DeskFolderShape: Shape {
    var tabWidth: CGFloat
    var tabHeight: CGFloat
    var radius: CGFloat
    var tabRadius: CGFloat = 12
    /// The inside curve where the tab's right side meets the folder's top.
    var fillet: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        let width = rect.width, bottom = rect.maxY, top = tabHeight
        let tab = min(max(tabWidth, tabRadius * 2), width)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: bottom - radius))
        path.addLine(to: CGPoint(x: 0, y: tabRadius))
        path.addArc(tangent1End: .zero, tangent2End: CGPoint(x: tabRadius, y: 0), radius: tabRadius)
        if tab + fillet + radius <= width {
            path.addArc(tangent1End: CGPoint(x: tab, y: 0), tangent2End: CGPoint(x: tab, y: tabRadius), radius: tabRadius)
            path.addArc(tangent1End: CGPoint(x: tab, y: top), tangent2End: CGPoint(x: tab + fillet, y: top), radius: fillet)
            path.addArc(tangent1End: CGPoint(x: width, y: top), tangent2End: CGPoint(x: width, y: top + radius),
                        radius: radius)
        } else {
            // A name as wide as the folder: the tab is the folder's top.
            path.addArc(tangent1End: CGPoint(x: width, y: 0), tangent2End: CGPoint(x: width, y: tabRadius),
                        radius: tabRadius)
        }
        path.addArc(tangent1End: CGPoint(x: width, y: bottom), tangent2End: CGPoint(x: width - radius, y: bottom),
                    radius: radius)
        path.addArc(tangent1End: CGPoint(x: 0, y: bottom), tangent2End: CGPoint(x: 0, y: bottom - radius), radius: radius)
        path.closeSubpath()
        return path
    }
}

/// A folder's colors from the Figma desk, by the task's tab color.
struct DeskFolderPalette {
    /// The folder and its tab.
    let folder: Color
    /// The colored glow under the folder and its cards.
    let glow: Color
    /// The time and the anchor on its cards.
    let ink: Color
    /// The card in front.
    let front: Color
    /// The shade a card casts on the one behind, a deeper tone of the folder so it never turns brown.
    let cast: Color

    static let replyInk = DeskStyle.adaptive(0xA3A3A3, dark: 0x8597A1)

    private static let glows: [UInt32] = [0xFFB400, 0x49C8FF, 0xFF64DB]
    private static let inks: [(UInt32, UInt32)] = [(0xFF7F00, 0xFFA040), (0x0095FF, 0x5CBBFF), (0xFF3ED2, 0xFF7AE0)]
    private static let fronts: [(UInt32, UInt32)] = [(0xFFF6E1, 0x3B3122), (0xD4F6FF, 0x173E4C), (0xFFEFFB, 0x3E2439)]
    private static let casts: [UInt32] = [0xC27A00, 0x0A78C2, 0xC232A0]

    init(_ task: AnchorSession) {
        let index = max(0, task.taskColorIndex ?? 0) % Self.inks.count
        folder = HostedTaskAppearance.landscapeTabTint(task)
        glow = Color(anchorHex: Self.glows[index])
        ink = DeskStyle.adaptive(Self.inks[index].0, dark: Self.inks[index].1)
        front = DeskStyle.adaptive(Self.fronts[index].0, dark: Self.fronts[index].1)
        cast = DeskStyle.adaptive(Self.casts[index], dark: 0x000000)
    }
}

/// The desk's own colors: the Figma's light board, and a night harbor for dark mode.
enum DeskStyle {
    static let waterLeft = adaptive(0xF9FCFE, dark: 0x0F1C25)
    static let waterRight = adaptive(0xD4F7FF, dark: 0x123641)
    static let ink = adaptive(0x26599D, dark: 0xB5E2F6)
    static let quietInk = adaptive(0x8F8F8F, dark: 0x8FA3AD)
    static let card = adaptive(0xFFFFFF, dark: 0x20343E)
    static let text = adaptive(0x000000, dark: 0xDFEFF5)

    static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

/// A working time as the desk writes it: "39min", "1h57min", "26h3min".
enum DeskDuration {
    static func text(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 60 { return "\(minutes)min" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h\(minutes % 60)min"
    }
}

/// A card coming to the front is picked up: lifted toward the light as it
/// passes over the others, carried down with its shadow deep, and set down
/// as it lands, so the move reads as a card, not a redraw.
private struct CardLift: ViewModifier {
    let trigger: Int
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { card, lift in
            card
                .overlay {
                    LinearGradient(colors: [.white.opacity(0.4 * lift), .white.opacity(0)],
                                   startPoint: .top, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.16 * lift), radius: 18 * lift, y: 12 * lift)
                .scaleEffect(1 + 0.035 * lift)
        } keyframes: { _ in
            CubicKeyframe(1, duration: 0.08)
            LinearKeyframe(1, duration: 0.2)
            SpringKeyframe(0, duration: 0.45, spring: Spring(response: 0.36, dampingRatio: 0.72))
        }
    }
}
#endif
