import Foundation

public extension ProcessEvent {
    /// Whether the person reads this in a task's records. Presence and link
    /// changes are the app's own bookkeeping (titles such as "Presence: away"),
    /// kept for return summaries but never shown as a record (D11).
    var isPersonFacing: Bool {
        kind != .presence && kind != .connection
    }
}

public extension AnchorSession {
    /// The timeline as the person reads it, in its stored order, without bookkeeping.
    var records: [ProcessEvent] {
        timeline.filter(\.isPersonFacing)
    }
}
