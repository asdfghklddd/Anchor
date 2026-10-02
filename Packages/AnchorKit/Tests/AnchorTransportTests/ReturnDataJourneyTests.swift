import AnchorCore
import Foundation
import Testing
@testable import AnchorTransport

@Suite("Populated return data journey")
struct ReturnDataJourneyTests {
    @Test("Notes and mixed Mac outcomes fill an open return page after delayed, repeated replay")
    @MainActor
    func delayedReturnReplay() async throws {
        let root = URL.temporaryDirectory.appending(path: "anchor-return-journey-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let phoneURL = root.appending(path: "phone.json")
        let phone = LocalSessionRepository(storageURL: phoneURL, sourceID: UUID())
        let mac = LocalSessionRepository(storageURL: root.appending(path: "mac.json"), sourceID: UUID())
        let toPhone = ReturnPeerTransport(receiver: phone)
        let toMac = ReturnPeerTransport(receiver: mac)
        let phoneLink = LinkedSessionRepository(base: phone, transport: toMac)
        let macLink = LinkedSessionRepository(base: mac, transport: toPhone)
        let now = Date.now
        let left = now.addingTimeInterval(-780)
        let session = AnchorSession(goal: AnchorGoal(
            title: "完善 Anchor 的离开与返航体验，并验证手机与 Mac 的任务同步",
            completionCriteria: "真实任务状态可以同步；返航摘要完整，长内容和大字号均可阅读。",
            userPlan: AnchorUserPlan(steps: ["修复终端构建错误", "运行回归测试", "检查手机上的返航摘要"])), startedAt: left.addingTimeInterval(-60))
        try await phoneLink.send(.hostSession(session))
        let note = AnchorNote(sessionID: session.id, origin: "session",
            text: "先检查终端构建失败的原因；修复后重新运行回归测试，再确认返航摘要的内容。",
            createdAt: left.addingTimeInterval(-20))
        // The note goes through the same immutable operation as an anchor record.
        let noteEnvelope = EventEnvelope(sessionID: session.id, sourceID: UUID(), sequence: 1,
            timestamp: note.createdAt, type: EventEnvelope.operationType,
            payload: try JSONEncoder.anchor.encode(SessionOperation.addNote(note)))
        try await phone.applyRemote(noteEnvelope)
        await phoneLink.reconcilePeerHistory()
        try await phoneLink.send(.updatePresence(.away, at: left))
        await phoneLink.flushPendingEvents()
        await toPhone.setConnected(false)

        let specifications: [(ProcessStatus, String, String, ProcessEventKind, String)] = [
            (.completed, "Codex", "整理任务同步接口", .completed, "任务同步接口整理完成"),
            (.completed, "Terminal", "验证事件去重与任务归属", .completed, "事件回放与去重测试通过"),
            (.running, "Codex", "检查长标题、大字号和多任务状态下的返航卡片布局", .progress, "正在检查返航页面的长内容布局"),
            (.disconnected, "Terminal", "持续观察构建日志", .progress, "构建日志连接已中断，尚未收到后续状态"),
            (.failed, "Codex", "生成辅助说明文档", .failed, "Codex turn_aborted"),
            (.queued, "Terminal", "运行最终回归测试", .created, "最终回归测试已排队"),
            (.failed, "Terminal", "Release 构建：检查签名配置与资源打包", .failed, "Release 构建未通过：缺少签名配置，需要回到 Mac 检查")
        ]
        for (index, item) in specifications.enumerated() {
            let date = left.addingTimeInterval(Double(80 + index * 80))
            let sourceID = UUID()
            let process = AnchorProcess(sessionID: session.id, sourceID: sourceID,
                sourceName: item.1, sourceSymbol: item.1 == "Codex" ? "C" : ">_", sourceTone: "cyan",
                title: item.2, status: item.0,
                detail: index == 6 ? "构建进程退出码为 65。检查 Xcode 的 Signing & Capabilities 设置，修复后再运行构建。Anchor 只记录状态，不会替你修改签名配置。" : "来源已报告当前状态；完整任务记录可在详情中查看。",
                updatedAt: date)
            let event = ProcessEvent(sessionID: session.id, processID: process.id, sourceID: sourceID,
                occurredAt: date, kind: item.3, title: item.4, detail: process.detail)
            try await macLink.send(.observeProcess(ProcessObservation(process: process, event: event)))
        }
        await macLink.flushPendingEvents()
        #expect(await phone.currentProjection().session?.processes.isEmpty == true)
        try await phoneLink.send(.updatePresence(.returning, at: now))
        #expect(await phone.currentProjection().session?.returnSummary?.changes.isEmpty == true)
        await phoneLink.flushPendingEvents()
        let phoneModel = AnchorSessionModel(repository: phoneLink,
            initialProjection: await phone.currentProjection(), usesTaskDashboard: true)
        phoneModel.start()
        defer { phoneModel.stop() }
        #expect(phoneModel.claimReturnFeedback())
        await toPhone.setConnected(true)
        await macLink.reconcilePeerHistory()
        await macLink.reconcilePeerHistory()
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while phoneModel.projection.session?.returnSummary?.changes.count != 7,
              ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(phoneModel.projection.session?.returnSummary?.changes.count == 7)
        #expect(!phoneModel.claimReturnFeedback())
        let reviewed = phoneModel.projection
        let returned = try #require(reviewed.session)
        #expect(returned.returnSummary?.changes.count == 7)
        #expect(returned.processes.count == 7)
        #expect(returned.notes.first?.text == note.text)
        #expect(returned.returnSummary?.awaySince == left)
        #expect(returned.processes.filter(\.isInterrupted).count == 1)
        #expect(returned.processes.filter { $0.status == .completed }.count == 2)
        #expect(returned.returnSummary?.generatedAt == now)
        let restored = LocalSessionRepository(storageURL: phoneURL, sourceID: UUID())
        #expect(TaskDashboardPolicy.presentation(of: await restored.currentProjection()).session?.returnSummary == returned.returnSummary)

        // Optional artifact for the isolated simulator, never read by a shipping target.
        if let destination = ProcessInfo.processInfo.environment["ANCHOR_RETURN_REVIEW_EXPORT"] {
            let directory = URL(fileURLWithPath: destination)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(contentsOf: phoneURL).write(to: directory.appending(path: "phone.json"))
        }
        #expect(await phoneModel.continueWorking())
        await phoneLink.flushPendingEvents()
        #expect(await phone.currentProjection().session?.returnSummary == nil)
        #expect(await mac.currentProjection().session?.presence == .atDesk)
        #expect(await phone.currentProjection().session?.processes.count == 7)
        #expect(await phone.currentProjection().session?.notes.first?.text == note.text)
    }
}

private actor ReturnPeerTransport: AnchorEventTransport {
    let receiver: any EventBackedSessionRepository
    var connected = true
    init(receiver: any EventBackedSessionRepository) { self.receiver = receiver }
    func setConnected(_ value: Bool) { connected = value }
    func send(_ event: EventEnvelope) async throws {
        guard connected else { throw AnchorLinkError.connectionLost }
        try await receiver.applyRemote(event)
    }
}
