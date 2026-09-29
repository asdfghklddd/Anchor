#if os(macOS)
import Testing
@testable import AnchorMacFeatures

@Test(
    "Stored sidebar values migrate to the three-section navigation",
    arguments: [
        ("current", MacSection.current),
        ("history", MacSection.history),
        ("settings", MacSection.settings),
        ("timeline", MacSection.current),
        ("sources", MacSection.settings),
        ("unknown", MacSection.current),
    ]
)
func storedSectionMigration(storedValue: String, expected: MacSection) {
    #expect(MacSection(storedValue: storedValue) == expected)
}
#endif
