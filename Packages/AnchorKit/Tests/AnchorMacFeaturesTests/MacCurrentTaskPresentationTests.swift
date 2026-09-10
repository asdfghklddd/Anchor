#if os(macOS)
import AnchorCore
import Testing
@testable import AnchorMacFeatures

@Test(
    "Only an unfinished formal task remains in the current workspace",
    arguments: [
        (SessionStatus?.none, false, false),
        (.some(.draft), false, true),
        (.some(.active), false, true),
        (.some(.completed), false, false),
        (.some(.completed), true, true),
        (.some(.archived), true, false),
    ]
)
func currentTaskForegroundVisibility(
    status: SessionStatus?,
    includingCompleted: Bool,
    expected: Bool
) {
    #expect(
        MacCurrentTaskPresentation.showsInForeground(
            status,
            includingCompleted: includingCompleted
        ) == expected
    )
}
#endif
