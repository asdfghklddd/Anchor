#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("A DeepSeek Harness conversation is placed by its words and runs, waits and finishes on the task")
func deepSeekHarnessWorkflow() async throws {
    let root = URL.temporaryDirectory.appending(path: "anchor-harness-\(UUID())")
    let sessions = root.appending(path: "session_projcache/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let suite = "anchor-harness-\(UUID())"
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
    await setup.observeAuthorizedHarnessFolder(sessions)
    defer { setup.stopObserving() }
    #expect(setup.hasConversationSource)
    #expect(setup.agentLogRoots == [sessions])

    let file = sessions.appending(path: "session-11111111-1111-1111-1111-111111111111.json")
    var step = 0
    func write(open: Bool, asking: Bool, answered: Int) throws {
        step += 1
        try harnessStatus(open: open, asking: asking, answered: answered).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: Date.now.addingTimeInterval(Double(step))],
                                              ofItemAtPath: file.path)
    }
    func latest() async -> AnchorProcess? {
        await mac.currentProjection().session?.processes.max { $0.updatedAt < $1.updatedAt }
    }

    // "Fix the Anchor dashboard" shares two words with the task, so it attaches by itself.
    try write(open: true, asking: false, answered: 0)
    try await harnessWait { setup.conversationTasks["11111111-1111-1111-1111-111111111111"] == taskID }
    try await harnessWait { await latest()?.status == .running }
    #expect(await latest()?.sourceSymbol == "DS")
    #expect(await latest()?.sourceName == "DeepSeek")

    try write(open: true, asking: true, answered: 0)
    try await harnessWait { await latest()?.status == .needsDecision }

    try write(open: false, asking: false, answered: 1)
    try await harnessWait { await latest()?.status == .completed }
    #expect(await latest()?.workedSeconds == 42)
}

private func harnessStatus(open: Bool, asking: Bool, answered: Int) throws -> Data {
    let now = Int(Date.now.timeIntervalSince1970 * 1_000)
    let question = #"{"id":"q"}"#
    let json = """
    {"version":7,"record":{"identity":{"formatVersion":4,"createdAt":\(now - 60_000),"cwd":"/tmp/Anchor","isSeeded":false,"inheritedEventCount":0},
    "rows":{"title":{"ver":1,"seq":1,"val":null},
    "workingDirectory":{"ver":1,"seq":1,"val":"/tmp/Anchor"},
    "turnBoundary":{"ver":1,"seq":1,"val":{"openTurnStartSeq":\(open ? "5" : "null"),"lastStepStartSeq":7,"lastTurn":1}},
    "sessionStats":{"ver":1,"seq":1,"val":{"turns":\(open ? 0 : 1),"steps":2,"llmMs":40000,"toolMs":2000}},
    "tokenUsage":{"ver":1,"seq":1,"val":{"totals":{"uncachedInputTokens":900,"outputTokens":30,"cacheReadTokens":0,"cacheWriteTokens":0}}},
    "turnOutline":{"ver":1,"seq":1,"val":{"turns":[{"turn":1,"seq":4,"prompt":"Fix the Anchor dashboard","response":"\(open ? "" : "Fixed it.")"}],"draft":""}},
    "userQuestions":{"ver":1,"seq":1,"val":{"inheritedEventCount":0,"timed":false,"questions":{"active":[\(asking ? question : "")],"settled":[\(Array(repeating: question, count: answered).joined(separator: ","))]}}},
    "subagent":{"ver":1,"seq":1,"val":{}},
    "sessionListMetadata":{"ver":1,"seq":1,"val":{"blank":false,"lastPromptAt":\(now - 30_000)}}}}}
    """
    return Data(json.utf8)
}

@MainActor
private func harnessWait(_ condition: () async -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw HarnessTimeout() }
        try await Task.sleep(for: .milliseconds(30))
    }
}
private struct HarnessTimeout: Error {}
#endif
