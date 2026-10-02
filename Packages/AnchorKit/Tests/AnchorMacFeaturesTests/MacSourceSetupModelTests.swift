#if os(macOS)
import Foundation
import AnchorCore
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

@MainActor
@Test("Manual bindings restore their original active task while another task is selected")
func manualBindingRestoresOriginalOwner() async throws {
    let root = URL.temporaryDirectory.appending(path: "anchor-manual-restore-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "anchor-manual-restore-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let owner = AnchorSession(goal: AnchorGoal(title: "Owner", completionCriteria: "Done"))
    let other = AnchorSession(goal: AnchorGoal(title: "Other", completionCriteria: "Done"))
    let repository = InMemorySessionRepository(initialProjection: SessionProjection(session: owner, additionalSessions: [other]))
    let file = root.appending(path: "manual.jsonl")
    try Data("{\"type\":\"session_meta\",\"payload\":{\"id\":\"manual-thread\"}}\n".utf8).write(to: file)
    var calls: [(UUID, Bool)] = []
    func setup() -> MacSourceSetupModel {
        MacSourceSetupModel(defaults: defaults,
            currentAnchorSessionID: { await repository.currentProjection().session?.id },
            autoAssociationSessions: { await repository.currentProjection().hostedSessions },
            onCodexSessionAssociated: { _, id, automatic in calls.append((id, automatic)) })
    }
    let original = setup()
    await original.observeAuthorizedCodexFolder(root)
    let candidate = try #require(await CodexTaskSupervisor(rootURL: root).snapshot().first)
    await original.trackCodexSession(candidate)
    original.stopObserving()
    #expect(calls.count == 1)
    try await repository.send(.selectSession(other.id))
    let restored = setup()
    defer { restored.stopObserving() }
    await restored.observeAuthorizedCodexFolder(root)
    await restored.refreshTaskState()
    await restored.refreshTaskState()
    #expect(calls.count == 2)
    #expect(calls.last?.0 == owner.id)
    #expect(calls.last?.1 == false)
    #expect(restored.trackedCodexSessionIDs.isEmpty)
}
#endif
