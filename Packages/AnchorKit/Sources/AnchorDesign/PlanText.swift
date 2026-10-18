import AnchorCore
import Foundation

/// The words of a live plan, shared by iPhone and Mac: each task's next action,
/// the step questions, and the prompt a step becomes when copied for an agent.
public enum PlanText {
    public static let stepDone = AnchorStrings.value("plan.step.done", default: "This step is done")
    public static let notYet = AnchorStrings.value("plan.step.not-yet", default: "Not yet")
    public static let then = AnchorStrings.value("plan.step.then", default: "Then")
    public static let nextTag = AnchorStrings.value("plan.step.next", default: "Next")
    public static let doneState = AnchorStrings.value("plan.step.state.done", default: "Done")
    public static let openState = AnchorStrings.value("plan.step.state.open", default: "Not done")
    public static let toggleHint = AnchorStrings.value(
        "plan.step.toggle.hint", default: "Double-tap to mark it done or not done.")
    public static let copyPrompt = AnchorStrings.value("plan.prompt.copy", default: "Copy as prompt")
    public static let copied = AnchorStrings.value("plan.prompt.copied", default: "Copied")
    public static let toReview = AnchorStrings.value("plan.state.review", default: "To review")
    public static let edit = AnchorStrings.value("plan.edit", default: "Edit")
    public static let editTitle = AnchorStrings.value("plan.edit.title", default: "Edit steps")
    public static let editHint = AnchorStrings.value(
        "plan.edit.hint", default: "Drag to reorder. Checked steps stay checked.")
    public static let stepPlaceholder = AnchorStrings.value("plan.edit.step", default: "Step")
    public static let addStepPlaceholder = AnchorStrings.value("plan.edit.add", default: "Add a step")
    public static let doFirst = AnchorStrings.value("plan.return.first", default: "Do first")
    /// An agent asked something and waits for the person's reply.
    public static let waitingForReply = AnchorStrings.value("status.waiting-reply", default: "Waiting for you")

    public static func tests(_ outcome: TestOutcome) -> String {
        switch outcome {
        case .passed: AnchorStrings.value("tests.passed", default: "Tests passed")
        case .failed: AnchorStrings.value("tests.failed", default: "Tests failed")
        case .ran: AnchorStrings.value("tests.ran", default: "Ran tests")
        case .notRun: AnchorStrings.value("tests.not-run", default: "Not tested")
        }
    }
    /// The task the person is on, which the Mac also uses to place new work.
    public static let current = AnchorStrings.value("plan.current", default: "Current")
    public static let makeCurrentHint = AnchorStrings.value(
        "plan.current.hint", default: "Makes this the task you're on.")
    public static let glanceNeedsYou = AnchorStrings.value("plan.glance.needs-you", default: "need you")
    public static let inProgress = AnchorStrings.value("plan.state.in-progress", default: "In progress")
    public static let allStepsDone = AnchorStrings.value(
        "plan.next.finish", default: "All steps done. Finish the task when you agree.")

    public static func othersUnchanged(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("plan.return.unchanged", default: "Tasks with no changes: %lld"), count)
    }

    public static func step(_ number: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("plan.step.number", default: "Step %lld"), number)
    }

    public static func stepsDone(_ done: Int, of total: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("plan.progress.a11y", default: "%lld of %lld steps done"), done, total)
    }

    public static func line(for action: TaskNextAction, compact: Bool = false) -> String {
        if compact, case let .start(step, text) = action {
            return String.localizedStringWithFormat(
                AnchorStrings.value("plan.next.start.short", default: "Step %lld: %@"), step + 1, text)
        }
        return switch action {
        case let .answer(process):
            String.localizedStringWithFormat(
                AnchorStrings.value("plan.next.answer", default: "Reply: %@ is waiting for you"), process)
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
    public static func running(since start: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(start))
        let units: Set<Duration.UnitsFormatStyle.Unit> = seconds < 60
            ? [.seconds] : seconds < 3_600 ? [.minutes] : [.hours, .minutes]
        let duration = Duration.seconds(seconds.rounded())
            .formatted(.units(allowed: units, width: .abbreviated).locale(AnchorStrings.interfaceLocale))
        return String.localizedStringWithFormat(
            AnchorStrings.value("plan.next.wait.elapsed", default: "Running for %@"), duration)
    }

    /// One step as a ready-to-paste request, carrying the goal it serves.
    public static func prompt(goal: AnchorGoal, step index: Int) -> String? {
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
