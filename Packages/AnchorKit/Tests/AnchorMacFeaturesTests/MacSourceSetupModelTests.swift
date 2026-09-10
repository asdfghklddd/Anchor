#if os(macOS)
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("Connecting a Codex session updates the visible source status")
func codexSessionConnectionUpdatesVisibleStatus() async throws {
    let selectedURL = URL(filePath: "/tmp/current-codex-session.jsonl")
    var receivedURL: URL?
    let model = MacSourceSetupModel(
        onCodexSessionSelected: { url in receivedURL = url }
    )

    try await model.connectCodexSession(selectedURL)

    #expect(receivedURL == selectedURL)
    #expect(model.codexSessionFileName == selectedURL.lastPathComponent)
}
#endif
