#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import SwiftUI

/// What the Mac can do with a task from its card: answer for a step, file
/// work, and open the full record. Every change syncs to the iPhone.
struct MacTaskActions {
    let setStep: (_ task: UUID, _ step: UUID, _ done: Bool) -> Void
    let markReviewed: (_ task: UUID) -> Void
    let open: (_ task: UUID) -> Void
    let assign: (CodexConversationSummary, _ task: UUID) -> Void
    let ignore: (CodexConversationSummary) -> Void
}

/// The Mac's main page: every task from the iPhone with your next action, its
/// current step and the agent work attached to it; then anything unsorted.
struct MacTasksPage: View {
    let model: AnchorSessionModel
    let sourceSetupModel: MacSourceSetupModel?
    let tasks: [AnchorSession]
    let actions: MacTaskActions
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacMetrics.pageSpacing) {
                MacWorkHeaderView(projection: model.projection, onOpenSettings: onOpenSettings)
                MacGlanceCard(
                    tasks: model.projection.hostedSessions,
                    connection: model.projection.connection,
                    selectedTaskID: nil,
                    onSelectTask: actions.open
                )
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: MacMetrics.pageSpacing) {
                        ForEach(MacTaskOrder.ordered(tasks)) { task in
                            MacTaskCard(
                                task: task,
                                conversations: conversations(of: task),
                                steps: sourceSetupModel?.conversationSteps ?? [:],
                                otherTasks: tasks.filter { $0.id != task.id },
                                now: context.date,
                                actions: actions
                            )
                        }
                        if let sourceSetupModel, !sourceSetupModel.unsortedConversations.isEmpty {
                            MacUnsortedCard(
                                conversations: sourceSetupModel.unsortedConversations,
                                candidates: sourceSetupModel.unsortedCandidates,
                                tasks: tasks,
                                now: context.date,
                                actions: actions
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: MacMetrics.contentWidth, alignment: .leading)
            .padding(.horizontal, MacMetrics.pageInset)
            .padding(.bottom, MacMetrics.pageInset)
        }
        .accessibilityIdentifier("mac.current.screen")
    }

    private func conversations(of task: AnchorSession) -> [CodexConversationSummary] {
        guard let sourceSetupModel else { return [] }
        return MacCodexConversationOrder.ordered(
            sourceSetupModel.codexConversations.filter { sourceSetupModel.conversationTasks[$0.id] == task.id }
        )
    }
}

/// Tasks that need the person come first, then ones with a step to start, then
/// ones an agent is working on; the most recently active leads within each.
enum MacTaskOrder {
    static func ordered(_ tasks: [AnchorSession]) -> [AnchorSession] {
        tasks.sorted { lhs, rhs in
            let left = rank(TaskNextAction(task: lhs)), right = rank(TaskNextAction(task: rhs))
            if left != right { return left < right }
            return lastActivity(lhs) > lastActivity(rhs)
        }
    }

    static func rank(_ action: TaskNextAction?) -> Int {
        action?.urgency ?? TaskNextAction.unplannedUrgency
    }

    private static func lastActivity(_ task: AnchorSession) -> Date {
        task.taskProcesses.map(\.updatedAt).max() ?? task.startedAt
    }
}

enum MacNextActionStyle {
    static func symbol(for action: TaskNextAction) -> (name: String, color: Color) {
        switch action {
        case .answer: ("questionmark.bubble.fill", AnchorStateTone.attention.ink)
        case .fix: ("xmark.octagon.fill", AnchorStateTone.failed.ink)
        case .review: ("eye.fill", AnchorStateTone.attention.ink)
        case .wait: ("hourglass", AnchorPalette.secondaryInk)
        case .start: ("arrow.right.circle.fill", AnchorPalette.interaction)
        case .finish: ("checkmark.seal.fill", AnchorStateTone.done.ink)
        }
    }
}

