#if os(macOS)
import AnchorCore

enum MacHistorySnapshotQuery {
    static func sorted(_ snapshots: [ContextSnapshot]) -> [ContextSnapshot] {
        snapshots.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt > rhs.createdAt
        }
    }

    static func filtered(
        _ snapshots: [ContextSnapshot],
        query: String
    ) -> [ContextSnapshot] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ordered = sorted(snapshots)
        guard !normalizedQuery.isEmpty else { return ordered }

        return ordered.filter { snapshot in
            snapshot.goalTitle.localizedCaseInsensitiveContains(normalizedQuery)
                || snapshot.latestNote?.localizedCaseInsensitiveContains(normalizedQuery) == true
        }
    }
}
#endif
