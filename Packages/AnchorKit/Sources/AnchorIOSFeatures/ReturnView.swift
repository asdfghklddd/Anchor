#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The return is a review step between being away and resuming the workspace.
/// It presents the current task and real changes in the four-card layout.
struct ReturnView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false
    @State private var feedbackCount = 0
    @State private var cardsPresented = false
    @State private var animateEntrance = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProcess: AnchorProcess?
    @State private var showsContext = false
    @State private var isContinuing = false
    @State private var showAllChanges = false

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
                    enteringCard(changesCard, index: 1)
                    enteringCard(workCard, index: 2)
                    enteringCard(nextStepCard, index: 3)
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
        .preferredColorScheme(.light)
        .sensoryFeedback(.success, trigger: feedbackCount)
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
        let reducesMotion = reduceMotion || systemReduceMotion
        return content
            .scaleEffect(cardsPresented || reducesMotion ? 1 : 0.92)
            .offset(y: cardsPresented || reducesMotion ? 0 : 22)
            .opacity(cardsPresented ? 1 : 0)
            .animation(
                animateEntrance
                    ? (reducesMotion
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
        let color: Color = interrupted ? .orange : (change.kind == .failed ? .red : (change.kind == .completed ? .green : AnchorIOSStyle.action))
        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(color)
                .frame(minWidth: 16, alignment: .leading)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(interrupted ? L10n.returnInterrupted : change.title)
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
                    metric(review.runningCount, label: L10n.returnRunning, symbol: "play.fill", color: .green)
                        .accessibilityIdentifier("return.work.running")
                    metric(review.completedCount, label: L10n.returnCompleted, symbol: "checkmark.seal.fill", color: AnchorIOSStyle.action)
                        .accessibilityIdentifier("return.work.completed")
                    metric(review.failedCount, label: L10n.returnFailed, symbol: "xmark.octagon.fill", color: .red)
                        .accessibilityIdentifier("return.work.failed")
                    metric(review.attentionCount, label: L10n.returnAttention, symbol: "exclamationmark.circle.fill", color: .orange)
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
            HStack(spacing: 5) {
                Text(L10n.returnBack)
                Image(systemName: "play.fill")
                    .font(.system(size: 7))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(secondaryInk)
            .frame(minWidth: 88, minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isContinuing)
        .accessibilityHint(L10n.continueWorking)
        .accessibilityIdentifier("return.back.button")
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .background(Color(red: 0.975, green: 0.982, blue: 0.984).opacity(0.93))
    }

    private var changes: [ReturnChange] { review.changes }
}
#endif
