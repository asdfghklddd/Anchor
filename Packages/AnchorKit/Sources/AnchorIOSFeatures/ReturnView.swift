#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

/// The return is a review step between being away and resuming the workspace.
/// It presents the current task and real changes in the four-card layout.
struct ReturnView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel

    @Environment(\.scenePhase) private var scenePhase
    @AnchorReducedMotion private var reduceMotion
    @State private var feedbackCount = 0
    @State private var cardsPresented = false
    @State private var animateEntrance = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProcess: AnchorProcess?
    @State private var showsContext = false
    @State private var isContinuing = false
    @State private var showAllChanges = false
    @State private var stepFeedback = 0
    @State private var copiedStep: UUID?
    /// The task whose every change is listed in a sheet.
    @State private var changesFor: ReturnOverview.Item?

    private let ink = Color(red: 0.11, green: 0.15, blue: 0.17)
    private let secondaryInk = Color(red: 0.43, green: 0.48, blue: 0.50)

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .padding(.bottom, 10)

                    enteringCard(taskCard, index: 0)
                    if review.overview.items.isEmpty {
                        enteringCard(changesCard, index: 1)
                        enteringCard(workCard, index: 2)
                        enteringCard(nextCard, index: 3)
                    } else {
                        ForEach(Array(review.overview.items.enumerated()), id: \.element.id) { index, item in
                            enteringCard(taskReturnCard(item), index: index + 1)
                        }
                        if review.overview.unchangedCount > 0 {
                            Text(PlanText.othersUnchanged(review.overview.unchangedCount))
                                .font(.caption)
                                .foregroundStyle(secondaryInk)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityIdentifier("return.unchanged")
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { backButton }
        .sheet(item: $selectedProcess) { process in processSheet(process) }
        .sheet(isPresented: $showsContext) { contextSheet }
        .sheet(isPresented: $showAllChanges) { changesSheet }
        .sheet(item: $changesFor) { item in taskChangesSheet(item) }
        .preferredColorScheme(.light)
        .sensoryFeedback(.success, trigger: feedbackCount)
        .sensoryFeedback(.success, trigger: stepFeedback)
        .onAppear { presentReturnIfActive() }
        .onChange(of: scenePhase) { _, _ in presentReturnIfActive() }
    }

    private func presentReturnIfActive() {
        guard scenePhase == .active, !cardsPresented else { return }
        // Share the once-per-return claim with feedback, so data refreshes,
        // rotation and leaving a sheet do not replay the entrance.
        let firstPresentation = model.claimReturnFeedback()
        animateEntrance = firstPresentation
        cardsPresented = true
        if firstPresentation { feedbackCount += 1 }
    }

    private func enteringCard<Content: View>(_ content: Content, index: Int) -> some View {
        content
            .scaleEffect(cardsPresented || reduceMotion ? 1 : 0.92)
            .offset(y: cardsPresented || reduceMotion ? 0 : 22)
            .opacity(cardsPresented ? 1 : 0)
            .animation(
                animateEntrance
                    ? (reduceMotion
                        ? .easeOut(duration: 0.16)
                        : .spring(duration: 0.36, bounce: 0.26).delay(Double(index) * 0.035))
                    : nil,
                value: cardsPresented
            )
    }

    private var background: some View {
        ZStack {
            Color(red: 0.975, green: 0.982, blue: 0.984)
            RadialGradient(
                colors: [Color(red: 0.73, green: 0.94, blue: 0.97).opacity(0.70), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 350
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.returnWhileAway)
                .font(.title3.weight(.semibold))
                .foregroundStyle(ink)
                .accessibilityIdentifier("return.screen")
                .accessibilityAddTraits(.isHeader)
            Text(projection.connection == .connected ? L10n.returnSubtitle : L10n.returnSavedRecords)
                .font(.caption)
                .foregroundStyle(secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 1)
    }

    private var review: ReturnReviewContent { ReturnReviewContent(projection: projection) }

    private var taskCard: some View {
        returnCard {
            VStack(spacing: 9) {
                Text(review.session?.goal.title ?? L10n.currentGoal)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("return.goal.title")
                if let elapsed = review.elapsedSeconds {
                    Text(L10n.returnAwayDuration(elapsed))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(secondaryInk)
                }
            }
            .frame(maxWidth: .infinity)
            if let first = review.overview.first, let action = first.action, action.needsPerson,
               action.asksForALook || review.overview.items.count > 1 {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: PlanCopy.symbol(for: action).name)
                        .foregroundStyle(PlanCopy.symbol(for: action).color)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(PlanText.doFirst)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryInk)
                        // The task named above needs no second mention.
                        Text(first.task.id == review.session?.id
                             ? PlanText.line(for: action)
                             : "\(first.task.goal.title) · \(PlanText.line(for: action))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("return.first")
            }
            if let context = review.context {
                Button { showsContext = true } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(review.anchorNote == nil ? L10n.contextNote : L10n.returnAnchorRecord, systemImage: "bookmark")
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(secondaryInk)
                        Text(context)
                            .font(.caption)
                            .foregroundStyle(ink)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("return.context.button")
            }
        }
        .accessibilityIdentifier("return.task.card")
    }

    private var changesCard: some View {
        returnCard {
            HStack(alignment: .firstTextBaseline) {
                cardHeading(L10n.returnChanges)
                Spacer(minLength: 8)
                Text("\(changes.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(secondaryInk)
                    .accessibilityIdentifier("return.changes.count")
            }

            if changes.isEmpty {
                Text(L10n.returnNoReceivedChanges)
                    .font(.subheadline)
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(changes.prefix(2))) { change in
                    changeRow(change, expanded: false)
                }
                Button(L10n.returnChangesSummary(changes.count)) {
                    showAllChanges = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnchorIOSStyle.action)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityIdentifier("return.changes.all.button")
            }
        }
        .accessibilityIdentifier("return.changes.card")
    }

    private func changeRow(_ change: ReturnChange, expanded: Bool) -> some View {
        let interrupted = change.title == "Codex turn_aborted"
        let symbol = interrupted ? "pause.circle.fill" : eventSymbol(change.kind)
        let color: Color = interrupted ? AnchorStateTone.attention.ink
            : (change.kind == .failed ? AnchorStateTone.failed.ink
                : (change.kind == .completed ? AnchorStateTone.done.ink : AnchorIOSStyle.action))
        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(color)
                .frame(minWidth: 16, alignment: .leading)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(changeTitle(change, interrupted: interrupted))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ink)
                    .lineLimit(expanded || dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                if expanded && !change.detail.isEmpty {
                    Text(change.detail)
                        .font(.caption)
                        .foregroundStyle(secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    if let process = review.process(for: change) {
                        Text(process.sourceName)
                    }
                    Text(change.occurredAt, style: .time)
                        .monospacedDigit()
                }
                .font(.caption2)
                .foregroundStyle(secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Raw lifecycle names ("Codex task_complete") become a readable sentence.
    private func changeTitle(_ change: ReturnChange, interrupted: Bool) -> String {
        guard CodexLifecycleRecord.eventTitles.contains(change.title) else { return change.title }
        let subject = review.process(for: change)?.title ?? "Codex"
        return "\(subject) \(L10n.eventVerb(change.kind, interrupted: interrupted))"
    }

    private var changesSheet: some View {
        NavigationStack {
            List(changes) { change in
                changeRow(change, expanded: true)
                    .padding(.vertical, 6)
            }
            .accessibilityIdentifier("return.changes.list")
            .navigationTitle(L10n.returnChanges)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { showAllChanges = false }
                        .accessibilityIdentifier("return.changes.done")
                }
            }
        }
    }

    private var workCard: some View {
        returnCard {
            cardHeading(L10n.returnWorkNow)
            if review.processes.isEmpty {
                Text(L10n.returnNoTaskRecords)
                    .font(.subheadline).foregroundStyle(secondaryInk)
            } else {
                let columns = dynamicTypeSize.isAccessibilitySize ? 2 : 4
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: columns), alignment: .leading, spacing: 14) {
                    metric(review.runningCount, label: L10n.returnRunning, symbol: "play.fill", color: AnchorStateTone.running.ink)
                        .accessibilityIdentifier("return.work.running")
                    metric(review.completedCount, label: L10n.returnCompleted, symbol: "checkmark.seal.fill", color: AnchorStateTone.done.ink)
                        .accessibilityIdentifier("return.work.completed")
                    metric(review.failedCount, label: L10n.returnFailed, symbol: "xmark.octagon.fill", color: AnchorStateTone.failed.ink)
                        .accessibilityIdentifier("return.work.failed")
                    metric(review.attentionCount, label: L10n.returnAttention, symbol: "exclamationmark.circle.fill", color: AnchorStateTone.attention.ink)
                        .accessibilityIdentifier("return.work.attention")
                }
                if review.queuedCount > 0 {
                    Text(L10n.returnQueued(review.queuedCount))
                        .font(.caption).foregroundStyle(secondaryInk)
                }
            }
        }
        .accessibilityIdentifier("return.work.card")
    }

    /// With written steps, the next step is the person's own: answer for it, then see what follows.
    @ViewBuilder
    private var nextCard: some View {
        if let plan = review.session?.goal.userPlan, !plan.steps.isEmpty,
           let action = review.session.flatMap(TaskNextAction.init(task:)) {
            planStepCard(plan, action: action)
        } else {
            nextStepCard
        }
    }

    private func planStepCard(_ plan: AnchorUserPlan, action: TaskNextAction) -> some View {
        returnCard {
            cardHeading(L10n.yourNextStep)
            switch action {
            case .answer, .fix, .review, .wait:
                Button {
                    if let process = review.nextProcess ?? review.processes.max(by: { $0.updatedAt < $1.updatedAt }) {
                        selectedProcess = process
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: PlanCopy.symbol(for: action).name)
                            .foregroundStyle(PlanCopy.symbol(for: action).color)
                            .accessibilityHidden(true)
                        Text(PlanText.line(for: action))
                            .foregroundStyle(ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").foregroundStyle(secondaryInk)
                    }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.returnViewRecord)
                .accessibilityIdentifier("return.plan.result")
            case .start, .finish:
                EmptyView()
            }
            if let task = review.session { stepBlock(task: task, plan: plan, action: action) }
        }
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: plan.completedSteps)
        .accessibilityIdentifier("return.plan.card")
    }

    /// One task that changed while the person was away: what happened, then its step question.
    private func taskReturnCard(_ item: ReturnOverview.Item) -> some View {
        returnCard {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(AnchorTaskIdentity.color(for: item.task))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(item.task.goal.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let plan = item.task.goal.userPlan, !plan.steps.isEmpty {
                    Text("\(plan.doneCount)/\(plan.steps.count)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(secondaryInk)
                        .accessibilityLabel(PlanText.stepsDone(plan.doneCount, of: plan.steps.count))
                }
            }
            if !item.changes.isEmpty {
                // Every state the task's work reports, so mixed outcomes are never collapsed (D02).
                Text(HostedTaskStatus(task: item.task).summary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("return.task.summary")
            }
            ForEach(item.changes.prefix(3)) { process in resultRow(process) }
            if item.changes.count > 3 {
                Button(L10n.returnChangesSummary(item.changes.count)) { changesFor = item }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AnchorIOSStyle.action)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityIdentifier("return.changes.all.button")
            }
            if let plan = item.task.goal.userPlan, !plan.steps.isEmpty, let action = item.action {
                Divider()
                stepBlock(task: item.task, plan: plan, action: action)
            }
        }
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: item.task.goal.userPlan?.completedSteps)
        .accessibilityIdentifier("return.task.\(item.task.id)")
    }

    /// A piece of work and what it reported, with the opening of its reply when there is one.
    private func resultRow(_ process: AnchorProcess) -> some View {
        Button { selectedProcess = process } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: Self.symbol(for: process).name)
                    .foregroundStyle(Self.symbol(for: process).color)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(([process.title, Self.word(for: process)] + [process.testOutcome.map(PlanText.tests)].compactMap { $0 })
                        .joined(separator: " · "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ink)
                    if !process.detail.isEmpty {
                        Text(process.detail)
                            .font(.caption)
                            .foregroundStyle(secondaryInk)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 36)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(L10n.returnViewRecord)
        .accessibilityIdentifier("return.result")
    }

    /// Every change one task reported while the person was away, in full.
    private func taskChangesSheet(_ item: ReturnOverview.Item) -> some View {
        NavigationStack {
            List(item.changes) { process in
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text("\(process.title) · \(Self.word(for: process))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ink)
                    } icon: {
                        Image(systemName: Self.symbol(for: process).name)
                            .foregroundStyle(Self.symbol(for: process).color)
                    }
                    if !process.detail.isEmpty {
                        Text(process.detail)
                            .font(.caption)
                            .foregroundStyle(secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 6) {
                        Text(process.sourceName)
                        Text(process.updatedAt, style: .time).monospacedDigit()
                    }
                    .font(.caption2)
                    .foregroundStyle(secondaryInk)
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }
            .accessibilityIdentifier("return.changes.list")
            .navigationTitle(item.task.goal.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { changesFor = nil }
                        .accessibilityIdentifier("return.changes.done")
                }
            }
        }
    }

    private static func symbol(for process: AnchorProcess) -> (name: String, color: Color) {
        if process.isInterrupted { return ("pause.circle.fill", AnchorIOSStyle.secondaryText) }
        switch process.status {
        case .completed: return ("checkmark.circle.fill", AnchorStateTone.done.ink)
        case .failed: return ("xmark.octagon.fill", AnchorStateTone.failed.ink)
        case .running: return ("play.circle.fill", AnchorStateTone.running.ink)
        case .needsDecision, .blocked, .disconnected: return ("exclamationmark.circle.fill", AnchorStateTone.attention.ink)
        case .queued: return ("circle.dashed", AnchorIOSStyle.secondaryText)
        }
    }

    private static func word(for process: AnchorProcess) -> String { L10n.runState(process) }

    /// The current step of a task's plan with its answers, the copy button and what follows.
    @ViewBuilder
    private func stepBlock(task: AnchorSession, plan: AnchorUserPlan, action: TaskNextAction) -> some View {
        if let current = plan.nextStepIndex {
            let step = plan.items[current]
            VStack(alignment: .leading, spacing: 3) {
                Text(PlanText.step(current + 1))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(secondaryInk)
                Text(step.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("return.plan.step")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { answerButtons(task: task, step: step.id, action: action) }
                VStack(alignment: .leading, spacing: 8) { answerButtons(task: task, step: step.id, action: action) }
            }
            if let prompt = PlanText.prompt(goal: task.goal, step: current) {
                Button(copiedStep == step.id ? PlanText.copied : PlanText.copyPrompt,
                       systemImage: copiedStep == step.id ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = prompt
                    copiedStep = step.id
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("return.plan.copy")
            }
            if current + 1 < plan.steps.count {
                Text("\(PlanText.then) · \(PlanText.step(current + 2)) · \(plan.steps[current + 1])")
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Label(PlanText.allStepsDone, systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AnchorStateTone.done.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func answerButtons(task: AnchorSession, step: UUID, action: TaskNextAction) -> some View {
        Button(PlanText.stepDone, systemImage: "checkmark") {
            stepFeedback += 1
            copiedStep = nil
            Task { _ = await model.send(.forSession(task.id, .setPlanStep(id: step, done: true))) }
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("return.plan.done")
        // "Not yet" answers a finished or failed result; with none to judge, it would mean nothing.
        if action.judgesAResult {
            Button(PlanText.notYet) {
                Task { _ = await model.send(.forSession(task.id, .markPlanReviewed)) }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("return.plan.not-yet")
        }
    }

    private var nextStepCard: some View {
        Button {
            if let process = review.nextProcess {
                selectedProcess = process
            } else { showsContext = true }
        } label: {
            returnCard {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        cardHeading(L10n.yourNextStep)
                        Text(nextStepTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(review.nextProcess?.title ?? review.session?.goal.completionCriteria ?? L10n.returnReady)
                            .font(.caption)
                            .foregroundStyle(secondaryInk)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(secondaryInk)
                }
                .multilineTextAlignment(.leading)
                .contentShape(.rect)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("return.next.step")
        .accessibilityHint(L10n.returnViewRecord)
    }

    private var nextStepTitle: String {
        guard let process = review.nextProcess else {
            return review.allCompleted ? L10n.returnCheckCompletion : L10n.returnResumeContext
        }
        if process.status == .failed && !process.isInterrupted { return L10n.returnReviewFailure }
        if process.isInterrupted || [.blocked, .needsDecision, .disconnected].contains(process.status) { return L10n.returnReviewAttention }
        return process.status == .running ? L10n.returnFollowRunning : L10n.returnReviewQueued
    }

    private func processSheet(_ selection: AnchorProcess) -> some View {
        NavigationStack {
            // Sheet presentation carries its selection atomically. Keep the
            // selected task stable while still showing live status updates.
            let process = review.processes.first { $0.id == selection.id } ?? selection
            ProcessDetailView(process: process)
                .accessibilityIdentifier("return.process.detail")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.done) { selectedProcess = nil }
                            .accessibilityIdentifier("return.process.done")
                    }
                }
        }
    }

    private var contextSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(review.session?.goal.title ?? L10n.currentGoal).font(.title2.bold())
                    if let context = review.context { Text(context).font(.body) }
                    Text(L10n.completionCriteria).font(.headline)
                    Text(review.session?.goal.completionCriteria ?? "").font(.body)
                    if let steps = review.session?.goal.userPlan?.steps {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            Text("\(index + 1). \(step)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .accessibilityIdentifier("return.context.detail")
            .navigationTitle(L10n.returnAnchorRecord)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { showsContext = false }
                        .accessibilityIdentifier("return.context.done")
                }
            }
        }
    }

    private func cardHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryInk)
    }

    private func metric(_ value: Int, label: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: symbol).font(.caption).foregroundStyle(color).accessibilityHidden(true)
            Text("\(value)")
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(secondaryInk)
        }
        .accessibilityElement(children: .combine)
    }

    private func returnCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.white.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .strokeBorder(.white.opacity(0.66), lineWidth: 1)
                    }
                    .shadow(color: Color(red: 0.31, green: 0.49, blue: 0.53).opacity(0.10), radius: 13, y: 7)
            }
            .accessibilityElement(children: .contain)
    }

    private var backButton: some View {
        Button {
            guard !isContinuing else { return }
            isContinuing = true
            Task {
                if await model.continueWorking() == false { isContinuing = false }
            }
        } label: {
            HStack(spacing: 8) {
                if isContinuing {
                    ProgressView().tint(AnchorIOSStyle.onAccent)
                }
                Text(L10n.continueWorking)
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(AnchorIOSPrimaryButtonStyle())
        .disabled(isContinuing)
        .accessibilityIdentifier("return.back.button")
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.975, green: 0.982, blue: 0.984).opacity(0.93))
    }

    private var changes: [ReturnChange] { review.changes }
}
#endif
