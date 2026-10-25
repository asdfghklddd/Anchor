#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct ProfileDetailSheet: View {
    let projection: SessionProjection
    let kind: ProfileDetailKind
    let onManage: () -> Void
    let onFinish: () -> Void
    /// Checks a step of the current task's plan on or off.
    var onToggleStep: ((UUID, Bool) -> Void)? = nil
    /// Saves the current task's edited step list.
    var onEditSteps: (([AnchorUserPlan.Step]) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HarborBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                        detailHero

                        if kind == .session {
                            sessionMetrics
                            if !processes.isEmpty { processPulse }
                            if let goal = projection.session?.goal, goal.userPlan != nil {
                                AnchorSavedPlan(goal: goal, onToggleStep: onToggleStep, onEditSteps: onEditSteps)
                                    .padding(16)
                                    .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 18))
                            }
                        }

                        recentSection

                        if kind == .session {
                            HStack(spacing: AnchorSpacing.small) {
                                Button(L10n.taskManagement, action: onManage)
                                    .buttonStyle(.borderedProminent)
                                    .tint(AnchorPalette.link)
                                Button(L10n.finish, action: onFinish)
                                    .buttonStyle(.bordered)
                                    .tint(AnchorPalette.link)
                                    .accessibilityIdentifier("profile.session.finish.button")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Label(L10n.done, systemImage: "checkmark")
                            }
                            .buttonStyle(HarborPrimaryButtonStyle())
                        }
                    }
                    .padding(AnchorSpacing.medium)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("profile.detail.\(String(describing: kind))")
    }

    @ViewBuilder private var detailHero: some View {
        if kind == .session, let task = projection.session {
            AnchorCard(tint: kind.tint) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(task.goal.title)
                        .font(.title2.bold())
                        .foregroundStyle(AnchorPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !task.goal.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(AnchorStrings.value("task.detail.criteria", default: "Completion criteria"))
                            .font(.subheadline.bold())
                            .foregroundStyle(AnchorPalette.link)
                        Text(task.goal.completionCriteria)
                            .font(.body)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else {
            AnchorCard(tint: kind.tint) {
                HStack(spacing: AnchorSpacing.small) {
                    Image(systemName: kind.symbol)
                        .font(.title3.bold())
                        .foregroundStyle(kind.tint)
                        .frame(width: 42, height: 42)
                        .background(kind.tint.opacity(0.14), in: .circle)
                    Text(kind.value(projection: projection))
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(AnchorPalette.ink)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var sessionMetrics: some View {
        HStack(spacing: 0) {
            profileMetric(taskProgress, label: L10n.taskProgress)
            Divider().padding(.vertical, 8)
            profileMetric(sessionStatus, label: L10n.currentStatus)
            Divider().padding(.vertical, 8)
            profileMetric("\(completedCount)/\(processCount)", label: L10n.completedWork)
        }
        .padding(.vertical, AnchorSpacing.small)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func profileMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var processPulse: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(AnchorStrings.value("task.detail.processes", default: "Process progress"))
                .font(.title3.bold())
                .foregroundStyle(AnchorPalette.ink)
            VStack(spacing: 0) {
                ForEach(processes) { process in
                    HStack(spacing: AnchorSpacing.small) {
                        SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(process.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(AnchorPalette.ink)
                            Text(L10n.status(process.status))
                                .contentTransition(.opacity)
                                .font(.caption2)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                            if !process.detail.isEmpty {
                                Text(process.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 4) {
                            if let progress = process.progress {
                                Text(progress, format: .percent.precision(.fractionLength(0)))
                                    .font(.caption.bold().monospacedDigit())
                                    .foregroundStyle(AnchorPalette.ink)
                                AnchorProgress(value: progress, tint: AnchorPalette.source(process.sourceTone))
                                    .frame(width: 64)
                            } else {
                                Text(L10n.compactStatus(process.status))
                                    .contentTransition(.opacity)
                                    .font(.caption.bold())
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                        }
                    }
                    .padding(.vertical, 10)
                    // A status that changes while you read crossfades instead of jumping.
                    .animation(AnchorMotion.micro, value: process.status)
                    if process.id != processes.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal, AnchorSpacing.small)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(AnchorStrings.value("profile.detail.recent.records", default: "Recent records"))
                .font(.title3.bold())
                .foregroundStyle(AnchorPalette.ink)
            VStack(spacing: 0) {
                if timeline.isEmpty {
                    Text(L10n.noEvents)
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AnchorSpacing.medium)
                } else {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: AnchorSpacing.small) {
                            Text(event.occurredAt, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .frame(width: 44, alignment: .leading)
                            Circle()
                                .fill(index == 0 ? kind.tint : AnchorPalette.secondaryInk.opacity(0.35))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AnchorPalette.ink)
                                if !event.detail.isEmpty {
                                    Text(event.detail)
                                        .font(.caption)
                                        .foregroundStyle(AnchorPalette.secondaryInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                        if index < timeline.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .padding(.horizontal, AnchorSpacing.small)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private func sectionHeading(kicker: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker)
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.link)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AnchorPalette.ink)
        }
    }

    private var processes: [AnchorProcess] {
        projection.session?.taskProcesses ?? []
    }

    private var timeline: [ProcessEvent] {
        Array((projection.session?.records ?? []).sorted { $0.occurredAt > $1.occurredAt }.prefix(6))
    }

    /// The person's own checked steps when they wrote some; a source's percentage otherwise.
    private var taskProgress: String {
        if let plan = projection.session?.goal.userPlan, !plan.steps.isEmpty {
            return "\(plan.doneCount)/\(plan.steps.count)"
        }
        return projection.session?.conversationsInJoiningOrder.first?.progress?
            .formatted(.percent.precision(.fractionLength(0))) ?? "—"
    }

    private var sessionStatus: String {
        // Finished runs are not a finished task; a plan's state follows the person's next move.
        if let session = projection.session, let action = TaskNextAction(task: session) {
            switch action {
            case .answer: return PlanText.waitingForReply
            case .fix: return L10n.status(.failed)
            case .review: return PlanText.toReview
            case .wait: return L10n.status(.running)
            case .start: return PlanText.inProgress
            case .finish: return L10n.status(.completed)
            }
        }
        if !projection.openDecisions.isEmpty { return L10n.status(.needsDecision) }
        for status in [ProcessStatus.failed, .blocked, .disconnected, .running] {
            if processes.contains(where: { $0.status == status }) { return L10n.status(status) }
        }
        if !processes.isEmpty && processes.allSatisfy({ $0.status == .completed }) {
            return L10n.status(.completed)
        }
        return L10n.status(.queued)
    }

    private var processCount: Int { processes.count }
    private var completedCount: Int { processes.filter { $0.status == .completed }.count }

}

private extension ProfileDetailKind {
    var title: String {
        switch self {
        case .focus: L10n.history
        case .contexts: L10n.savedContexts
        case .anchors: L10n.completedAnchors
        case .session: AnchorStrings.value("task.detail.title", default: "Task details")
        case .returnMemory: L10n.returning
        case .contextSnapshot: L10n.contextNote
        }
    }

    var symbol: String {
        switch self {
        case .focus: "timer"
        case .contexts: "square.stack.3d.up"
        case .anchors: "scope"
        case .session: "waveform.path.ecg"
        case .returnMemory: "arrow.uturn.left.circle"
        case .contextSnapshot: "square.stack.3d.up"
        }
    }

    var tint: Color {
        switch self {
        case .focus: AnchorPalette.coral
        case .contexts, .contextSnapshot: AnchorPalette.periwinkle
        case .anchors, .session, .returnMemory: AnchorPalette.seafoam
        }
    }

    func value(projection: SessionProjection) -> String {
        switch self {
        case .focus: L10n.minuteCount(max(0, Int(Date.now.timeIntervalSince(projection.session?.startedAt ?? .now) / 60)))
        case .contexts: "\((projection.session?.notes.count ?? 0) + (projection.session?.snapshots.count ?? 0))"
        case .anchors: "\(projection.session?.taskProcesses.filter { $0.status == .completed }.count ?? 0)"
        case .session, .returnMemory: TaskStatusPresentation.text(for: projection.session)
        case .contextSnapshot: "\(projection.session?.snapshots.count ?? 0)"
        }
    }

}
#endif
