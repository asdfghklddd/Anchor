#if os(macOS)
import Foundation
import AnchorCore
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("Clear work attaches itself to its task and step, and nothing pops up")
func codexClearWorkAttachesItself() async throws {
    let fixture = try CodexPlacementFixture(request: "帮我实现红黑树的删除操作")
    defer { fixture.cleanup() }
    var calls: [(UUID, Bool)] = []
    let model = fixture.model { _, owner, automatic in calls.append((owner, automatic)) }
    defer { model.stopObserving() }
    var attention = 0
    model.onNeedsAttention = { attention += 1 }
    await model.observeAuthorizedCodexFolder(fixture.root)
    await model.placeConversations(try await fixture.conversations())

    #expect(calls.count == 1)
    #expect(calls.first?.0 == fixture.homework.id)
    #expect(calls.first?.1 == true)
    #expect(model.conversationTasks[fixture.conversationID] == fixture.homework.id)
    #expect(model.conversationSteps[fixture.conversationID] == fixture.homework.goal.userPlan?.items[1].id)
    #expect(model.unsortedConversations.isEmpty)
    #expect(attention == 0)
}

@MainActor
@Test("Unclear work waits unsorted; filing it is remembered across a restart")
func codexUnclearWorkWaitsAndFilingIsRemembered() async throws {
    let fixture = try CodexPlacementFixture(request: "继续")
    defer { fixture.cleanup() }
    var calls: [(UUID, Bool)] = []
    let model = fixture.model { _, owner, automatic in calls.append((owner, automatic)) }
    await model.observeAuthorizedCodexFolder(fixture.root)
    let conversations = try await fixture.conversations()
    await model.placeConversations(conversations)
    #expect(calls.isEmpty)
    let unsorted = try #require(model.unsortedConversations.first)
    #expect(unsorted.id == fixture.conversationID)

    await model.assign(unsorted, to: fixture.website.id)
    #expect(calls.count == 1)
    #expect(calls.first?.0 == fixture.website.id)
    #expect(calls.first?.1 == false)
    #expect(model.unsortedConversations.isEmpty)
    model.stopObserving()

    let restored = fixture.model { _, owner, automatic in calls.append((owner, automatic)) }
    defer { restored.stopObserving() }
    await restored.observeAuthorizedCodexFolder(fixture.root)
    await restored.placeConversations(conversations)
    #expect(calls.last?.0 == fixture.website.id)
    #expect(restored.conversationTasks[fixture.conversationID] == fixture.website.id)
    #expect(restored.unsortedConversations.isEmpty)
}

@MainActor
@Test("Moving work unbinds it from the old task; not part of a task stops following it")
func codexMoveAndIgnore() async throws {
    let fixture = try CodexPlacementFixture(request: "帮我实现红黑树的删除操作")
    defer { fixture.cleanup() }
    var unbound: [UUID] = []
    let model = fixture.model(onBind: { _, _, _ in }, onUnbind: { _, owner in unbound.append(owner) })
    defer { model.stopObserving() }
    await model.observeAuthorizedCodexFolder(fixture.root)
    let conversations = try await fixture.conversations()
    await model.placeConversations(conversations)
    let conversation = try #require(conversations.first)

    await model.assign(conversation, to: fixture.website.id)
    #expect(unbound == [fixture.homework.id])
    #expect(model.conversationTasks[fixture.conversationID] == fixture.website.id)

    await model.ignore(conversation)
    #expect(unbound == [fixture.homework.id, fixture.website.id])
    await model.placeConversations(conversations)
    #expect(model.conversationTasks[fixture.conversationID] == nil)
    #expect(model.unsortedConversations.isEmpty)
    #expect(model.isIgnored(fixture.conversationID))
}

