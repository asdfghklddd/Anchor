// Role: the task card opened from a folder tab: plan on the left, conversations and finish on the right,
// with in-place editing. An open edit saves on close.
// Note: `ProfileDetailSheet` still opens instead at accessibility text sizes. `KeyboardTopReader` uses
// `keyboardLayoutGuide` because keyboard notifications did not shrink the card here.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

public extension EnvironmentValues {
    /// Saves a change made on the desk; false when it could not be saved.
    @Entry var sendTaskCommand: @MainActor @Sendable (SessionCommand) async -> Bool = { _ in false }
}

/// A task opened from the desk, over the whole library, the way a conversation
/// opens: the person's plan on the left, checked off with a tap, and the task's
/// conversations on the right. Edit turns the name and the steps into fields
/// right here, and the card rises above the keyboard. Tapping beside it or
/// swiping it down closes it; an edit still open is saved as it goes.
struct DeskTaskCard: View {
    let task: AnchorSession
    let palette: DeskFolderPalette
    /// The tallest the card may be, the library's own height.
    let maxHeight: CGFloat
    let onConversation: (AnchorProcess) -> Void
    let onClosed: () -> Void

    @Environment(\.sendTaskCommand) private var send
    @AnchorReducedMotion private var reduceMotion
    @State private var editing = false
    @State private var title = ""
    @State private var steps: [AnchorUserPlan.Step] = []
    @State private var newStep = ""
    @FocusState private var focus: Field?
    @State private var confirmingFinish = false
    @State private var images: [Data] = []
    @State private var savedChecks = 0
    /// How tall the plan and the conversations want to be, so the card hugs them.
    @State private var planHeight: CGFloat = 0
    @State private var sideHeight: CGFloat = 0
    /// Where the keyboard starts and the card starts, on screen.
    @State private var keyboardTop: CGFloat?
    @State private var cardTop: CGFloat = 0

    /// Which editable field has focus.
    private enum Field: Hashable {
        case title, step(UUID), new
    }

    private static let header: CGFloat = 62
    private static let minimumBody: CGFloat = 150
    private static let sideWidth: CGFloat = 186

