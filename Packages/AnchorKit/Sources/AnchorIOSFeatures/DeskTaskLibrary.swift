#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The desk's task library (任务进程库): a column per task, its name on a tab
/// in the task's color above a stack of up to three of its conversations.
/// The card in front reads the person's latest request and the agent's latest
/// reply; behind it each card shows only its name. Tapping a card behind
/// slides it down to the front, lifting toward the light as it goes, and it
/// lands with a light tap. More than three tasks scroll sideways.
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

    private static let visibleColumns = 3
    private static let columnSpacing: CGFloat = 12
    private static let nextColumnSliver: CGFloat = 20
    /// How far a tab tucks under the first card.
    private static let tabTuck: CGFloat = 16
    private static let radius: CGFloat = 18
    private static let slide = Animation.spring(response: 0.44, dampingFraction: 0.82)

    // Sizes may grow with Dynamic Type but never shrink below these.
    private var nameSize: CGFloat { max(17, nameScaled) }
    private var requestSize: CGFloat { max(15, requestScaled) }
    private var replySize: CGFloat { max(14, replyScaled) }
    /// The strip a card behind shows: its name with some air.
    private var peek: CGFloat { (nameSize * 1.25 + 18).rounded() }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibleList
            } else {
                GeometryReader { proxy in
                    // With more tasks, a sliver of the next column says the row scrolls.
                    let gaps = tasks.count > Self.visibleColumns
                        ? Self.columnSpacing * CGFloat(Self.visibleColumns) + Self.nextColumnSliver
                        : Self.columnSpacing * CGFloat(Self.visibleColumns - 1)
                    let width = max(0, (proxy.size.width - gaps) / CGFloat(Self.visibleColumns))
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: Self.columnSpacing) {
                            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                                column(task, width: width)
                                    .opacity(settled ? 1 : 0.4)
                                    .offset(y: settled ? 0 : 8)
                                    .animation(reduceMotion ? .easeOut(duration: 0.16)
                                        : AnchorMotion.continuity.delay(Double(index) * 0.04), value: settled)
                            }
                        }
                        .frame(height: proxy.size.height, alignment: .top)
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollDisabled(tasks.count <= Self.visibleColumns)
                    // Shadows may spill past the edges unless the columns scroll.
                    .scrollClipDisabled(tasks.count <= Self.visibleColumns)
                    .scrollIndicators(.hidden)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: landings)
        // Columns follow real membership changes; ordinary refreshes keep them still.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: tasks.map(\.id))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.task.library")
    }

    // MARK: A task's column

    private func column(_ task: AnchorSession, width: CGFloat) -> some View {
        let stack = TaskConversationStack(task: task, pick: picks[task.id])
        let tint = HostedTaskAppearance.tint(task)
        return VStack(alignment: .leading, spacing: 0) {
            tab(task, tint: tint, width: width)
            Group {
                if stack.cards.isEmpty {
                    emptyCard
                } else {
                    cards(stack, of: task, tint: tint)
                }
            }
            .padding(.top, -Self.tabTuck)
        }
        .frame(width: width)
        .accessibilityElement(children: .contain)
    }

    /// The task's name on its color; tapping it opens the task.
    private func tab(_ task: AnchorSession, tint: Color, width: CGFloat) -> some View {
        Button { onTask(task.id) } label: {
            Text(task.goal.title)
                .font(.system(size: nameSize, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.top, 7)
                .padding(.bottom, 7 + Self.tabTuck)
                .background(tint, in: .rect(cornerRadius: 14, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .frame(maxWidth: width * 0.92, alignment: .leading)
        .accessibilityLabel(task.goal.title)
        .accessibilityHint(DeskText.openTask)
        .accessibilityIdentifier("hosted.task.\(task.id)")
    }

    /// Every card reaches the bottom, so the ones behind read as paper under
    /// the one in front; only their top strips show.
    private func cards(_ stack: TaskConversationStack, of task: AnchorSession, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ForEach(Array(stack.cards.enumerated()), id: \.element.id) { index, process in
                    let top = CGFloat(index) * peek
                    card(process, of: task, tint: tint, isFront: process.id == stack.front?.id)
                        .frame(height: max(0, proxy.size.height - top))
                        .offset(y: top)
                        .zIndex(Double(index))
                        .transition(reduceMotion ? .opacity
                            : .asymmetric(insertion: .offset(y: 36).combined(with: .opacity), removal: .opacity))
                }
            }
        }
        // Cards move when the stack's order changes, not on every refresh.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : Self.slide, value: stack.cards.map(\.id))
    }

    private func card(_ process: AnchorProcess, of task: AnchorSession, tint: Color, isFront: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
        return Button {
            if isFront { onTask(task.id) } else { bringToFront(process, of: task) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(process.title)
                    .font(.system(size: nameSize, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: peek, maxHeight: peek, alignment: .leading)
                exchange(process, tint: tint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AnchorIOSStyle.surface)
            .clipShape(shape)
            .contentShape(shape)
        }
        .buttonStyle(AnchorPressButtonStyle())
        // Cast up onto the card behind, so the stack reads as layers.
        .background { shape.fill(AnchorIOSStyle.surface).shadow(color: .black.opacity(0.1), radius: 9, y: -2) }
        .overlay {
            ResultSwell(trigger: swells[process.id, default: 0], tone: swellTone,
                        cornerRadius: Self.radius, reduceMotion: reduceMotion)
        }
        .modifier(CardLift(trigger: lifts[process.id, default: 0], radius: Self.radius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(process.title)
        .accessibilityValue(isFront ? spokenExchange(process) : "")
        .accessibilityHint(isFront ? DeskText.openTask : DeskText.showConversation)
        .accessibilityAddTraits(isFront ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("ambient.conversation.\(process.id)")
    }

    /// The person's latest request, the agent's latest reply, and what a tap does.
    private func exchange(_ process: AnchorProcess, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let request = process.request {
                Text(request)
                    .font(.system(size: requestSize, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(3)
                    .layoutPriority(1)
            }
            // The reply takes what room is left and ends in an ellipsis.
            Text(reply(for: process))
                .font(.system(size: replySize))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Text(DeskText.openTask)
                .font(.system(size: replySize, weight: .semibold))
                .foregroundStyle(tint.mix(with: AnchorIOSStyle.text, by: 0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(tint.opacity(0.14))
    }

    private var emptyCard: some View {
        Text(DeskText.noConversations)
            .font(.system(size: replySize, weight: .medium))
            .foregroundStyle(AnchorIOSStyle.secondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
                    .fill(AnchorIOSStyle.surface)
                    .shadow(color: .black.opacity(0.1), radius: 9, y: -2)
            }
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

    private func bringToFront(_ process: AnchorProcess, of task: AnchorSession) {
        picks[task.id] = TaskConversationStack.Pick(conversation: process.id, at: .now)
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

    // MARK: Accessibility sizes

    /// Large text gets no overlap: each task's conversations as full cards, newest first.
    private var accessibleList: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(tasks) { task in
                let tint = HostedTaskAppearance.tint(task)
                let stack = TaskConversationStack(task: task)
                VStack(alignment: .leading, spacing: 0) {
                    tab(task, tint: tint, width: .infinity)
                    VStack(alignment: .leading, spacing: 10) {
                        if stack.cards.isEmpty { emptyCard }
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
                            .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: Self.radius, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, -Self.tabTuck)
                }
            }
        }
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