struct MacTaskCard: View {
    let task: AnchorSession
    let conversations: [CodexConversationSummary]
    let steps: [String: UUID]
    let otherTasks: [AnchorSession]
    let now: Date
    let actions: MacTaskActions

    @State private var showsAllSteps = false
    @State private var copiedStep: UUID?

    private var plan: AnchorUserPlan? { task.goal.userPlan.flatMap { $0.steps.isEmpty ? nil : $0 } }
    private var action: TaskNextAction? { TaskNextAction(task: task) }
    private var commands: [AnchorProcess] { task.taskProcesses.filter { !$0.isCodexTurn } }

    private static func isStart(_ action: TaskNextAction) -> Bool {
        if case .start = action { return true }
        return false
    }

    /// A slim edge marks a task that needs the person now (fix or check).
    private var urgentTint: Color? {
        guard let action, MacTaskOrder.rank(action) <= 1 else { return nil }
        return MacNextActionStyle.symbol(for: action).color
    }

    var body: some View {
        MacCard(tint: urgentTint) {
            VStack(alignment: .leading, spacing: 12) {
                header
                // "Start step N" is what the current-step block already says.
                if let action, !Self.isStart(action) { nextAction(action) }
                if let plan, let current = plan.nextStepIndex { currentStep(plan, index: current) }
                if let plan { allSteps(plan) }
                if !conversations.isEmpty || !commands.isEmpty {
                    Divider()
                    work
                }
            }
        }
        .accessibilityIdentifier("mac.task.\(task.id)")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(AnchorTaskIdentity.color(for: task))
                .frame(width: 9, height: 9)
                .accessibilityHidden(true)
            Text(task.goal.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(2)
            Spacer(minLength: 8)
            if let plan {
                Text("\(plan.doneCount)/\(plan.steps.count)")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .accessibilityLabel(PlanText.stepsDone(plan.doneCount, of: plan.steps.count))
            }
            Button(MacTaskCopy.details, systemImage: "chevron.right") { actions.open(task.id) }
                .buttonStyle(.borderless)
                .labelStyle(.titleAndIcon)
                .accessibilityIdentifier("mac.task.details")
        }
    }

    private func nextAction(_ action: TaskNextAction) -> some View {
        let symbol = MacNextActionStyle.symbol(for: action)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol.name)
                .foregroundStyle(symbol.color)
                .accessibilityHidden(true)
            Text(PlanText.line(for: action))
                .font(.callout.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
            if case let .wait(_, since) = action {
                Text(PlanText.running(since: since, now: now))
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func currentStep(_ plan: AnchorUserPlan, index: Int) -> some View {
        let step = plan.items[index]
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanText.step(index + 1))
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                Text(step.text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AnchorPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(PlanText.stepDone, systemImage: "checkmark") {
                    actions.setStep(task.id, step.id, true)
                }
                .accessibilityIdentifier("mac.task.step.done")
                if action?.judgesAResult == true {
                    Button(PlanText.notYet) { actions.markReviewed(task.id) }
                }
                if let prompt = PlanText.prompt(goal: task.goal, step: index) {
                    Button(copiedStep == step.id ? PlanText.copied : PlanText.copyPrompt,
                           systemImage: copiedStep == step.id ? "checkmark" : "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(prompt, forType: .string)
                        copiedStep = step.id
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("mac.task.copy")
                }
            }
            .controlSize(.regular)
        }
    }

    private func allSteps(_ plan: AnchorUserPlan) -> some View {
        DisclosureGroup(isExpanded: $showsAllSteps) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(plan.items.enumerated()), id: \.element.id) { index, step in
                    Button {
                        actions.setStep(task.id, step.id, !step.isDone)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(step.isDone ? AnchorStateTone.done.ink : AnchorPalette.secondaryInk)
                            Text("\(index + 1). \(step.text)")
                                .foregroundStyle(step.isDone ? AnchorPalette.secondaryInk : AnchorPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(step.isDone ? PlanText.doneState : PlanText.openState)
                }
            }
            .padding(.top, 6)
        } label: {
            Text(MacTaskCopy.allSteps(plan.steps.count))
                .font(.callout)
                .foregroundStyle(AnchorPalette.secondaryInk)
        }
    }