    private var plan: AnchorUserPlan? { task.goal.userPlan }
    private var conversations: [AnchorProcess] {
        TaskConversationStack.conversations(of: task).sorted {
            if $0.needsRescue != $1.needsRescue { return $0.needsRescue }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var height: CGFloat {
        guard let keyboardTop else { return maxHeight }
        return min(maxHeight, max(Self.header + 56, keyboardTop - cardTop - 8))
    }

    private var bodyHeight: CGFloat {
        let wanted = max(planHeight, editing ? 0 : sideHeight, Self.minimumBody)
        return min(wanted, height - Self.header)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DeskStyle.quietInk.opacity(0.45))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .accessibilityHidden(true)
            headerRow
            HStack(alignment: .top, spacing: 14) {
                planColumn
                if !editing {
                    side
                        .frame(width: Self.sideWidth)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .frame(height: bodyHeight, alignment: .top)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .background(DeskStyle.card, in: .rect(cornerRadius: 24, style: .continuous))
        .contentShape(.rect(cornerRadius: 24, style: .continuous))
        .compositingGroup()
        .shadow(color: palette.glow.opacity(0.28), radius: 24, y: 4)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { cardTop = $0 }
        .background {
            KeyboardTopReader { top in
                guard top != keyboardTop else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.3, bounce: 0)) {
                    keyboardTop = top
                }
            }
            .accessibilityHidden(true)
        }
        .sensoryFeedback(.success, trigger: savedChecks)
        .task(id: task.goal.id) { await loadImages() }
        .onDisappear { if editing { save() } }
    }

    // MARK: The head

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if editing {
                TextField(L10n.goalTitle, text: $title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(titleIsTooLong ? AnchorIOSStyle.attentionInk : DeskStyle.text)
                    .focused($focus, equals: .title)
                    .submitLabel(.done)
                    .accessibilityIdentifier("desk.task.title.field")
            } else {
                Text(task.goal.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DeskStyle.text)
                    .lineLimit(1)
                Text(HostedTaskStatus(task: task).word)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(editing ? L10n.done : PlanText.edit) {
                if editing { finishEditing() } else { startEditing() }
            }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.ink)
                .buttonStyle(AnchorPressButtonStyle(.control))
                .disabled(editing && titleIsTooLong)
                .frame(minWidth: 44, minHeight: 36)
                .contentShape(.rect)
                .accessibilityIdentifier("desk.task.edit")
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .frame(height: Self.header - 12)
    }

    /// Only a title that grows past the limit blocks saving; an older, longer
    /// title can still be kept or shortened.
    private var titleIsTooLong: Bool {
        let units = AnchorTitleLength.units(of: title)
        return units > AnchorTitleLength.limit && units > AnchorTitleLength.units(of: task.goal.title)
    }

    // MARK: The plan

    private var planColumn: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if editing {
                        editableSteps
                    } else if let plan, !plan.items.isEmpty {
                        ForEach(Array(plan.items.enumerated()), id: \.element.id) { index, step in
                            stepRow(step, index: index, isNext: plan.nextStepIndex == index)
                        }
                    } else {
                        Button { startEditing(focusing: .new) } label: {
                            Label(PlanText.addStepPlaceholder, systemImage: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(palette.ink)
                                .frame(minHeight: 36)
                        }
                        .buttonStyle(AnchorPressButtonStyle())
                        .accessibilityIdentifier("desk.task.plan.add")
                    }
                    if !images.isEmpty, !editing {
                        AnchorSetupPhotos(images: images)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { planHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.never)
            .onChange(of: focus) { _, field in
                guard let field else { return }
                withAnimation(.easeOut(duration: 0.2)) { reader.scrollTo(field, anchor: .center) }
            }
            // The keyboard arrives after the focus and takes the room the field was in.
            .onChange(of: keyboardTop) { _, top in
                guard top != nil, let focus else { return }
                withAnimation(.easeOut(duration: 0.2)) { reader.scrollTo(focus, anchor: .center) }
            }
        }
        .accessibilityIdentifier("desk.task.plan")
    }

    /// A step checked with a tap; the next one clear, the done ones quiet.
    private func stepRow(_ step: AnchorUserPlan.Step, index: Int, isNext: Bool) -> some View {
        Button { toggle(step) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(step.isDone || isNext ? palette.ink : DeskStyle.quietInk)
                    .contentTransition(.symbolEffect(.replace))
                Text(step.text)
                    .font(.system(size: 14, weight: isNext ? .medium : .regular))
                    .foregroundStyle(step.isDone ? DeskStyle.quietInk : DeskStyle.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .frame(minHeight: 36)
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityLabel("\(index + 1). \(step.text)")
        .accessibilityValue(step.isDone ? PlanText.doneState : PlanText.openState)
        .accessibilityHint(PlanText.toggleHint)
        .accessibilityIdentifier("desk.task.step.\(index)")
    }

    @ViewBuilder
    private var editableSteps: some View {
        ForEach($steps) { $step in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { steps.removeAll { $0.id == step.id } }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(DeskStyle.quietInk)
                        .frame(minWidth: 28, minHeight: 36)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.delete)
                TextField(PlanText.stepPlaceholder, text: $step.text, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(DeskStyle.text)
                    .lineLimit(1...4)
                    .focused($focus, equals: .step(step.id))
            }
            .id(Field.step(step.id))
        }
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(palette.ink)
                .frame(minWidth: 28, minHeight: 36)
                .accessibilityHidden(true)
            TextField(PlanText.addStepPlaceholder, text: $newStep)
                .font(.system(size: 14))
                .foregroundStyle(DeskStyle.text)
                .focused($focus, equals: .new)
                .submitLabel(.next)
                .onSubmit(addStep)
                .accessibilityIdentifier("desk.task.step.new")
        }
        .id(Field.new)
    }

    // MARK: The conversations

    private var side: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if conversations.isEmpty {
                        Text(DeskText.noConversations)
                            .font(.system(size: 12))
                            .foregroundStyle(DeskStyle.quietInk)
                    }
                    ForEach(conversations) { conversationRow($0) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height + 66 } action: { sideHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            Button { confirmingFinish = true } label: {
                Text(L10n.completeSession)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(DeskStyle.card.opacity(0.7), in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(AnchorPressButtonStyle(.control))
            .accessibilityIdentifier("desk.task.finish")
            .confirmationDialog(L10n.finishConfirmTitle, isPresented: $confirmingFinish, titleVisibility: .visible) {
                Button(L10n.completeSession) { complete() }
                    .accessibilityIdentifier("desk.task.finish.confirm")
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.finishConfirmDetail)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.front.opacity(0.6), in: .rect(cornerRadius: 16, style: .continuous))
    }

    /// A conversation and where it stands; a tap opens its own card.
    private func conversationRow(_ process: AnchorProcess) -> some View {
        Button { onConversation(process) } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(process.needsRescue ? palette.ink : DeskStyle.quietInk.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(process.title)
                    .font(.system(size: 13))
                    .foregroundStyle(DeskStyle.text)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(L10n.compactStatus(process.status))
                    .font(.system(size: 11))
                    .foregroundStyle(process.needsRescue ? palette.ink : DeskStyle.quietInk)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(minHeight: 34)
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityIdentifier("desk.task.conversation.\(process.id)")
    }

    // MARK: Changes

    private func toggle(_ step: AnchorUserPlan.Step) {
        let done = !step.isDone
        let allDoneAfter = done && (plan?.items.filter { !$0.isDone }.count == 1)
        Task {
            // Success follows the save, not the tap: a failed save never ticks.
            guard await send(.forSession(task.id, .setPlanStep(id: step.id, done: done))), done else { return }
            savedChecks += 1
            AnchorSound.shared.play(allDoneAfter ? .planDone : .step)
        }
    }

    private func startEditing(focusing field: Field? = nil) {
        title = task.goal.title
        steps = plan?.items ?? []
        newStep = ""
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.35, bounce: 0.05)) { editing = true }
        focus = field
    }

    private func finishEditing() {
        save()
        focus = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.35, bounce: 0.05)) { editing = false }
    }

    private func addStep() {
        let text = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        steps.append(AnchorUserPlan.Step(text: text))
        newStep = ""
        focus = .new
    }

    /// Saves what changed. A name that would not fit, or a plan left with no
    /// steps at all, keeps what was there.
    private func save() {
        addStep()
        let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let saveTitle = !newTitle.isEmpty && !titleIsTooLong && newTitle != task.goal.title
        let kept = steps.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let saveSteps = !kept.isEmpty && steps != (plan?.items ?? [])
        let (id, goal, edited) = (task.id, task.goal, steps)
        Task {
            if saveTitle {
                _ = await send(.forSession(id, .updateGoal(title: newTitle, completionCriteria: goal.completionCriteria,
                                                           note: goal.note)))
            }
            if saveSteps { _ = await send(.forSession(id, .updatePlanSteps(edited))) }
        }
    }

    private func complete() {
        Task {
            guard await send(.forSession(task.id, .completeSession)) else { return }
            AnchorSound.shared.play(.taskDone)
            onClosed()
        }
    }

    private func loadImages() async {
        guard let names = plan?.localImageNames, !names.isEmpty else { return }
        let goalID = task.goal.id
        let loaded = await Task.detached(priority: .userInitiated) {
            AnchorPlanImages.load(goalID: goalID, names: names)
        }.value
        guard !Task.isCancelled else { return }
        images = loaded
    }
}

