#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The landscape desk board, read from about 60 cm on its stand (D05). It is
/// centered on the task the person is on: its current step large enough to
/// read at a glance (40 pt), the agent's state on it (22 pt), and the answer
/// for the step within reach. The other tasks are chips that say which ones
/// need a look, with how current this copy is. No text is smaller than 17 pt.
/// Nothing moves on its own except real state changes and the one-time
/// arrival, when the anchor drops and sets in the harbor water.
struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    /// Play the anchor drop and its haptic: true only when work just turned
    /// from portrait to landscape.
    var playsArrival = false
    /// Opens a task's details.
    let onTask: (UUID) -> Void
    let onManage: () -> Void
    /// Makes another task the one the person is on.
    var onSelect: (UUID) -> Void = { _ in }
    /// Answers for a step: task, step, done.
    var onStep: (UUID, UUID, Bool) -> Void = { _, _, _ in }
    /// "Not yet": the person looked at the result and the step stays open.
    var onReviewed: (UUID) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var stepScaled: CGFloat = 40
    @ScaledMetric(relativeTo: .title) private var labelScaled: CGFloat = 28
    @ScaledMetric(relativeTo: .title) private var nameScaled: CGFloat = 26
    @ScaledMetric(relativeTo: .title2) private var stateScaled: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var detailScaled: CGFloat = 17
    @ScaledMetric(relativeTo: .title) private var clockScaled: CGFloat = 34

    @State private var drop: CGFloat = 1
    @State private var contacts = 0
    @State private var ripple: CGFloat = 1
    @State private var rowsShown = true
    @State private var stepAnswers = 0
    @State private var keepAwake = DeskKeepAwake()

    // Desk sizes may grow with Dynamic Type but never shrink below the desk floor.
    private var stepSize: CGFloat { max(40, stepScaled) }
    private var labelSize: CGFloat { max(28, labelScaled) }
    private var nameSize: CGFloat { max(26, nameScaled) }
    private var stateSize: CGFloat { max(22, stateScaled) }
    private var detailSize: CGFloat { max(17, detailScaled) }
    private var clockSize: CGFloat { max(34, clockScaled) }

    private var tasks: [AnchorSession] { projection.hostedSessions }

    /// The task the person is on: the selected one, else the first anchored.
    private var current: AnchorSession? {
        projection.session.flatMap { selected in tasks.first { $0.id == selected.id } } ?? tasks.first
    }

    /// The other tasks keep their anchoring order, so place stays a cue from afar.
    private var others: [AnchorSession] { tasks.filter { $0.id != current?.id } }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.everyMinute) { context in
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                topRow(now: context.date)
                                focus(now: context.date)
                                library(maxRows: max(1, others.count), now: context.date)
                            }
                            .padding(16)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 0) {
                                topRow(now: context.date)
                                Spacer(minLength: 8)
                                focus(now: context.date)
                                Spacer(minLength: 0)
                            }
                            .frame(width: max(0, geometry.size.width * 0.58))
                            library(maxRows: 4, now: context.date)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        // The harbor water runs edge to edge, under the home indicator.
        .background {
            GeometryReader { screen in
                harborWater(width: screen.size.width, height: screen.size.height)
            }
            .ignoresSafeArea()
        }
        .background { HarborBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: contacts)
        .sensoryFeedback(.success, trigger: stepAnswers)
        .onAppear {
            keepAwake.start()
            if playsArrival, !tasks.isEmpty { playArrival() }
        }
        .onDisappear { keepAwake.stop() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.screen")
    }

    // MARK: The task the person is on (left)

    private func topRow(now: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(now.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(.system(size: clockSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .contentTransition(reduceMotion ? .opacity : .numericText())
                .accessibilityIdentifier("ambient.time")
            Text("\(L10n.ambientElapsed) \(L10n.minutesShort(elapsedMinutes(at: now)))")
                .font(.system(size: detailSize, weight: .medium))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.8)
                .accessibilityHint(L10n.ambientElapsedHint)
                .accessibilityIdentifier("ambient.focus")
            Spacer(minLength: 4)
            manageButton
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
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
        .accessibilityIdentifier("ambient.tasks.manage")
    }

    @ViewBuilder
    private func focus(now: Date) -> some View {
        if let task = current {
            focusContent(task, now: now)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.glanceEmpty).font(.system(size: labelSize, weight: .semibold)).foregroundStyle(AnchorIOSStyle.text)
                Text(L10n.glanceEmptyDetail).font(.system(size: detailSize)).foregroundStyle(AnchorIOSStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ambient.glance")
        }
    }

    private func focusContent(_ task: AnchorSession, now: Date) -> some View {
        let action = TaskNextAction(task: task)
        let plan = task.goal.userPlan.flatMap { $0.steps.isEmpty ? nil : $0 }
        let status = HostedTaskStatus(task: task)
        return VStack(alignment: .leading, spacing: 10) {
            Button { onTask(task.id) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Circle().fill(HostedTaskAppearance.tint(task)).frame(width: 12, height: 12).accessibilityHidden(true)
                    Text(task.goal.title)
                        .font(.system(size: nameSize, weight: .semibold))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.8)
                    if let plan {
                        Text("\(plan.doneCount)/\(plan.steps.count)")
                            .font(.system(size: stateSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                    }
                    if tasks.count > 1 {
                        Text(PlanText.current)
                            .font(.system(size: detailSize, weight: .bold))
                            .foregroundStyle(HostedTaskAppearance.tint(task))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(AnchorPressButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(task.goal.title)
            .accessibilityValue(accessibleValue(task, status: status, action: action, isCurrent: tasks.count > 1))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("hosted.task.\(task.id)")

            if let plan, let index = plan.nextStepIndex {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlanText.step(index + 1))
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                    Text(plan.items[index].text)
                        .font(.system(size: stepSize, weight: .bold))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(plan.items[index].id)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ambient.step")
            } else if plan != nil {
                Label(PlanText.allStepsDone, systemImage: "checkmark.seal.fill")
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(AnchorStateTone.done.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Without written steps, the task's reported state is the answer.
                Label(status.word, systemImage: status.symbol.name)
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(status.symbol.color)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }

            if let action { agentLine(task, action: action, now: now) }

            if let plan, let index = plan.nextStepIndex {
                answers(task, step: plan.items[index].id, action: action)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: plan?.nextStepIndex)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.glance")
    }

    /// What the agent is doing for this task: a result to fix or check, with
    /// the opening of its reply, or how long a run has been going.
    @ViewBuilder
    private func agentLine(_ task: AnchorSession, action: TaskNextAction, now: Date) -> some View {
        let symbol = PlanCopy.symbol(for: action)
        switch action {
        case let .answer(title), let .fix(title), let .review(title):
            VStack(alignment: .leading, spacing: 4) {
                Label(PlanText.line(for: action), systemImage: symbol.name)
                    .font(.system(size: stateSize, weight: .semibold))
                    .foregroundStyle(symbol.color)
                    .lineLimit(1).minimumScaleFactor(0.75)
                if let detail = Self.latest(in: task, titled: title)?.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: detailSize))
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("ambient.agent")
        case let .wait(_, since):
            Label("\(PlanText.line(for: action)) · \(PlanText.running(since: since, now: now))", systemImage: symbol.name)
                .font(.system(size: stateSize, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.75)
                .accessibilityIdentifier("ambient.agent")
        case .start, .finish:
            EmptyView()
        }
    }

    @ViewBuilder
    private func answers(_ task: AnchorSession, step: UUID, action: TaskNextAction?) -> some View {
        HStack(spacing: 12) {
            Button(PlanText.stepDone, systemImage: "checkmark") {
                stepAnswers += 1
                onStep(task.id, step, true)
            }
            .accessibilityIdentifier("ambient.step.done")
            // "Not yet" answers a result; with none to judge it would mean nothing.
            if action?.judgesAResult == true {
                Button(PlanText.notYet) { onReviewed(task.id) }
                    .accessibilityIdentifier("ambient.step.not-yet")
            }
        }
        .font(.system(size: detailSize, weight: .semibold))
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private static func latest(in task: AnchorSession, titled title: String) -> AnchorProcess? {
        task.taskProcesses.filter { $0.title == title }.max { $0.updatedAt < $1.updatedAt }
    }

    // MARK: The other tasks (right)

    @ViewBuilder
    private func library(maxRows: Int, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if tasks.isEmpty {
                Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                    .font(.system(size: stateSize, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
                    .padding(20)
                    .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.heroRadius))
            } else {
                let overflow = others.count > maxRows
                let shown = overflow ? Array(others.prefix(maxRows - 1)) : others
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, task in
                    chip(task)
                        .opacity(rowsShown ? 1 : 0.4)
                        .offset(y: rowsShown ? 0 : 8)
                        .animation(reduceMotion ? .easeOut(duration: 0.16)
                            : AnchorMotion.continuity.delay(Double(index) * 0.04), value: rowsShown)
                }
                if overflow {
                    Button(action: onManage) {
                        Text(L10n.glanceMore(others.count - shown.count))
                            .font(.system(size: detailSize, weight: .semibold))
                            .foregroundStyle(AnchorIOSStyle.action)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .accessibilityIdentifier("ambient.more")
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Label(SyncText.line(for: projection.freshness, now: now), systemImage: SyncText.symbol(for: projection.freshness))
                    .font(.system(size: detailSize, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(0.85)
                    .accessibilityIdentifier("ambient.freshness")
            }
        }
        // Chips follow real membership changes; ordinary refreshes keep them still.
        .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: others.map(\.id))
        .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.task.library")
    }

    /// Another task: its name, its next move, and a mark when it needs a look.
    /// Tapping makes it the task the person is on.
    private func chip(_ task: AnchorSession) -> some View {
        let action = TaskNextAction(task: task)
        let status = HostedTaskStatus(task: task)
        let needsLook = action?.asksForALook == true
        return Button { onSelect(task.id) } label: {
            HStack(alignment: .center, spacing: 10) {
                Capsule().fill(HostedTaskAppearance.tint(task)).frame(width: 5, height: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.goal.title)
                        .font(.system(size: stateSize, weight: .semibold))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.85)
                    Text(action.map { PlanText.line(for: $0, compact: true) } ?? status.word)
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundStyle(needsLook ? PlanCopy.symbol(for: action!).color : AnchorIOSStyle.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 4)
                if needsLook, let action {
                    Image(systemName: PlanCopy.symbol(for: action).name)
                        .font(.system(size: detailSize + 3, weight: .semibold))
                        .foregroundStyle(PlanCopy.symbol(for: action).color)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.goal.title)
        .accessibilityValue(accessibleValue(task, status: status, action: action, isCurrent: false))
        .accessibilityHint(PlanText.makeCurrentHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("hosted.task.\(task.id)")
    }

    private func accessibleValue(_ task: AnchorSession, status: HostedTaskStatus, action: TaskNextAction?,
                                 isCurrent: Bool) -> String {
        var parts = [isCurrent ? PlanText.current : nil, action.map { PlanText.line(for: $0) }].compactMap { $0 }
        if let plan = task.goal.userPlan, !plan.steps.isEmpty {
            parts.append(PlanText.stepsDone(plan.doneCount, of: plan.steps.count))
        } else if let progress = task.conversationsInJoiningOrder.first?.progress, progress.isFinite {
            parts.append(status.summary)
            parts.append("\(L10n.taskProgress) \(min(1, max(0, progress)).formatted(.percent.precision(.fractionLength(0))))")
        } else {
            parts.append(status.hasSources ? "\(status.summary), \(L10n.cardProgressUnreported)" : status.summary)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: Harbor water and the set anchor

    private func harborWater(width: CGFloat, height: CGFloat) -> some View {
        let anchorX = width * 0.30
        return ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.7)).frame(height: 1.5)
                Rectangle().fill(AnchorIOSStyle.oceanSurface.opacity(0.32))
            }
            .frame(height: 48)
            if !tasks.isEmpty {
                // The rope only shows while the anchor falls.
                Rectangle()
                    .fill(AnchorIOSStyle.secondaryText.opacity(0.6))
                    .frame(width: 1.4, height: max(0, (height - 60) * drop))
                    .opacity(drop < 1 ? 1 : 0)
                    .offset(x: anchorX + 10, y: -44)
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 30, height: 10)
                    .scaleEffect(x: 1 + ripple * 1.6, y: 1 + ripple * 0.6)
                    .opacity(ripple < 1 ? 1 - ripple : 0)
                    .offset(x: anchorX - 4, y: -42)
                HarborAnchorGlyph(color: AnchorIOSStyle.heading.opacity(0.75), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .offset(x: anchorX, y: -22 - (1 - drop) * (height - 60))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
    }

    /// The anchor falls from the top, sets in the water with one haptic, and
    /// the rows settle in. Content is readable from the first frame (D10).
    private func playArrival() {
        guard !reduceMotion else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                contacts += 1
            }
            return
        }
        drop = 0
        rowsShown = false
        withAnimation(.timingCurve(0.45, 0, 0.9, 0.6, duration: 0.42)) { drop = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            contacts += 1
            ripple = 0
            withAnimation(.easeOut(duration: 0.7)) { ripple = 1 }
            rowsShown = true
        }
    }

    private func elapsedMinutes(at date: Date) -> Int {
        guard let startedAt = projection.session?.startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(startedAt) / 60))
    }
}
#endif
