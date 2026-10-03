import Foundation
import Testing
@testable import AnchorCore

@Suite("Dashboard readability data")
struct DashboardReadabilityJourneyTests {
    @Test("Unknown, zero and measured main progress survive reordering and reload")
    func progressStatesRemainDistinct() async throws {
        let directory = URL.temporaryDirectory.appending(path: "anchor-readability-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = directory.appending(path: "session-repository.json")
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let values: [Double?] = [nil, 0, 0.63, 1]
        let titles = ["等待主会话上报进度", "任务刚刚开始", "核对任务同步", "验证已经完成"]
        for index in values.indices {
            let id = UUID(uuidString: String(format: "CA720001-7215-40E0-8B0B-%012d", index + 1))!
            let main = AnchorProcess(sessionID: id, sourceID: UUID(), sourceName: "Codex",
                sourceSymbol: "C", sourceTone: "cyan", title: "Main conversation",
                status: index == 3 ? .completed : .running, progress: values[index])
            let secondary = AnchorProcess(sessionID: id, sourceID: UUID(), sourceName: "Terminal",
                sourceSymbol: ">_", sourceTone: "cyan", title: "Secondary conversation",
                status: index == 3 ? .completed : .running, progress: 0.98)
            let task = AnchorSession(id: id,
                goal: AnchorGoal(title: titles[index], completionCriteria: "状态和百分比可以读懂"),
                startedAt: Date.now.addingTimeInterval(Double(index - 60)),
                processes: [main, secondary], taskColorIndex: index)
            try await repository.send(.hostSession(task))
            try await repository.send(.forSession(id, .reorderProcesses([secondary.id, main.id])))
        }
        let restored = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        let tasks = await restored.currentProjection().hostedSessions
        #expect(tasks.count == 4)
        #expect(tasks.map { $0.conversationsInJoiningOrder.first?.progress } == values)
        #expect(tasks.allSatisfy { $0.processes.first?.title == "Secondary conversation" })
        // Used only by the isolated UI validation runner; shipping targets never read this variable.
        if let destination = ProcessInfo.processInfo.environment["ANCHOR_READABILITY_REVIEW_EXPORT"] {
            let output = URL(fileURLWithPath: destination)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try Data(contentsOf: storage).write(to: output.appending(path: "session-repository.json"))
        }
    }
}
