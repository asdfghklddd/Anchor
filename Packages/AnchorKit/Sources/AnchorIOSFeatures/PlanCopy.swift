#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The words of a live plan: each task's next action, the step question on
/// return, and the prompt a step becomes when copied for an agent.
enum PlanCopy {
    static let stepDone = AnchorStrings.value("plan.step.done", default: "This step is done")
    static let notYet = AnchorStrings.value("plan.step.not-yet", default: "Not yet")
    static let then = AnchorStrings.value("plan.step.then", default: "Then")
    static let nextTag = AnchorStrings.value("plan.step.next", default: "Next")
    static let doneState = AnchorStrings.value("plan.step.state.done", default: "Done")
    static let openState = AnchorStrings.value("plan.step.state.open", default: "Not done")
    static let toggleHint = AnchorStrings.value(
        "plan.step.toggle.hint", default: "Double-tap to mark it done or not done.")
    static let copyPrompt = AnchorStrings.value("plan.prompt.copy", default: "Copy as prompt")
    static let copied = AnchorStrings.value("plan.prompt.copied", default: "Copied")
    static let toReview = AnchorStrings.value("plan.state.review", default: "To review")
    static let inProgress = AnchorStrings.value("plan.state.in-progress", default: "In progress")
    static let allStepsDone = AnchorStrings.value(
        "plan.next.finish", default: "All steps done. Finish the task when you agree.")

    static func step(_ number: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("plan.step.number", default: "Step %lld"), number)
    }

    static func stepsDone(_ done: Int, of total: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("plan.progress.a11y", default: "%lld of %lld steps done"), done, total)
    }

    static func line(for action: TaskNextAction, compact: Bool = false) -> String {
        if compact, case let .start(step, text) = action {
            return String.localizedStringWithFormat(
                AnchorStrings.value("plan.next.start.short", default: "Step %lld: %@"), step + 1, text)
        }
        return switch action {
        case let .fix(process):
            String.localizedStringWithFormat(AnchorStrings.value("plan.next.fix", default: "Fix: %@ failed"), process)
        case let .review(process):
            String.localizedStringWithFormat(
                AnchorStrings.value("plan.next.review", default: "Check: %@ finished"), process)
        case let .wait(process, _):
            String.localizedStringWithFormat(
                AnchorStrings.value("plan.next.wait", default: "Wait: %@ is running"), process)
        case let .start(step, text):
            String.localizedStringWithFormat(
                AnchorStrings.value("plan.next.start", default: "Start step %lld: %@"), step + 1, text)
        case .finish:
            allStepsDone
        }
    }

    /// Seconds under a minute, whole minutes under an hour, then hours and minutes.
    static func running(since start: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(start))
        let units: Set<Duration.UnitsFormatStyle.Unit> = seconds < 60
            ? [.seconds] : seconds < 3_600 ? [.minutes] : [.hours, .minutes]
        let duration = Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: units, width: .abbreviated).locale(AnchorStrings.interfaceLocale))
        return String.localizedStringWithFormat(
            AnchorStrings.value("plan.next.wait.elapsed", default: "Running for %@"), duration)
    }

    static func symbol(for action: TaskNextAction) -> (name: String, color: Color) {
        switch action {
        case .fix: ("xmark.octagon.fill", AnchorStateTone.failed.ink)
        case .review: ("eye.fill", AnchorStateTone.attention.ink)
        case .wait: ("hourglass", AnchorIOSStyle.secondaryText)
        case .start: ("arrow.right.circle.fill", AnchorIOSStyle.action)
        case .finish: ("checkmark.seal.fill", AnchorStateTone.done.ink)
        }
    }

    /// One step as a ready-to-paste request, carrying the goal it serves.
    static func prompt(goal: AnchorGoal, step index: Int) -> String? {
        guard let steps = goal.userPlan?.steps, steps.indices.contains(index) else { return nil }
        var lines = [String.localizedStringWithFormat(
            AnchorStrings.value("plan.prompt.goal", default: "Goal: %@"), goal.title)]
        let criteria = goal.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        if !criteria.isEmpty {
            lines.append(String.localizedStringWithFormat(
                AnchorStrings.value("plan.prompt.criteria", default: "Done when: %@"), criteria))
        }
        lines.append(String.localizedStringWithFormat(
            AnchorStrings.value("plan.prompt.step", default: "Now do step %lld: %@"), index + 1, steps[index]))
        return lines.joined(separator: "\n")
    }
}
#endif
