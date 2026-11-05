#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("A WorkBuddy conversation is placed by its words and runs, waits and finishes on the task")
func workBuddyWorkflow() async throws {
    let root = URL.temporaryDirectory.appending(path: "anchor-workbuddy-\(UUID())")
    let projects = root.appending(path: "projects", directoryHint: .isDirectory)
    let project = projects.appending(path: "tmp-Anchor", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "anchor-workbuddy-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let mac = LocalSessionRepository(storageURL: root.appending(path: "mac.json"), sourceID: UUID())
    let taskID = UUID()
    try await mac.send(.hostSession(AnchorSession(id: taskID,
        goal: AnchorGoal(title: "Anchor", completionCriteria: "Ship the dashboard"), startedAt: .now.addingTimeInterval(-3600))))
    let runs = TaskRunStore(url: root.appending(path: "runs.json"))
    let coordinator = ProcessSourceCoordinator(repository: mac, sources: [], taskRunStore: runs)
    let binder = CodexSessionBinder(repository: mac, coordinator: coordinator, taskRunStore: runs,
        checkpointStore: CodexLifecycleCheckpointStore(storageURL: root.appending(path: "checkpoints.json")))
    await coordinator.start()
    let setup = MacSourceSetupModel(defaults: defaults,
        currentAnchorSessionID: { await mac.currentProjection().session?.id },
        autoAssociationSessions: { await mac.currentProjection().hostedSessions },
        onCodexSessionAssociated: { url, owner, automatic, step in
            try await binder.bind(fileURL: url, sessionID: owner, automaticallyMatched: automatic, stepID: step)
        })
    await setup.observeAuthorizedWorkBuddyFolder(projects)
    defer { setup.stopObserving() }
    #expect(setup.hasConversationSource)
    #expect(setup.workBuddyFolderName == "projects")
    #expect(setup.agentLogRoots == [projects])

    let id = "22222222-2222-2222-2222-222222222222"
    let file = project.appending(path: "\(id).jsonl")
    let start = Int(Date.now.timeIntervalSince1970 * 1_000) - 30_000
    func append(_ line: String) throws {
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: file)
        }
    }
    func latest() async -> AnchorProcess? {
        await mac.currentProjection().session?.processes.max { $0.updatedAt < $1.updatedAt }
    }

    // "Fix the Anchor dashboard" shares words with the task, so it attaches by itself.
    try append(#"{"type":"session-meta","id":"m","sessionId":"\#(id)","timestamp":\#(start),"meta":{}}"#)
    try append(#"{"id":"u","timestamp":\#(start + 100),"type":"message","role":"user","content":[{"type":"input_text","text":"<user_info>Mac</user_info><user_query>Fix the Anchor dashboard</user_query>"}],"providerData":{"startsNewUserRequest":true,"conversationRequestId":"r-1"},"sessionId":"\#(id)","cwd":"/tmp/Anchor"}"#)
    try await workBuddyWait { setup.conversationTasks[id] == taskID }
    try await workBuddyWait { await latest()?.status == .running }
    #expect(await latest()?.sourceSymbol == "WB")
    #expect(await latest()?.sourceName == "WorkBuddy")

    try append(#"{"id":"q","timestamp":\#(start + 5_000),"type":"function_call","providerData":{"conversationRequestId":"r-1","usage":{"requests":1}},"callId":"q1","name":"AskUserQuestion","arguments":"{}","sessionId":"\#(id)"}"#)
    // As with Claude Code, the turn keeps running while its conversation says it waits on the person.
    try await workBuddyWait {
        await setup.refreshCodexCandidates()
        return setup.codexConversations.first { $0.id == id }?.isWaitingForReply == true
    }

    try append(#"{"id":"qr","timestamp":\#(start + 8_000),"type":"function_call_result","name":"AskUserQuestion","callId":"q1","status":"completed","output":[],"sessionId":"\#(id)"}"#)
    try append(#"{"id":"a","timestamp":\#(start + 9_000),"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"Fixed it."}],"providerData":{"conversationRequestId":"r-1","usage":{"requests":1}},"sessionId":"\#(id)"}"#)
    try await workBuddyWait { await latest()?.status == .completed }
}

@MainActor
private func workBuddyWait(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw WorkBuddyTimeout() }
        try await Task.sleep(for: .milliseconds(30))
    }
}
private struct WorkBuddyTimeout: Error {}
#endif
