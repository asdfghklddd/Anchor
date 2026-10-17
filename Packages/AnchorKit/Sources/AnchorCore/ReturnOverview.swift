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
            let left = lhs.action?.urgency ?? 5, right = rhs.action?.urgency ?? 5
            if left != right { return left < right }
            return Self.latest(lhs) > Self.latest(rhs)
        }
        unchangedCount = unchanged
    }

    /// The one thing to do first.
    public var first: Item? { items.first }

    private static func latest(_ item: Item) -> Date {
        item.changes.first?.updatedAt ?? item.task.startedAt
    }
}