    private var work: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(conversations) { conversation in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    MacCodexConversationRow(
                        conversation: conversation,
                        status: MacCodexConversationStatus(conversation, now: now),
                        note: stepNote(for: conversation)
                    )
                    Menu {
                        Menu(MacTaskCopy.moveTo) {
                            ForEach(otherTasks) { other in
                                Button(other.goal.title) { actions.assign(conversation, other.id) }
                            }
                        }
                        .disabled(otherTasks.isEmpty)
                        Button(MacTaskCopy.notPartOfTask) { actions.ignore(conversation) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .accessibilityLabel(MacTaskCopy.moveTo)
                }
            }
            ForEach(commands) { command in
                HStack(spacing: 10) {
                    Image(systemName: command.status == .running ? "terminal.fill" : "terminal")
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    Text(command.title)
                        .font(.callout.monospaced())
                        .foregroundStyle(AnchorPalette.ink)
                        .lineLimit(1)
                    Text(L10n.status(command.status))
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Spacer(minLength: 8)
                    Text(command.updatedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func stepNote(for conversation: CodexConversationSummary) -> String? {
        guard let stepID = steps[conversation.id], let index = plan?.index(of: stepID) else { return nil }
        return PlanText.step(index + 1)
    }
}

/// Recent conversations Anchor could not place with confidence: one click files them.
struct MacUnsortedCard: View {
    let conversations: [CodexConversationSummary]
    let candidates: [String: [UUID]]
    let tasks: [AnchorSession]
    let now: Date
    let actions: MacTaskActions

    var body: some View {
        MacCard(MacTaskCopy.unsortedTitle, symbol: "tray") {
            Text("\(conversations.count)")
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(AnchorPalette.secondaryInk)
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                Text(MacTaskCopy.unsortedDetail)
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .padding(.bottom, 4)
                ForEach(conversations) { conversation in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        MacCodexConversationRow(
                            conversation: conversation,
                            status: MacCodexConversationStatus(conversation, now: now)
                        )
                        Menu(MacTaskCopy.fileUnder) {
                            ForEach(ordered(for: conversation)) { task in
                                Button(task.goal.title) { actions.assign(conversation, task.id) }
                            }
                        }
                        .fixedSize()
                        .accessibilityIdentifier("mac.unsorted.file")
                        Button(MacTaskCopy.notPartOfTask) { actions.ignore(conversation) }
                            .buttonStyle(.borderless)
                    }
                }
            }
        }
        .accessibilityIdentifier("mac.unsorted")
    }

    /// The tasks its words leaned towards come first.
    private func ordered(for conversation: CodexConversationSummary) -> [AnchorSession] {
        let leaning = candidates[conversation.id] ?? []
        return tasks.sorted { lhs, rhs in
            let left = leaning.firstIndex(of: lhs.id) ?? Int.max
            let right = leaning.firstIndex(of: rhs.id) ?? Int.max
            return left == right ? lhs.goal.title < rhs.goal.title : left < right
        }
    }
}

enum MacTaskCopy {
    static let details = AnchorStrings.value("mac.tasks.details", default: "Details")
    static let moveTo = AnchorStrings.value("mac.tasks.move", default: "Move to")
    static let fileUnder = AnchorStrings.value("mac.unsorted.file", default: "File under")
    static let notPartOfTask = AnchorStrings.value("mac.unsorted.ignore", default: "Not part of a task")
    static let unsortedTitle = AnchorStrings.value("mac.unsorted.title", default: "Unsorted")
    static let unsortedDetail = AnchorStrings.value(
        "mac.unsorted.detail", default: "Anchor wasn't sure which task these belong to.")

    static func allSteps(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("mac.tasks.all-steps", default: "All %lld steps"), count)
    }
}
#endif
