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

@MainActor
@Test("Distinct Codex sessions can remain tracked for one Anchor task")
func multipleCodexSessionsRemainTracked() async throws {
    let first = URL(filePath: "/tmp/first-codex-session.jsonl")
    let second = URL(filePath: "/tmp/second-codex-session.jsonl")
    var receivedURLs: [URL] = []
    let model = MacSourceSetupModel(
        onCodexSessionSelected: { url in receivedURLs.append(url) }
    )

    try await model.connectCodexSession(first, codexSessionID: "thread-1")
    try await model.connectCodexSession(second, codexSessionID: "thread-2")
    try await model.connectCodexSession(first, codexSessionID: "thread-1")

    #expect(receivedURLs == [first, second])
    #expect(model.trackedCodexSessionIDs == ["thread-1", "thread-2"])
    #expect(model.codexSessionFileName == second.lastPathComponent)
}
#endif
