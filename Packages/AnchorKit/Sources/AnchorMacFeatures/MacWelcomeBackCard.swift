#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// What the Mac says when the person comes back (M4): how long they were away,
/// what they were on, what changed on each task, and what to do first.
public struct MacWelcomeBack: Sendable {
    public let awaySince: Date
    public let returnedAt: Date
    /// The task the person was on, while it is still open.
    public let current: AnchorSession?
    public let overview: ReturnOverview

    public init(tasks: [AnchorSession], currentID: UUID?, awaySince: Date, returnedAt: Date) {
        self.awaySince = awaySince
        self.returnedAt = returnedAt
        current = currentID.flatMap { id in
            tasks.first { $0.id == id && ($0.status == .active || $0.status == .draft) }
        }
        overview = ReturnOverview(tasks: tasks, awaySince: awaySince)
    }

    /// No open task, so there is nothing to come back to.
    public var isEmpty: Bool { current == nil && overview.items.isEmpty }

    /// One click opens what needs the person first, else the task they were on.
    public var taskToOpen: UUID? {
        if let first = overview.first, first.action?.needsPerson == true { return first.task.id }
        return current?.id ?? overview.first?.task.id
    }
}

/// The small card above the edge boat after time away. It is read in a few
/// seconds and gets out of the way: one button opens the task, Esc or the
/// close button dismisses it, and it never takes focus on its own.
public struct MacWelcomeBackCard: View {
    let welcome: MacWelcomeBack
    let onOpen: (UUID) -> Void
    let onDismiss: () -> Void

    public init(welcome: MacWelcomeBack, onOpen: @escaping (UUID) -> Void, onDismiss: @escaping () -> Void) {
        self.welcome = welcome
        self.onOpen = onOpen
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MacWelcomeCopy.title)
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                Text(L10n.returnAwayDuration(welcome.returnedAt.timeIntervalSince(welcome.awaySince)))
                    .font(.subheadline)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                Spacer(minLength: 8)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(width: 22, height: 22)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(MacWelcomeCopy.close)
                .accessibilityLabel(MacWelcomeCopy.close)
                .accessibilityIdentifier("mac.welcome.close")
            }

            if let current = welcome.current { wereOn(current) }

            Divider()

            if welcome.overview.items.isEmpty {
                Text(MacWelcomeCopy.nothingChanged)
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            } else {
                ForEach(welcome.overview.items.prefix(3)) { item in change(item) }
                if welcome.overview.items.count > 3 {
                    Text(MacWelcomeCopy.moreChanged(welcome.overview.items.count - 3))
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
            }

            if let first = welcome.overview.first, let action = first.action, action.needsPerson {
                let symbol = MacNextActionStyle.symbol(for: action)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: symbol.name).foregroundStyle(symbol.color).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PlanText.doFirst)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        Text(first.task.id == welcome.current?.id
                             ? PlanText.line(for: action)
                             : "\(first.task.goal.title) · \(PlanText.line(for: action))")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AnchorPalette.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("mac.welcome.first")
            }

            if let id = welcome.taskToOpen {
                HStack {
                    Spacer()
                    Button(MacWelcomeCopy.openTask) { onOpen(id) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .accessibilityIdentifier("mac.welcome.open")
                }
            }
        }
        .padding(14)
        .frame(width: 340, alignment: .leading)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: MacMetrics.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MacMetrics.cardRadius)
                .strokeBorder(Color(AnchorColorTokens.border), lineWidth: 1)
        }
        .onExitCommand(perform: onDismiss)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(MacWelcomeCopy.title)
        .accessibilityIdentifier("mac.welcome")
    }

    private func wereOn(_ task: AnchorSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(MacWelcomeCopy.wereOn)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnchorPalette.secondaryInk)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(AnchorTaskIdentity.color(for: task)).frame(width: 8, height: 8).accessibilityHidden(true)
                Text(task.goal.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
            }
            if let plan = task.goal.userPlan, let index = plan.nextStepIndex {
                Text("\(PlanText.step(index + 1)) · \(plan.items[index].text)")
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.welcome.current")
    }

    /// One task that changed: its newest change, or the result it still waits on.
    private func change(_ item: ReturnOverview.Item) -> some View {
        let fact = item.changes.first.map { "\($0.title) · \(L10n.runState($0))" }
            ?? item.action.map { PlanText.line(for: $0) } ?? ""
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle().fill(AnchorTaskIdentity.color(for: item.task)).frame(width: 7, height: 7).accessibilityHidden(true)
            Text(item.task.goal.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
                .layoutPriority(1)
            Spacer(minLength: 6)
            Text(fact)
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

enum MacWelcomeCopy {
    static let title = AnchorStrings.value("mac.welcome.title", default: "Welcome back")
    static let wereOn = AnchorStrings.value("mac.welcome.were-on", default: "You were on")
    static let nothingChanged = AnchorStrings.value(
        "mac.welcome.nothing", default: "Nothing changed while you were away.")
    static let openTask = AnchorStrings.value("mac.welcome.open", default: "Open task")
    static let close = AnchorStrings.value("mac.welcome.close", default: "Close (Esc)")

    static func moreChanged(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.welcome.more", default: "Other tasks with changes: %lld"), count)
    }
}
#endif
