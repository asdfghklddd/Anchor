#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The home holds at most three tasks: attention and context are limited too.
enum HomeTaskLimit {
    static let count = 3

    /// Which three to show if more were hosted before the limit: the ones
    /// asking for the person first, otherwise the hosted order.
    static func shown(_ tasks: [AnchorSession]) -> [AnchorSession] {
        guard tasks.count > count else { return tasks }
        let ranked = tasks.enumerated().sorted { a, b in
            let ua = TaskNextAction(task: a.element)?.urgency ?? 9
            let ub = TaskNextAction(task: b.element)?.urgency ?? 9
            return ua == ub ? a.offset < b.offset : ua < ub
        }
        let keep = Set(ranked.prefix(count).map(\.element.id))
        return tasks.filter { keep.contains($0.id) }
    }
}

/// "任务锚定库": a pale panel holding up to three task cards. The cards are
/// for reading at a glance; tapping into a task stays off for now. Swiping a
/// card left shows "已完成" behind it.
struct HomeTaskLibrary: View {
    let tasks: [AnchorSession]
    let currentID: UUID?
    var settlingTaskID: UUID?
    var settledTaskID: UUID?
    var anchorSettles = 0
    var onComplete: (UUID) async -> Bool = { _ in false }
    /// Only one card stands open at a time.
    @State private var openID: UUID?
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(AnchorStrings.value("home.library.title", default: "Anchored tasks"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(HomeStyle.libraryTitle)
                .padding(.leading, 16)
                .padding(.top, 13)
                .accessibilityAddTraits(.isHeader)
            Group {
                if tasks.isEmpty {
                    Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HomeStyle.cardNote)
                        .frame(maxWidth: .infinity, minHeight: HomeTaskCard.height)
                        .accessibilityIdentifier("workspace.empty.processes")
                        // Fades as the first anchor drops, so the drop isn't fighting a jump.
                        .transition(.opacity)
                } else {
                    VStack(spacing: 12) {
                        ForEach(HomeTaskLimit.shown(tasks)) { task in
                            HomeTaskCard(task: task)
                                .modifier(HomeSwipeToComplete(
                                    isOpen: Binding(get: { openID == task.id },
                                                    set: { openID = $0 ? task.id : (openID == task.id ? nil : openID) }),
                                    reduceMotion: reduceMotion,
                                    onComplete: { await onComplete(task.id) }))
                                .overlay(alignment: .topTrailing) {
                                    if tasks.count > 1, task.id == currentID {
                                        HomeCurrentPin().offset(x: 39, y: -21)
                                    }
                                }
                                .modifier(DropSettle(
                                    floating: task.id == settlingTaskID, settles: anchorSettles,
                                    isSettled: task.id == settledTaskID, tint: HomeStyle.task(task),
                                    reduceMotion: reduceMotion, cornerRadius: HomeTaskCard.radius))
                                .accessibilityIdentifier("hosted.task.\(task.id)")
                                .transition(reduceMotion ? .opacity : .scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    // The first card's own drop choreography brings it in.
                    .transition(.asymmetric(insertion: .identity, removal: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 25)
            .padding(.bottom, 19)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeStyle.library, in: .rect(cornerRadius: 18))
        .shadow(color: HomeStyle.cardShadow.opacity(0.13), radius: 10, y: 3)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: tasks.map(\.id))
        .animation(AnchorMotion.micro, value: tasks.isEmpty)
    }
}

/// One task: its color mark, its name and what's next. A task waiting on
/// the person takes a pale wash of its color, like the desk's red-light cards.
struct HomeTaskCard: View {
    let task: AnchorSession
    static let radius: CGFloat = 14
    static let height: CGFloat = 53
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let waiting = TaskNextAction(task: task)?.asksForALook == true
        HStack(spacing: 14) {
            Capsule()
                .fill(HomeStyle.task(task))
                .frame(width: 2.5, height: 15)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.goal.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(HomeStyle.cardText)
                    .lineLimit(1)
                if let line = subtitle {
                    Text(line)
                        .font(.system(size: 11))
                        .foregroundStyle(HomeStyle.cardNote)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 11.5)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? nil : Self.height)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 0)
        .background(waiting ? HomeStyle.wash(task) : AnchorIOSStyle.surface, in: .rect(cornerRadius: Self.radius))
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityValue(HostedTaskStatus(task: task).word)
    }

    private var subtitle: String? {
        if let action = TaskNextAction(task: task) { return PlanText.line(for: action, compact: true) }
        let criteria = task.goal.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        return criteria.isEmpty ? nil : criteria
    }
}

/// Drag a card left to show "已完成" behind it; tap that, or keep dragging
/// past the far edge, to finish the task. A tap on the open card closes it.
private struct HomeSwipeToComplete: ViewModifier {
    @Binding var isOpen: Bool
    let reduceMotion: Bool
    let onComplete: () async -> Bool
    @State private var drag: CGFloat = 0
    @State private var completing = false
    @State private var width: CGFloat = 0
    private static let actionWidth: CGFloat = 84

    func body(content: Content) -> some View {
        let rest: CGFloat = completing ? -width : (isOpen ? -Self.actionWidth : 0)
        let offset = min(0, rest + drag)
        let pastFull = -offset > fullThreshold
        content
            .offset(x: offset)
            .background(alignment: .trailing) {
                Button(action: complete) {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text(AnchorStrings.value("home.task.done", default: "Done"))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(width: max(Self.actionWidth - 8, -offset - 8))
                    .frame(maxHeight: .infinity)
                    .background(HomeStyle.done, in: .rect(cornerRadius: HomeTaskCard.radius))
                }
                .buttonStyle(.plain)
                .opacity(offset < -1 ? 1 : 0)
                .accessibilityHidden(true)
            }
            // The slid card hides at the row's edge; the extra height keeps its shadow.
            .mask { Rectangle().padding(.vertical, -12) }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
            .contentShape(.rect)
            .onTapGesture { if isOpen { settle(open: false) } }
            .gesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        guard !completing, abs(value.translation.width) > abs(value.translation.height) else { return }
                        drag = value.translation.width
                    }
                    .onEnded { value in
                        guard !completing else { return }
                        let end = rest + value.predictedEndTranslation.width
                        if -(rest + drag) > fullThreshold { complete() }
                        else { settle(open: end < -Self.actionWidth / 2) }
                    }
            )
            .sensoryFeedback(.impact(weight: .light), trigger: pastFull) { _, now in now }
            .accessibilityAction(named: AnchorStrings.value("home.task.done", default: "Done"), complete)
    }

