import Foundation

/// The day so far (I10): the steps the person finished today, the tasks they
/// moved forward or finished, and what is still waiting on them or running.
public struct TodayRecap: Sendable {
    public struct FinishedStep: Identifiable, Sendable {
        public let id: UUID
        public let text: String
        public let taskTitle: String
        public let taskID: UUID
        public let at: Date
    }

    /// Newest first.
    public let finishedSteps: [FinishedStep]
    public let finishedTasks: [AnchorSession]
    /// Tasks with a step done, work reported or the task finished today.
    public let movedTaskCount: Int
    /// Open tasks whose next action is the person's: a question, a failure or a result.
    public let needsYou: [(task: AnchorSession, action: TaskNextAction)]
    /// Open tasks with work still running.
    public let running: [AnchorSession]

    /// `open` are the hosted tasks; `archived` may include tasks finished today.
    public init(open: [AnchorSession], archived: [AnchorSession], now: Date, calendar: Calendar = .current) {
        let isToday = { (date: Date) in calendar.isDate(date, inSameDayAs: now) }
        let finishedToday = archived.filter { $0.status == .completed && $0.completedAt.map(isToday) == true }
        var steps: [FinishedStep] = []
        var moved = 0
        for task in open + finishedToday {
            let done = (task.goal.userPlan?.items ?? []).compactMap { step -> FinishedStep? in
                guard let at = step.completedAt, isToday(at) else { return nil }
                return FinishedStep(id: step.id, text: step.text, taskTitle: task.goal.title, taskID: task.id, at: at)
            }
            steps += done
            let worked = task.taskProcesses.contains { isToday($0.updatedAt) }
            if !done.isEmpty || worked || task.completedAt.map(isToday) == true { moved += 1 }
        }
        finishedSteps = steps.sorted { $0.at > $1.at }
        finishedTasks = finishedToday
        movedTaskCount = moved
        needsYou = open.compactMap { task in
            TaskNextAction(task: task).flatMap { $0.asksForALook ? (task, $0) : nil }
        }
        running = open.filter { $0.taskProcesses.contains { $0.status == .running } }
    }

    /// Nothing happened yet today.
    public var isEmpty: Bool { finishedSteps.isEmpty && finishedTasks.isEmpty && movedTaskCount == 0 }
}
