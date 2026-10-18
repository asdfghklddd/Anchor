import AnchorCore
import Foundation

/// The words of the day's recap, shared by iPhone and Mac.
public enum TodayText {
    public static let title = AnchorStrings.value("today.title", default: "Today")
    public static let waiting = AnchorStrings.value("today.waiting", default: "Waiting for you")
    public static let running = AnchorStrings.value("today.running", default: "Still running")

    /// "完成 3 步 · 推进 2 个任务 · 完成 1 个任务"
    public static func summary(_ recap: TodayRecap) -> String {
        var parts: [String] = []
        if !recap.finishedSteps.isEmpty {
            parts.append(String.localizedStringWithFormat(
                AnchorStrings.value("today.summary.steps", default: "Steps done: %lld"), recap.finishedSteps.count))
        }
        if recap.movedTaskCount > 0 {
            parts.append(String.localizedStringWithFormat(
                AnchorStrings.value("today.summary.moved", default: "Tasks moved: %lld"), recap.movedTaskCount))
        }
        if !recap.finishedTasks.isEmpty {
            parts.append(String.localizedStringWithFormat(
                AnchorStrings.value("today.summary.finished", default: "Tasks finished: %lld"), recap.finishedTasks.count))
        }
        return parts.joined(separator: " · ")
    }

    public static func moreSteps(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("today.more", default: "More steps: %lld"), count)
    }
}
