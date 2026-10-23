#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// A hosted task in the library. The identity color matches its lane in the
/// glance card; the status line names every state its conversations report.
struct HostedTaskCard: View {
    let task: AnchorSession
    let height: CGFloat
    /// The task the person is on, marked when there is more than one.
    var isCurrent = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 20
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var ringSize: CGFloat = 13

    /// Tall cards have room to say what last happened.
    private var showsLatest: Bool { dynamicTypeSize.isAccessibilitySize || height >= 160 }

    var body: some View {
        let tint = HostedTaskAppearance.tint(task)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text(task.goal.title).font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if !summary.isComplete, !showsLatest, let planProgress {
                    // A short card gives the step line the full width below.
                    stepsCapsule(planProgress, tint: tint)
                } else if summary.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AnchorStateTone.done.ink)
                        .frame(width: 26, height: 26)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.36, bounce: 0.3),
                       value: summary.isComplete)
            .animation(AnchorMotion.micro, value: isCurrent)
            // The person's own next move leads; the last event is the fallback for a task without steps.
            if showsLatest {
                if let nextAction {
                    nextActionBlock(nextAction)
                } else if let latest = latestEvent {
                    latestLine(latest)
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 6) {
                // With a plan, the next action already names the state that matters.
                if !showsLatest, let nextAction {
                    nextActionLine(nextAction)
                } else if nextAction == nil {
                    statusLine(tint: tint)
                }
                Spacer(minLength: 4)
                if isCurrent {
                    currentTag(tint: tint)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9)))
                }
                if let planProgress {
                    if showsLatest, !summary.isComplete { stepsCapsule(planProgress, tint: tint) }
                } else if let progress = displayedProgress {
                    capsule(progress, text: progress.formatted(.percent.precision(.fractionLength(0))), tint: tint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(minHeight: height, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : height, alignment: .topLeading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.cardRadius))
        .overlay(alignment: .topLeading) {
            // Identity tab: ties the card to its lane without a thick border.
            Capsule().fill(tint).frame(width: 22, height: 4).padding(.leading, 14).padding(.top, 7)
                .accessibilityHidden(true)
        }
        .shadow(color: AnchorIOSStyle.heading.opacity(0.10), radius: 9, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.goal.title)
        .accessibilityValue(accessibleStatus)
    }

    // MARK: State

    private var summary: HostedTaskStatus { HostedTaskStatus(task: task) }

    private var latestEvent: (event: ProcessEvent, process: AnchorProcess)? {
        task.taskProcesses
            .flatMap { process in
                process.events.filter { [.created, .outputReady, .decisionRequired, .completed, .failed].contains($0.kind) }
                    .map { ($0, process) }
            }
            .max { $0.0.occurredAt < $1.0.occurredAt }
    }

    private var nextAction: TaskNextAction? { TaskNextAction(task: task) }

    /// Steps the person checked off: a progress basis they own, unlike a source's percentage.
    private var planProgress: (done: Int, total: Int)? {
        guard let plan = task.goal.userPlan, !plan.steps.isEmpty else { return nil }
        return (plan.doneCount, plan.steps.count)
    }

    private var displayedProgress: Double? {
        guard let value = task.conversationsInJoiningOrder.first?.progress, value.isFinite else { return nil }
        return min(1, max(0, value))
    }

    private var accessibleStatus: String {
        var parts = isCurrent ? [PlanText.current, statusText] : [statusText]
        if let nextAction { parts.append(PlanText.line(for: nextAction)) }
        if let planProgress {
            parts.append(PlanText.stepsDone(planProgress.done, of: planProgress.total))
        } else if let progress = displayedProgress {
            parts.append("\(L10n.taskProgress) \(progress.formatted(.percent.precision(.fractionLength(0))))")
        } else if summary.hasSources {
            parts.append(L10n.cardProgressUnreported)
        }
        return parts.joined(separator: ", ")
    }

    private var statusText: String { summary.summary }

    private var statusSymbol: (name: String, color: Color) { summary.symbol }

    // MARK: Pieces

    private func currentTag(tint: Color) -> some View {
        Text(PlanText.current)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14), in: .capsule)
            .accessibilityHidden(true)
    }

    private func statusLine(tint: Color) -> some View {
        let symbol = statusSymbol
        return HStack(spacing: 5) {
            Image(systemName: symbol.name)
                .foregroundStyle(symbol.color)
                .contentTransition(.symbolEffect(.replace))
            Text(statusText)
                .foregroundStyle(AnchorIOSStyle.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .animation(AnchorMotion.micro, value: statusText)
    }

    private func latestLine(_ latest: (event: ProcessEvent, process: AnchorProcess)) -> some View {
        let interrupted = latest.event.isInterruption
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(latest.process.title) \(L10n.eventVerb(latest.event.kind, interrupted: interrupted))")
                .font(.footnote)
                .foregroundStyle(AnchorIOSStyle.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
            Text("\(latest.process.sourceName) · \(latest.event.occurredAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                .font(.caption2)
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
        }
        .padding(.top, 2)
    }

    private func nextActionBlock(_ action: TaskNextAction) -> some View {
        let symbol = PlanCopy.symbol(for: action)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol.name)
                .foregroundStyle(symbol.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanText.line(for: action))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)
                if case let .wait(_, since) = action {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(PlanText.running(since: since, now: context.date))
                            .font(.caption2)
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                    }
                }
            }
        }
        .font(.footnote.weight(.medium))
        .padding(.top, 2)
        .animation(AnchorMotion.micro, value: action)
    }

    private func nextActionLine(_ action: TaskNextAction) -> some View {
        let symbol = PlanCopy.symbol(for: action)
        return HStack(spacing: 5) {
            Image(systemName: symbol.name)
                .foregroundStyle(symbol.color)
                .contentTransition(.symbolEffect(.replace))
            Text(PlanText.line(for: action, compact: true))
                .foregroundStyle(AnchorIOSStyle.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
        .font(.caption.weight(.semibold))
        .animation(AnchorMotion.micro, value: action)
    }

    private func stepsCapsule(_ steps: (done: Int, total: Int), tint: Color) -> some View {
        capsule(Double(steps.done) / Double(steps.total), text: "\(steps.done)/\(steps.total)", tint: tint)
    }

    private func capsule(_ progress: Double, text: String, tint: Color) -> some View {
        let animation = reduceMotion ? Animation.easeOut(duration: 0.16) : AnchorMotion.continuity
        return HStack(spacing: 5) {
            ZStack {
                Circle().stroke(tint.opacity(0.25), lineWidth: 2)
                Circle().trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(animation, value: progress)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityHidden(true)
            Text(text)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: progress))
                .animation(animation, value: text)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(AnchorIOSStyle.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.18), in: .capsule)
    }
}
#endif