/// Where the keyboard starts in the window, none while it is away, from the
/// system's own guide: it follows every kind of keyboard on the desk.
private struct KeyboardTopReader: UIViewRepresentable {
    let onChange: (CGFloat?) -> Void

    func makeUIView(context: Context) -> Host {
        let host = Host()
        host.onChange = onChange
        return host
    }

    func updateUIView(_ host: Host, context: Context) {
        host.onChange = onChange
    }

    final class Host: UIView {
        var onChange: ((CGFloat?) -> Void)?
        private let marker = Marker()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            marker.translatesAutoresizingMaskIntoConstraints = false
            marker.isUserInteractionEnabled = false
            addSubview(marker)
            NSLayoutConstraint.activate([
                marker.topAnchor.constraint(equalTo: keyboardLayoutGuide.topAnchor),
                marker.leadingAnchor.constraint(equalTo: leadingAnchor),
                marker.widthAnchor.constraint(equalToConstant: 1),
                marker.heightAnchor.constraint(equalToConstant: 1),
            ])
            marker.onMove = { [weak self] in self?.report() }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        private func report() {
            guard let window else { return }
            let top = marker.convert(marker.bounds, to: window).minY
            // With no keyboard the guide rests at the bottom of the screen.
            let isUp = top < window.bounds.height - 60
            DispatchQueue.main.async { [weak self] in self?.onChange?(isUp ? top : nil) }
        }
    }

    final class Marker: UIView {
        var onMove: (() -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onMove?()
        }

        override var center: CGPoint {
            didSet { if center != oldValue { onMove?() } }
        }
    }
}
#endif
