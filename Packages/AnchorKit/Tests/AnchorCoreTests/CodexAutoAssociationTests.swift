import Foundation
import Testing
@testable import AnchorCore

private let anchorTime = Date(timeIntervalSince1970: 1_800_000_000)
private func autoTask(_ title: String, at: Date = anchorTime) -> AnchorSession {
    AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "看完灰度数据和用户反馈，确认能不能全量上线。"), startedAt: at)
}

@Test func autoAssociationMatchesNewRelevantConversation() {
    let task = autoTask("复盘注册灰度效果")
    let result = CodexAutoAssociation.matchingSession(text: "帮我复盘一次注册灰度，计算注册完成率，整理用户反馈，判断能否全量上线。", conversationStartedAt: anchorTime.addingTimeInterval(10), sessions: [task], now: anchorTime.addingTimeInterval(20))
    #expect(result == task.id)
}

@Test func autoAssociationRejectsOldLateUnrelatedAndAmbiguousConversations() {
    let task = autoTask("复盘注册灰度效果")
    let relevant = "复盘注册灰度效果，整理用户反馈"
    for offset: Double in [-1, 1801] {
        #expect(CodexAutoAssociation.matchingSession(text: relevant, conversationStartedAt: anchorTime.addingTimeInterval(offset), sessions: [task], now: anchorTime.addingTimeInterval(3600)) == nil)
    }
    #expect(CodexAutoAssociation.matchingSession(text: "帮我完成一个任务，确认一下明天安排", conversationStartedAt: anchorTime, sessions: [task], now: anchorTime) == nil)
    #expect(CodexAutoAssociation.matchingSession(text: relevant, conversationStartedAt: anchorTime, sessions: [task, autoTask("复盘注册灰度效果")], now: anchorTime) == nil)
    #expect(CodexAutoAssociation.matchingSession(text: relevant, conversationStartedAt: anchorTime.addingTimeInterval(10), sessions: [task], now: anchorTime) == nil)
}

@Test func autoAssociationReadsOnlyUserLifecycleText() throws {
    let file = URL.temporaryDirectory.appending(path: "auto-match-\(UUID()).jsonl")
    defer { try? FileManager.default.removeItem(at: file) }
    let lines = [
        #"{"type":"response_item","payload":{"role":"assistant","content":"复盘注册灰度效果"}}"#,
        #"{"type":"event_msg","payload":{"type":"agent_message","message":"复盘注册灰度效果"}}"#,
        #"{"type":"event_msg","payload":{"type":"user_message","message":"请帮我整理灰度反馈"}}"#
    ]
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
    #expect(CodexAutoAssociation.firstUserRequest(at: file) == "请帮我整理灰度反馈")
}

@Test func autoAssociationPersistsWithoutPretendingManualConfirmation() async throws {
    let file = URL.temporaryDirectory.appending(path: "auto-association-\(UUID()).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = TaskRunStore(url: file)
    let target = AnchorEventAssociation(taskID: UUID(), workItemID: UUID(), automaticallyMatched: true)
    try await store.upsert(task: AnchorTask(id: target.taskID, title: "复盘注册灰度效果", completionCriteria: "确定上线安排"))
    try await store.upsert(workItem: AnchorWorkItem(id: target.workItemID, taskID: target.taskID, title: "Codex conversation"))
    let association = AnchorSessionAssociation(sessionID: UUID(), sourceID: UUID(), target: target)
    try await store.confirmAssociation(association)
    let saved = try #require(await store.associations().first)
    #expect(saved.target.automaticallyMatched == true)
    #expect(saved.target.confirmedByUser == false)
    let legacy = "{\"taskID\":\"\(target.taskID)\",\"workItemID\":\"\(target.workItemID)\",\"confirmedByUser\":true}"
    #expect(try JSONDecoder().decode(AnchorEventAssociation.self, from: Data(legacy.utf8)).automaticallyMatched == nil)
}

@Test func autoAssociationReadsDesktopResponseItemUserText() throws {
    let file = URL.temporaryDirectory.appending(path: "desktop-match-\(UUID()).jsonl")
    defer { try? FileManager.default.removeItem(at: file) }
    let lines = [
        #"{"type":"response_item","payload":{"type":"message","role":"developer","content":[{"type":"input_text","text":"ignored developer instructions"}]}}"#,
        #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>environment setup</environment_context>"}]}}"#,
        #"{"type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"input_text","text":"ignored assistant text"}]}}"#,
        #"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"帮我复盘注册灰度效果"}]}}"#
    ]
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
    let text = try #require(CodexAutoAssociation.firstUserRequest(at: file))
    #expect(text == "帮我复盘注册灰度效果")
    let task = autoTask("复盘注册灰度效果")
    #expect(CodexAutoAssociation.matchingSession(text: text, conversationStartedAt: anchorTime, sessions: [task], now: anchorTime) == task.id)
}
