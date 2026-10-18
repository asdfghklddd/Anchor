import Foundation

/// Everything that changed across the person's tasks while they were away, in
/// the order to look at it: what needs them first, then the rest. Tasks that
/// neither changed nor wait on the person are only counted.
public struct ReturnOverview: Sendable {
    public struct Item: Identifiable, Sendable {
        public let task: AnchorSession
        public let action: TaskNextAction?
        /// Work on this task that reported something after the person left, newest first.
        public let changes: [AnchorProcess]

        public var id: UUID { task.id }
    }

    public let items: [Item]
    public let unchangedCount: Int

    public init(tasks: [AnchorSession], awaySince: Date?) {
        var items: [Item] = []
        var unchanged = 0
        for task in tasks where task.status == .active || task.status == .draft {
            let changes = awaySince.map { since in
                task.taskProcesses.filter { $0.updatedAt > since }.sorted { $0.updatedAt > $1.updatedAt }
            } ?? []
            let action = TaskNextAction(task: task)
            guard !changes.isEmpty || action?.asksForALook == true else {
                unchanged += 1
                continue
            }
            items.append(Item(task: task, action: action, changes: changes))
        }
        self.items = items.sorted { lhs, rhs in
            let left = Self.urgency(lhs), right = Self.urgency(rhs)
            if left != right { return left < right }
            return Self.latest(lhs) > Self.latest(rhs)
        }
        unchangedCount = unchanged
    }

    /// The one thing to do first.
    public var first: Item? { items.first }

    /// The plan's reading order; a task without written steps still puts a
    /// question first, then a failure, then a finished result.
    private static func urgency(_ item: Item) -> Int {
        if let action = item.action { return action.urgency }
        if item.changes.contains(where: { $0.status == .needsDecision }) { return TaskNextAction.answer(process: "").urgency }
        if item.changes.contains(where: { $0.status == .failed && !$0.isInterrupted }) { return TaskNextAction.fix(process: "").urgency }
        if item.changes.contains(where: { $0.status == .completed }) { return TaskNextAction.review(process: "").urgency }
        return TaskNextAction.unplannedUrgency
    }

    private static func latest(_ item: Item) -> Date {
        item.changes.first?.updatedAt ?? item.task.startedAt
    }
}