    private var fullThreshold: CGFloat { max(Self.actionWidth * 1.6, width * 0.6) }

    private func settle(open: Bool) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity) {
            drag = 0
            isOpen = open
        }
    }

    private func complete() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity) {
            drag = 0
            completing = true
        }
        Task {
            // If it couldn't be finished, the card comes back.
            guard !(await onComplete()) else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity) {
                completing = false
                isOpen = false
            }
        }
    }
}

/// The person's avatar in a pin, on the task they are on now.
private struct HomeCurrentPin: View {
    var body: some View {
        ProfileAvatar(size: 39)
            .padding(6)
            .background(HomeStyle.pin, in: UnevenRoundedRectangle(
                topLeadingRadius: 25.5, bottomLeadingRadius: 0, bottomTrailingRadius: 25.5, topTrailingRadius: 25.5))
            .frame(width: 51, height: 51)
            .accessibilityHidden(true)
    }
}

/// Said when a fourth anchor is asked for; it floats above the anchor button.
struct HomeTaskCapNote: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(AnchorStrings.value("home.cap.message",
                                     default: "Human, your attention and context are limited too. Finish a current task before starting another."))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(HomeStyle.cardText)
                .fixedSize(horizontal: false, vertical: true)
            Button(AnchorStrings.value("home.cap.ok", default: "OK"), action: onDismiss)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(HomeStyle.ink)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 6)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: HomeTaskCard.radius))
        .shadow(color: HomeStyle.cardShadow.opacity(0.16), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("home.cap.note")
    }
}
#endif
