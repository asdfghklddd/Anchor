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
}
