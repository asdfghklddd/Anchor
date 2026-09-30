#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The return is a review step between being away and resuming the workspace.
/// It presents the current task and real changes in the four-card layout.
struct ReturnView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDecision: Decision?
    @State private var showAllChanges = false

    private let ink = Color(red: 0.11, green: 0.15, blue: 0.17)
    private let secondaryInk = Color(red: 0.43, green: 0.48, blue: 0.50)

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                        .padding(.bottom, 27)

                    taskCard
                    changesCard
                    workCard
                    nextStepCard
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 16)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { backButton }
        .sheet(item: $selectedDecision) { decision in
            DecisionView(model: model, decision: decision)
        }
        .sheet(isPresented: $showAllChanges) { changesSheet }
        .preferredColorScheme(.light)
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
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(ink)
                .accessibilityIdentifier("return.screen")
                .accessibilityAddTraits(.isHeader)
            Text(L10n.returnSubtitle)
                .font(.caption)
                .foregroundStyle(secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 1)
    }

    private var taskCard: some View {
        returnCard {
            VStack(spacing: 8) {
                Text(projection.session?.goal.title ?? L10n.currentGoal)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .accessibilityIdentifier("return.goal.title")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 1)
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
                Text(L10n.returnNoChanges)
                    .font(.subheadline)
                    .foregroundStyle(secondaryInk)
            } else {
                ForEach(Array(changes.prefix(2))) { change in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(ink)
                            .lineLimit(1)
                        if !change.detail.isEmpty {
                            Text(change.detail)
                                .font(.caption)
                                .foregroundStyle(secondaryInk)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                if changes.count > 2 {
                    Button(L10n.returnChangesSummary(changes.count)) {
                        showAllChanges = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ink)
                    .padding(.top, 2)
                    .accessibilityIdentifier("return.changes.all.button")
                }
            }
        }
        .accessibilityIdentifier("return.changes.card")
    }

    private var changesSheet: some View {
        NavigationStack {
            List(changes) { change in
                VStack(alignment: .leading, spacing: 4) {
                    Text(change.title)
                        .font(.subheadline.weight(.semibold))
                    if !change.detail.isEmpty {
                        Text(change.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(change.occurredAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("return.changes.list")
            .navigationTitle(L10n.returnChanges)
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
            HStack(spacing: 24) {
                metric(runningCount, label: L10n.returnStillRunning)
                    .accessibilityIdentifier("return.work.running")
                metric(waitingCount, label: L10n.returnWaitingJudgment)
                    .accessibilityIdentifier("return.work.waiting")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 5)
        }
        .accessibilityIdentifier("return.work.card")
    }

    @ViewBuilder
    private var nextStepCard: some View {
        if let decision = nextDecision {
            Button {
                selectedDecision = decision
            } label: {
                nextStepContent(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("return.next.step")
        } else {
            nextStepContent(showsChevron: false)
                .accessibilityIdentifier("return.next.step")
        }
    }

    private func nextStepContent(showsChevron: Bool) -> some View {
        returnCard {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    cardHeading(L10n.yourNextStep)
                    Text(nextProcess?.title ?? L10n.returnReady)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ink)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    if let detail = nextProcess?.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(secondaryInk)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    }
                }
                Spacer(minLength: 4)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryInk)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func cardHeading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(secondaryInk)
    }

    private func metric(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
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
            .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 150 : 96, alignment: .topLeading)
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
            Task { await model.continueWorking() }
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
        .accessibilityHint(L10n.continueWorking)
        .accessibilityIdentifier("return.back.button")
        .frame(maxWidth: .infinity)
        .padding(.bottom, 2)
        .background(Color(red: 0.975, green: 0.982, blue: 0.984).opacity(0.93))
    }

    private var changes: [ReturnChange] {
        projection.session?.returnSummary?.changes ?? []
    }

    private var runningCount: Int {
        projection.session?.taskProcesses.filter { $0.status == .running }.count ?? 0
    }

    private var waitingCount: Int {
        projection.session?.decisions.filter { $0.status == .open }.count ?? 0
    }

    private var nextDecision: Decision? {
        guard let session = projection.session else { return nil }
        if let recommendedID = session.returnSummary?.recommendedProcessID,
           let decision = session.decisions.first(where: {
               $0.status == .open && $0.processID == recommendedID
           }) {
            return decision
        }
        return session.decisions.first { $0.status == .open }
    }

    private var nextProcess: AnchorProcess? {
        guard let session = projection.session else { return nil }
        if let decision = nextDecision {
            return session.processes.first { $0.id == decision.processID }
        }
        return session.taskProcesses.first { $0.status == .running }
    }
}
#endif
