import Foundation
import Testing
@testable import AnchorCore

/// Realistic multi-task data for reviewing the home glance. The repository is
/// exported only when an isolated preview runner sets the variable below.
@Suite("Design preview data")
struct DesignPreviewFixtureTests {
    @Test("Mixed lifecycle states survive a reload")
    func mixedLifecycleStates() async throws {
        let directory = URL.temporaryDirectory.appending(path: "anchor-design-preview-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appending(path: "session-repository.json")
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let now = Date.now

        func at(_ minutesAgo: Double) -> Date { now.addingTimeInterval(-minutesAgo * 60) }
        func conversation(_ title: String, task: UUID, source: String = "Codex",
                          sourceID: UUID = UUID(), status: ProcessStatus,
                          _ events: [(ProcessEventKind, Double, String, String?)]) -> AnchorProcess {
            let processID = UUID()
            let mapped = events.map { kind, minutes, eventTitle, metric in
                ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID,
                             occurredAt: at(minutes), kind: kind, title: eventTitle, metric: metric)
            }
            return AnchorProcess(id: processID, sessionID: task, sourceID: sourceID, sourceName: source,
                                 sourceSymbol: source == "Codex" ? "C" : ">_", sourceTone: "cyan",
                                 title: title, status: status,
                                 updatedAt: mapped.map(\.occurredAt).max() ?? now, events: mapped)
        }
        func id(_ index: Int) -> UUID { UUID(uuidString: String(format: "DE51A000-7215-40E0-8B0B-%012d", index))! }

        let tasks: [AnchorSession] = [
            AnchorSession(id: id(1), goal: AnchorGoal(title: "重构同步协议", completionCriteria: "两端协议版本一致，测试全部通过"),
                startedAt: at(72), processes: [
                    conversation("sync-protocol", task: id(1), status: .running, [
                        (.created, 66, "Codex task_started", nil), (.completed, 41, "Codex task_complete", nil),
                        (.created, 24, "Codex task_started", nil)
                    ]),
                    conversation("swift test", task: id(1), source: "终端", sourceID: BuiltInProcessSourceID.file,
                                 status: .completed, [(.created, 19, "swift test", nil), (.completed, 13, "swift test", "0")])
                ], taskColorIndex: 0),
            AnchorSession(id: id(2), goal: AnchorGoal(title: "修复登录崩溃", completionCriteria: "冷启动登录不再崩溃"),
                startedAt: at(52), processes: [
                    conversation("login-crash", task: id(2), status: .failed, [
                        (.created, 48, "Codex task_started", nil), (.failed, 11, "Codex task_failed", nil)
                    ])
                ], taskColorIndex: 1),
            AnchorSession(id: id(3), goal: AnchorGoal(title: "撰写发布说明", completionCriteria: "中英文说明都已定稿"),
                startedAt: at(34), processes: [
                    conversation("release-notes", task: id(3), status: .completed, [
                        (.created, 30, "Codex task_started", nil), (.completed, 6, "Codex task_complete", nil)
                    ])
                ], taskColorIndex: 2),
            AnchorSession(id: id(4), goal: AnchorGoal(title: "数据迁移脚本", completionCriteria: "旧数据完整迁移"),
                startedAt: at(21), processes: [
                    conversation("python migrate.py", task: id(4), source: "终端", sourceID: BuiltInProcessSourceID.file,
                                 status: .failed, [(.created, 18, "python started", nil), (.failed, 3, "python interrupted", "130")])
                ], taskColorIndex: 3),
            AnchorSession(id: id(5), goal: AnchorGoal(title: "整理设计文档", completionCriteria: "规范与实现一致"),
                startedAt: at(4), taskColorIndex: 4)
        ]
        for task in tasks { try await repository.send(.hostSession(task)) }

        let restored = await LocalSessionRepository(storageURL: storage, sourceID: UUID()).currentProjection()
        let glance = WorkGlance(tasks: restored.hostedSessions)
        #expect(restored.hostedSessions.count == 5)
        #expect(glance.headline == .failed(1))
        #expect(glance.attention == 1)
        #expect(glance.running == 1)

        // Used only by the isolated design preview runner; shipping targets never read this variable.
        if let destination = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"] {
            let output = URL(fileURLWithPath: destination)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: storage).write(to: output.appending(path: "session-repository.json"))
        }
    }

    @Test("Live plans keep each task's next action across a reload and a return")
    func livePlanNextActions() async throws {
        let directory = URL.temporaryDirectory.appending(path: "anchor-live-plan-preview-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appending(path: "session-repository.json")
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let now = Date.now

        func at(_ minutesAgo: Double) -> Date { now.addingTimeInterval(-minutesAgo * 60) }
        func id(_ index: Int) -> UUID { UUID(uuidString: String(format: "1A7E0000-7215-40E0-8B0B-%012d", index))! }
        func codex(_ title: String, task: UUID, status: ProcessStatus, started: Double, ended: Double? = nil,
                   reply: String = "") -> AnchorProcess {
            let processID = UUID(), sourceID = UUID()
            var events = [ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID,
                                       occurredAt: at(started), kind: .created, title: "Codex task_started", metric: nil)]
            if let ended {
                events.append(ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID, occurredAt: at(ended),
                                           kind: status == .completed ? .completed : .failed,
                                           title: status == .completed ? "Codex task_complete" : "Codex task_failed", metric: nil))
            }
            return AnchorProcess(id: processID, sessionID: task, sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C",
                                 sourceTone: "cyan", title: title, status: status, detail: reply,
                                 updatedAt: events.map(\.occurredAt).max() ?? now, events: events)
        }
        func plan(_ steps: [String], done: [Int], reviewed: Double?) -> AnchorUserPlan {
            AnchorUserPlan(steps: steps, completedSteps: done, reviewedAt: reviewed.map(at))
        }

        let homework = AnchorSession(id: id(1), goal: AnchorGoal(
            title: "数据结构作业", completionCriteria: "红黑树的插入和删除都通过测试",
            userPlan: plan(["实现插入", "实现删除操作", "补边界情况测试", "写实验报告"], done: [0], reviewed: 45)),
            startedAt: at(120), processes: [codex("红黑树删除", task: id(1), status: .completed, started: 32, ended: 4,
                                         reply: "已实现 delete 和 fixup，所有测试通过。另外补了一个回归测试，覆盖删除根节点的情况。")],
            taskColorIndex: 0)
        let website = AnchorSession(id: id(2), goal: AnchorGoal(
            title: "个人网站", completionCriteria: "作品集页面上线",
            userPlan: plan(["整理项目清单", "做项目页", "部署上线"], done: [0], reviewed: 90)),
            startedAt: at(300), processes: [codex("portfolio", task: id(2), status: .completed, started: 150, ended: 120)],
            taskColorIndex: 1)
        let anchor = AnchorSession(id: id(3), goal: AnchorGoal(
            title: "Anchor", completionCriteria: "每天都愿意用",
            userPlan: plan(["自动显示对话", "完成提醒", "活的计划", "手机端提醒", "可靠连接"], done: [0, 1, 2], reviewed: 20)),
            startedAt: at(240), processes: [codex("Anchor", task: id(3), status: .running, started: 12)],
            taskColorIndex: 2)
        let notes = AnchorSession(id: id(4), goal: AnchorGoal(
            title: "研究笔记", completionCriteria: "整理好推荐系统论文",
            userPlan: plan(["读第 3 篇论文", "整理笔记"], done: [], reviewed: nil)),
            startedAt: at(60), taskColorIndex: 3)
        for task in [website, anchor, notes, homework] { try await repository.send(.hostSession(task)) }
        try await repository.send(.selectSession(homework.id))

        let atDesk = await LocalSessionRepository(storageURL: storage, sourceID: UUID()).currentProjection()
        let actions = Dictionary(uniqueKeysWithValues: atDesk.hostedSessions.map { ($0.id, TaskNextAction(task: $0)) })
        #expect(actions[homework.id] == .review(process: "红黑树删除"))
        #expect(actions[website.id] == .start(step: 1, text: "做项目页"))
        #expect(actions[anchor.id]??.needsPerson == false)
        #expect(actions[notes.id] == .start(step: 0, text: "读第 3 篇论文"))
        let export = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"].map { URL(fileURLWithPath: $0) }
        if let export {
            let output = export.appending(path: "live-plan-home")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: storage).write(to: output.appending(path: "session-repository.json"))
        }

        try await repository.send(.updatePresence(.away, at: at(40), awaySince: at(40)))
        try await repository.send(.updatePresence(.returning, at: now))
        let returned = await LocalSessionRepository(storageURL: storage, sourceID: UUID()).currentProjection()
        #expect(returned.session?.id == homework.id)
        #expect(returned.session?.presence == .returning)
        #expect(returned.session.flatMap(TaskNextAction.init(task:)) == .review(process: "红黑树删除"))
        if let export {
            let output = export.appending(path: "live-plan-return")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: storage).write(to: output.appending(path: "session-repository.json"))
        }
    }

    @Test("While the current task's agent works, the desk points at the task that needs you")
    func deskWaitMeanwhile() async throws {
        let directory = URL.temporaryDirectory.appending(path: "anchor-desk-wait-preview-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appending(path: "session-repository.json")
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let now = Date.now

        func at(_ minutesAgo: Double) -> Date { now.addingTimeInterval(-minutesAgo * 60) }
        func id(_ index: Int) -> UUID { UUID(uuidString: String(format: "DE5C0000-7215-40E0-8B0B-%012d", index))! }
        func codex(_ title: String, task: UUID, status: ProcessStatus, started: Double, ended: Double? = nil,
                   step: UUID? = nil, reply: String = "") -> AnchorProcess {
            let processID = UUID(), sourceID = UUID()
            var events = [ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID,
                                       occurredAt: at(started), kind: .created, title: "Codex task_started", metric: nil)]
            if let ended {
                events.append(ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID, occurredAt: at(ended),
                                           kind: .completed, title: "Codex task_complete", metric: nil))
            }
            return AnchorProcess(id: processID, sessionID: task, sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C",
                                 sourceTone: "cyan", title: title, status: status, detail: reply,
                                 updatedAt: events.map(\.occurredAt).max() ?? now, events: events, stepID: step)
        }

        let homeworkPlan = AnchorUserPlan(steps: ["实现插入", "实现删除操作", "补边界情况测试", "写实验报告"],
                                          completedSteps: [0], reviewedAt: at(45))
        let homework = AnchorSession(id: id(1), goal: AnchorGoal(
            title: "数据结构作业", completionCriteria: "红黑树的插入和删除都通过测试", userPlan: homeworkPlan),
            startedAt: at(120), processes: [codex("红黑树删除", task: id(1), status: .running, started: 6,
                                         step: homeworkPlan.items[1].id)],
            taskColorIndex: 0)
        let website = AnchorSession(id: id(2), goal: AnchorGoal(
            title: "个人网站", completionCriteria: "作品集页面上线",
            userPlan: AnchorUserPlan(steps: ["整理项目清单", "做项目页", "部署上线"], completedSteps: [0], reviewedAt: at(90))),
            startedAt: at(300), processes: [codex("项目页", task: id(2), status: .completed, started: 30, ended: 9,
                                         reply: "项目页已完成，三个项目卡片和详情页都能打开。")],
            taskColorIndex: 1)
        let notes = AnchorSession(id: id(3), goal: AnchorGoal(
            title: "研究笔记", completionCriteria: "整理好推荐系统论文",
            userPlan: AnchorUserPlan(steps: ["读第 3 篇论文", "整理笔记"])),
            startedAt: at(60), taskColorIndex: 3)
        for task in [website, notes, homework] { try await repository.send(.hostSession(task)) }
        try await repository.send(.selectSession(homework.id))

        let projection = await LocalSessionRepository(storageURL: storage, sourceID: UUID()).currentProjection()
        let current = try #require(projection.hostedSessions.first { $0.id == homework.id })
        #expect(TaskMeanwhile(current: current, among: projection.hostedSessions)
            == .other(task: website.id, title: "个人网站", action: .review(process: "项目页")))
        if case .waiting = DeskHold(current: current, among: projection.hostedSessions) {} else {
            Issue.record("expected the desk to hold while the agent works")
        }
        if let export = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"].map({ URL(fileURLWithPath: $0) }) {
            let output = export.appending(path: "desk-wait")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: storage).write(to: output.appending(path: "session-repository.json"))
        }
    }

    @Test("The task library stacks each task's newest conversations with the latest in front")
    func taskLibrary() async throws {
        let directory = URL.temporaryDirectory.appending(path: "anchor-task-library-preview-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appending(path: "session-repository.json")
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let now = Date.now

        func at(_ minutesAgo: Double) -> Date { now.addingTimeInterval(-minutesAgo * 60) }
        func id(_ index: Int) -> UUID { UUID(uuidString: String(format: "1B7A0000-7215-40E0-8B0B-%012d", index))! }
        func conversation(_ index: Int, _ title: String, task: UUID, status: ProcessStatus, started: Double,
                          ended: Double? = nil, request: String, reply: String = "") -> AnchorProcess {
            let processID = id(index), sourceID = UUID()
            var events = [ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID,
                                       occurredAt: at(started), kind: .created, title: "Codex task_started", metric: nil)]
            if let ended {
                events.append(ProcessEvent(sessionID: task, processID: processID, sourceID: sourceID, occurredAt: at(ended),
                                           kind: status == .failed ? .failed : .completed,
                                           title: status == .failed ? "Codex task_failed" : "Codex task_complete",
                                           metric: nil))
            }
            return AnchorProcess(id: processID, sessionID: task, sourceID: sourceID, sourceName: "Claude Code",
                                 sourceSymbol: "C", sourceTone: "cyan", title: title, status: status, detail: reply,
                                 updatedAt: events.map(\.occurredAt).max() ?? now, events: events, request: request)
        }

        let desk = AnchorSession(id: id(1), goal: AnchorGoal(title: "横屏工作台", completionCriteria: "按设计稿完成"),
            startedAt: at(180), processes: [
                conversation(11, "iOS app UI polish", task: id(1), status: .completed, started: 150, ended: 120,
                             request: "把竖屏首页的卡片间距再收一点，标题和头像对齐。",
                             reply: "已调整：卡片间距从 16 改为 12，标题与头像基线对齐，深色模式也检查过。"),
                conversation(12, "任务进程库", task: id(1), status: .completed, started: 40, ended: 8,
                             request: "按设计稿重做横屏工作页：左边大时钟，右边三列任务，每列最多三段对话叠成卡片。",
                             reply: "已完成：左侧换成加宽粗体时钟，右侧按任务分三列，每列最多三张对话卡，点上面的卡会滑到最前面。"),
                conversation(13, "卡片切换动效", task: id(1), status: .running, started: 5,
                             request: "卡片切换时加一点简单的物理光影反馈。"),
            ], taskColorIndex: 0)
        let homework = AnchorSession(id: id(2), goal: AnchorGoal(title: "数据结构作业", completionCriteria: "红黑树通过测试"),
            startedAt: at(240), processes: [
                conversation(21, "红黑树删除", task: id(2), status: .completed, started: 70, ended: 52,
                             request: "帮我实现红黑树的删除，包括 fixup，写完跑一下测试。",
                             reply: "已实现 delete 和 fixup，所有测试通过。另外补了一个回归测试，覆盖删除根节点的情况。"),
                conversation(22, "实验报告", task: id(2), status: .needsDecision, started: 30, ended: 14,
                             request: "根据测试结果写实验报告的第三节。",
                             reply: "第三节写到复杂度分析时需要你确认：报告里用平均情况还是最坏情况？"),
            ], taskColorIndex: 1)
        let voice = AnchorSession(id: id(3), goal: AnchorGoal(title: "语音陪练", completionCriteria: "语音自然"),
            startedAt: at(300), processes: [
                conversation(31, "唤醒词误触", task: id(3), status: .failed, started: 90, ended: 75,
                             request: "排查安静环境下的误唤醒。",
                             reply: "测试失败：安静环境下 20 次里仍有 2 次误唤醒。"),
                conversation(32, "节奏提示音", task: id(3), status: .completed, started: 60, ended: 44,
                             request: "每组动作之间加一个轻的提示音。",
                             reply: "加好了，提示音在每组结束前 3 秒响起，音量跟随系统。"),
                conversation(33, "语音更柔和", task: id(3), status: .completed, started: 25, ended: 3,
                             request: "另外还有一个不是P0关键，但是可以探索的点就是这个语音是不是比较机械，就是能不能让它更加柔和一点的一些语音呢……",
                             reply: "可以。我已经做了3条“柔和、自然女声”的试听稿，换用了本机的神经网络女声，放慢一点语速，并调整了措辞和停顿。1.保持不动 “很好，就这样，保持不动。”"),
            ], taskColorIndex: 2)
        for task in [desk, homework, voice] { try await repository.send(.hostSession(task)) }

        let projection = TaskDashboardPolicy.presentation(
            of: await LocalSessionRepository(storageURL: storage, sourceID: UUID()).currentProjection())
        let fronts = projection.hostedSessions.map { TaskConversationStack(task: $0).front?.title }
        // A failed or waiting conversation (the old red light) is in front; otherwise the newest.
        #expect(Set(fronts) == ["卡片切换动效", "实验报告", "唤醒词误触"])
        #expect(projection.hostedSessions.flatMap(\.processes).allSatisfy { $0.request != nil })
        if let export = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"].map({ URL(fileURLWithPath: $0) }) {
            let output = export.appending(path: "task-library")
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: storage).write(to: output.appending(path: "session-repository.json"))
        }
    }
}
