#if os(macOS)
import AnchorCore
import AnchorTransport
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("Phone anchor discovers Mac conversation, syncs, returns and archives")
func anchorFullWorkflow() async throws {
    let root = URL.temporaryDirectory.appending(path: "anchor-workflow-\(UUID())")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "anchor-workflow-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let phoneStore = LocalSessionRepository(storageURL: root.appending(path: "phone.json"), sourceID: UUID())
    let macStore = LocalSessionRepository(storageURL: root.appending(path: "mac.json"), sourceID: UUID())
    let phone = LinkedSessionRepository(base: phoneStore, transport: WorkflowTransport(target: macStore))
    let mac = LinkedSessionRepository(base: macStore, transport: WorkflowTransport(target: phoneStore))
    let taskID = UUID()
    try await phone.send(.hostSession(AnchorSession(id: taskID,
        goal: AnchorGoal(title: "Anchor", completionCriteria: "Ship the dashboard"), startedAt: .now.addingTimeInterval(-3600))))
    try await phone.send(.forSession(taskID, .addNote("Resume from this anchor")))
    await phone.flushPendingEvents()
    #expect(await mac.currentProjection().session?.id == taskID)
    #expect(await mac.currentProjection().session?.notes.first?.text == "Resume from this anchor")

    let runs = TaskRunStore(url: root.appending(path: "runs.json"))
    let coordinator = ProcessSourceCoordinator(repository: mac, sources: [], taskRunStore: runs)
    let binder = CodexSessionBinder(repository: mac, coordinator: coordinator, taskRunStore: runs,
        checkpointStore: CodexLifecycleCheckpointStore(storageURL: root.appending(path: "checkpoints.json")))
    await coordinator.start()
    let sourceRoot = root.appending(path: "sessions")
    try FileManager.default.createDirectory(at: sourceRoot, withIntermediateDirectories: true)
    func setup() -> MacSourceSetupModel {
        MacSourceSetupModel(defaults: defaults,
            currentAnchorSessionID: { await mac.currentProjection().session?.id },
            autoAssociationSessions: { await mac.currentProjection().hostedSessions },
            onCodexSessionAssociated: { url, owner, automatic in
                try await binder.bind(fileURL: url, sessionID: owner, automaticallyMatched: automatic)
            })
    }
    let firstSetup = setup()
    await firstSetup.observeAuthorizedCodexFolder(sourceRoot)
    defer { firstSetup.stopObserving() }
    let file = sourceRoot.appending(path: "new-conversation.jsonl")
    let timestamp = ISO8601DateFormatter().string(from: .now)
    try Data("""
    {"timestamp":"\(timestamp)","type":"session_meta","payload":{"id":"conversation-1","cwd":"/tmp/Anchor","originator":"Codex Desktop"}}
    {"type":"event_msg","payload":{"type":"user_message","message":"Fix the Anchor dashboard"}}
    {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}

    """.utf8).write(to: file)
    try await workflowWait { await mac.currentProjection().session?.processes.first?.status == .running }
    await mac.flushPendingEvents()
    #expect(await phone.currentProjection().session?.processes.first?.status == .running)
    #expect(firstSetup.trackedCodexSessionIDs == ["conversation-1"])

    let otherID = UUID()
    try await phone.send(.hostSession(AnchorSession(id: otherID, goal: AnchorGoal(title: "Other work", completionCriteria: "Done"))))
    await phone.flushPendingEvents()
    firstSetup.stopObserving()
    let restoredSetup = setup()
    await restoredSetup.observeAuthorizedCodexFolder(sourceRoot)
    defer { restoredSetup.stopObserving() }
    #expect(restoredSetup.trackedCodexSessionIDs.isEmpty)
    try await phone.send(.selectSession(taskID))
    try await phone.send(.updatePresence(.away, at: .now))
    await phone.flushPendingEvents()
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let ended = formatter.string(from: .now)
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("{\"timestamp\":\"\(ended)\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"turn-1\"}}\n".utf8))
    try handle.close()
    try await workflowWait { await mac.currentProjection().session?.processes.first?.status == .completed }
    await mac.flushPendingEvents()
    let observed = await phone.currentProjection()
    #expect(observed.session?.status == .active)
    #expect(observed.additionalSessions.first(where: { $0.id == otherID })?.processes.isEmpty == true)
    try await phone.send(.updatePresence(.returning, at: .now))
    let returned = await phone.currentProjection()
    #expect(returned.session?.returnSummary?.changes.contains(where: { $0.kind == .completed }) == true)
    try await phone.send(.acknowledgeReturn)
    #expect(await phone.currentProjection().session?.returnSummary == nil)
    try await phone.send(.forSession(taskID, .completeSession))
    await phone.flushPendingEvents()
    #expect(await phone.currentProjection().archivedSessions.contains(where: { $0.id == taskID }) == true)
    #expect(await mac.currentProjection().archivedSessions.contains(where: { $0.id == taskID }) == true)
    #expect(await mac.currentProjection().hostedSessions.contains(where: { $0.id == otherID }) == true)
    await coordinator.stop()
    let reloaded = LocalSessionRepository(storageURL: root.appending(path: "phone.json"), sourceID: UUID())
    #expect(await reloaded.currentProjection().archivedSessions.first(where: { $0.id == taskID })?.notes.first?.text == "Resume from this anchor")
}

private struct WorkflowTransport: AnchorEventTransport {
    let target: LocalSessionRepository
    func send(_ event: EventEnvelope) async throws { try await target.applyRemote(event) }
}

@MainActor
private func workflowWait(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(8))
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw WorkflowTimeout() }
        try await Task.sleep(for: .milliseconds(30))
    }
}
private struct WorkflowTimeout: Error {}
#endif
