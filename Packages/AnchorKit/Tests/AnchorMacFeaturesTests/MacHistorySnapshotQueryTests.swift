#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@Test("History snapshots sort newest first")
func historySortsNewestFirst() {
    let older = snapshot(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
        title: "Older task",
        date: Date(timeIntervalSince1970: 100)
    )
    let newer = snapshot(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
        title: "Newer task",
        date: Date(timeIntervalSince1970: 200)
    )

    #expect(MacHistorySnapshotQuery.sorted([older, newer]).map(\.id) == [newer.id, older.id])
}

@Test(
    "History search matches titles and notes",
    arguments: [
        ("launch", ["Launch film"]),
        ("camera", ["Design review"]),
        ("  ", ["Design review", "Launch film"]),
        ("missing", []),
    ]
)
func historySearch(query: String, expectedTitles: [String]) {
    let snapshots = [
        snapshot(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            title: "Launch film",
            date: Date(timeIntervalSince1970: 100),
            note: "Export the final cut"
        ),
        snapshot(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            title: "Design review",
            date: Date(timeIntervalSince1970: 200),
            note: "Confirm the camera direction"
        ),
    ]

    let results = MacHistorySnapshotQuery.filtered(snapshots, query: query)

    #expect(results.map(\.goalTitle) == expectedTitles)
}

private func snapshot(
    id: UUID,
    title: String,
    date: Date,
    note: String? = nil
) -> ContextSnapshot {
    ContextSnapshot(
        id: id,
        createdAt: date,
        goalTitle: title,
        processes: [],
        openDecisionIDs: [],
        latestNote: note
    )
}
#endif
