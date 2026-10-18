#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("Claude Code work attaches to its task like Codex work, and stays attached after a restart")
func claudeCodeWorkAttachesItself() async throws {
    let root = URL.temporaryDirectory.appending(path: "anchor-claude-placement-\(UUID())")
    let project = root.appending(path: "-tmp-homework")
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    let suite = "anchor-claude-placement-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
    let homework = AnchorSession(goal: AnchorGoal(title: "数据结构作业", completionCriteria: "红黑树的插入和删除都通过测试",
        userPlan: AnchorUserPlan(steps: ["实现插入", "实现删除操作", "补边界情况测试"])),
        status: .active, startedAt: .now.addingTimeInterval(-3_600))
    let website = AnchorSession(goal: AnchorGoal(title: "个人网站", completionCriteria: "作品集上线",
        userPlan: AnchorUserPlan(steps: ["做项目页", "部署上线"])),
        status: .active, startedAt: .now.addingTimeInterval(-3_600))
    let repository = InMemorySessionRepository(initialProjection: SessionProjection(session: homework, additionalSessions: [website]))
    let started = ISO8601DateFormatter().string(from: .now.addingTimeInterval(-60))
    let prompt = #"{"parentUuid":null,"isSidechain":false,"userType":"external","cwd":"/tmp/homework","sessionId":"claude-1","type":"user","message":{"role":"user","content":"帮我实现红黑树的删除操作"},"uuid":"u-1","timestamp":"\#(started)"}"#
    try Data((prompt + "\n").utf8).write(to: project.appending(path: "claude-1.jsonl"))

    var calls: [(URL, UUID, Bool, UUID?)] = []
    func makeModel() -> MacSourceSetupModel {
        MacSourceSetupModel(defaults: defaults,
            currentAnchorSessionID: { await repository.currentProjection().session?.id },
            autoAssociationSessions: { await repository.currentProjection().hostedSessions },
            onCodexSessionAssociated: { url, owner, automatic, step in calls.append((url, owner, automatic, step)) })
    }
    let model = makeModel()
    await model.observeAuthorizedClaudeFolder(root)
    #expect(model.hasConversationSource)
    #expect(model.codexSessionsFolderName == nil)
    let conversations = await CodexTaskSupervisor(rootURL: root, dialect: .claudeCode).summaries()
    await model.placeConversations(conversations)

    #expect(calls.count == 1)
    #expect(calls.first?.1 == homework.id)
    #expect(calls.first?.3 == homework.goal.userPlan?.items[1].id)
    #expect(model.conversationTasks["claude-1"] == homework.id)
    model.stopObserving()

    // After a relaunch the saved link finds the file under the Claude Code folder again.
    let restored = makeModel()
    defer { restored.stopObserving() }
    await restored.observeAuthorizedClaudeFolder(root)
    #expect(calls.count == 2)
    #expect(calls.last?.0.lastPathComponent == "claude-1.jsonl")
    #expect(calls.last?.1 == homework.id)
}
#endif