@MainActor
@Test("A finished task never receives work")
func codexFinishedTaskGetsNoWork() async throws {
    let fixture = try CodexPlacementFixture(request: "帮我实现红黑树的删除操作")
    defer { fixture.cleanup() }
    try await fixture.repository.send(.forSession(fixture.homework.id, .completeSession))
    let model = fixture.model { _, owner, _ in
        if owner == fixture.homework.id { Issue.record("A finished task must not receive work") }
    }
    defer { model.stopObserving() }
    await model.observeAuthorizedCodexFolder(fixture.root)
    await model.placeConversations(try await fixture.conversations())
    #expect(model.conversationTasks[fixture.conversationID] != fixture.homework.id)
}

@MainActor
private struct CodexPlacementFixture {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let homework: AnchorSession
    let website: AnchorSession
    let repository: InMemorySessionRepository
    let conversationID = "placement-thread"

    init(request: String) throws {
        root = URL.temporaryDirectory.appending(path: "anchor-placement-\(UUID())")
        suite = "anchor-placement-\(UUID())"
        defaults = try #require(UserDefaults(suiteName: suite))
        homework = AnchorSession(goal: AnchorGoal(title: "数据结构作业", completionCriteria: "红黑树的插入和删除都通过测试",
            userPlan: AnchorUserPlan(steps: ["实现插入", "实现删除操作", "补边界情况测试"])),
            status: .active, startedAt: .now.addingTimeInterval(-3_600))
        website = AnchorSession(goal: AnchorGoal(title: "个人网站", completionCriteria: "作品集上线",
            userPlan: AnchorUserPlan(steps: ["做项目页", "部署上线"])),
            status: .active, startedAt: .now.addingTimeInterval(-3_600))
        repository = InMemorySessionRepository(initialProjection: SessionProjection(session: homework, additionalSessions: [website]))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let created = formatter.string(from: .now.addingTimeInterval(-86_400))
        let started = formatter.string(from: .now.addingTimeInterval(-60))
        try Data("""
        {"timestamp":"\(created)","type":"session_meta","payload":{"id":"\(conversationID)","cwd":"/tmp/homework","originator":"Codex Desktop"}}
        {"type":"event_msg","payload":{"type":"user_message","message":"\(request)"}}
        {"timestamp":"\(started)","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}

        """.utf8).write(to: root.appending(path: "rollout-placement.jsonl"))
    }

    func conversations() async throws -> [CodexConversationSummary] {
        await CodexTaskSupervisor(rootURL: root).summaries()
    }

    func model(
        onBind: @escaping @MainActor @Sendable (URL, UUID, Bool) async throws -> Void,
        onUnbind: (@MainActor @Sendable (URL, UUID) async throws -> Void)? = nil
    ) -> MacSourceSetupModel {
        let repository = repository
        return MacSourceSetupModel(defaults: defaults,
            currentAnchorSessionID: { await repository.currentProjection().session?.id },
            autoAssociationSessions: { await repository.currentProjection().hostedSessions },
            onCodexSessionAssociated: onBind,
            onCodexSessionUnbound: onUnbind)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}
#endif

#if os(macOS)
import AppKit
import SwiftUI

@MainActor
@Test func codexConnectionSheetPreviews() async throws {
    guard let destination = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"] else { return }
    let fixture = try CodexPlacementFixture(request: "继续")
    defer { fixture.cleanup() }
    let model = fixture.model { _, _, _ in }
    defer { model.stopObserving() }
    model.presentCodexSetupIfNeeded()
    for scheme in [ColorScheme.light, .dark] {
        let view = NSHostingView(rootView: MacCodexConnectionSheet(model: model)
            .environment(\.colorScheme, scheme)
            .environment(\.locale, Locale(identifier: "zh-Hans")))
        view.setFrameSize(view.fittingSize)
        view.layoutSubtreeIfNeeded()
        let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let directory = URL(filePath: destination)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try png.write(to: directory.appending(path: "codex-onboarding-\(scheme == .dark ? "dark" : "light").png"))
    }
}
#endif
