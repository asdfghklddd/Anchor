import AnchorCore
import AnchorDesign
import AppKit
import Foundation
import SwiftUI
import Testing
@testable import AnchorMacFeatures

/// Renders the Mac glance and edge buoy with disposable data. Images are written
/// only when a preview runner sets ANCHOR_DESIGN_PREVIEW_EXPORT.
@MainActor
@Suite("Mac design preview")
struct MacDesignPreviewTests {
    private static func tasks(now: Date) -> [AnchorSession] {
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        func process(_ title: String, source: String = "Codex", sourceID: UUID = UUID(), status: ProcessStatus,
                     _ events: [(ProcessEventKind, Double, String, String?)]) -> AnchorProcess {
            let mapped = events.map { ProcessEvent(sourceID: sourceID, occurredAt: at($0.1), kind: $0.0, title: $0.2, metric: $0.3) }
            return AnchorProcess(sourceID: sourceID, sourceName: source, sourceSymbol: "C", sourceTone: "cyan",
                                 title: title, status: status, updatedAt: mapped.map(\.occurredAt).max() ?? now,
                                 events: mapped)
        }
        return [
            AnchorSession(goal: AnchorGoal(title: "重构同步协议", completionCriteria: ""), startedAt: at(72), processes: [
                process("sync-protocol", status: .running, [
                    (.created, 66, "Codex task_started", nil), (.completed, 41, "Codex task_complete", nil),
                    (.created, 24, "Codex task_started", nil)
                ])
            ], taskColorIndex: 0),
            AnchorSession(goal: AnchorGoal(title: "修复登录崩溃", completionCriteria: ""), startedAt: at(52), processes: [
                process("login-crash", status: .failed, [(.created, 48, "Codex task_started", nil), (.failed, 11, "Codex task_failed", nil)])
            ], taskColorIndex: 1),
            AnchorSession(goal: AnchorGoal(title: "撰写发布说明", completionCriteria: ""), startedAt: at(34), processes: [
                process("release-notes", status: .completed, [(.created, 30, "Codex task_started", nil), (.completed, 6, "Codex task_complete", nil)])
            ], taskColorIndex: 2),
            AnchorSession(goal: AnchorGoal(title: "数据迁移脚本", completionCriteria: ""), startedAt: at(21), processes: [
                process("python migrate.py", source: "终端", sourceID: BuiltInProcessSourceID.file, status: .failed,
                        [(.created, 18, "python started", nil), (.failed, 3, "python interrupted", "130")])
            ], taskColorIndex: 3)
        ]
    }

    /// One fixed throwaway domain, removed after rendering, so runs leave no preference files.
    private static let previewDefaultsName = "anchor.design-preview"
    private static let previewDefaults = UserDefaults(suiteName: previewDefaultsName)!

    @Test("The glance and buoy render in both appearances")
    func renderPreviews() throws {
        let tasks = Self.tasks(now: .now)
        #expect(EdgeBuoySignal.unseen(in: tasks, since: .now.addingTimeInterval(-3_600)) == .failed)

        for scheme in [ColorScheme.light, .dark] {
            let page = MacGlanceCard(tasks: tasks, connection: .connected, selectedTaskID: tasks[0].id, onSelectTask: { _ in })
                .padding(24)
                .frame(width: 900)
                .background(AnchorPalette.canvas)
                .environment(\.colorScheme, scheme)
                .environment(\.locale, AnchorStrings.interfaceLocale)
            try export(page, name: "mac-glance-\(scheme == .dark ? "dark" : "light")")
        }

        let row = HStack(spacing: 24) {
            ForEach([EdgeBuoySignal.failed, .attention, .finished], id: \.self) { signal in
                let model = AnchorEdgePresentationModel(defaults: Self.previewDefaults)
                let _ = model.showBuoy(signal)
                AnchorEdgeControlView(presentation: model, onOpenDetails: {})
            }
        }
        .padding(20)
        .background(Color(red: 0.30, green: 0.42, blue: 0.40))
        try export(row, name: "mac-edge-buoys")
        Self.previewDefaults.removePersistentDomain(forName: Self.previewDefaultsName)
    }

    @Test("The Codex conversations card renders in both appearances")
    func renderCodexConversations() throws {
        let now = Date.now
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let conversations = [
            codexConversation("sync", .running(since: at(6)), modified: at(0.3), title: "重构同步协议"),
            codexConversation("tests", .running(since: at(41)), modified: at(14), title: "跑完整测试并修复失败项"),
            codexConversation("login", .completed(at: at(3), duration: 420), modified: at(3), title: "修复登录崩溃",
                              reply: "已修复 LoginView 在启动时的崩溃，所有测试通过。另外补了一个回归测试，覆盖未登录状态。"),
            codexConversation("notes", .failed(at: at(25), message: "Context window exceeded"), modified: at(25),
                              title: "整理发布说明", workspace: "Docs"),
            codexConversation("migrate", .interrupted(at: at(70)), modified: at(70), title: "数据迁移脚本", workspace: "Tools"),
            codexConversation("buoy", .completed(at: at(130), duration: 3_120), modified: at(130), title: "Mac 边缘浮标的清除时机",
                              reply: String(repeating: "浮标在打开 Anchor 或激活应用时清除，同一信号不会重复提示；更强的新信号会让收起的小船回来一次。", count: 3)),
            codexConversation("older", .completed(at: at(300), duration: 50), modified: at(300), title: "更早的对话"),
        ]
        for scheme in [ColorScheme.light, .dark] {
            let page = MacCodexConversationsCard(conversations: conversations)
                .padding(24)
                .frame(width: 900)
                .background(AnchorPalette.canvas)
                .environment(\.colorScheme, scheme)
                .environment(\.locale, AnchorStrings.interfaceLocale)
            try export(page, name: "mac-codex-conversations-\(scheme == .dark ? "dark" : "light")")
        }
        try export(
            MacCodexConversationsCard(conversations: [])
                .padding(24).frame(width: 900).background(AnchorPalette.canvas)
                .environment(\.locale, AnchorStrings.interfaceLocale),
            name: "mac-codex-conversations-empty"
        )
    }

    @Test("Task cards and the unsorted list render in both appearances")
    func renderTaskCards() throws {
        let now = Date.now
        func at(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        func run(_ title: String, _ status: ProcessStatus, started: Double, ended: Double?) -> AnchorProcess {
            let sourceID = UUID()
            var events = [ProcessEvent(sourceID: sourceID, occurredAt: at(started), kind: .created, title: "Codex task_started")]
            if let ended {
                events.append(ProcessEvent(sourceID: sourceID, occurredAt: at(ended), kind: .completed, title: "Codex task_complete"))
            }
            return AnchorProcess(sourceID: sourceID, sourceName: "Codex", sourceSymbol: "C", sourceTone: "cyan",
                                 title: title, status: status, updatedAt: at(ended ?? started), events: events)
        }
        let homeworkPlan = try #require(AnchorUserPlan(steps: ["实现插入", "实现删除操作", "补边界情况测试", "写实验报告"])
            .marking(step: 0, done: true, at: at(45)))
        let homework = AnchorSession(goal: AnchorGoal(title: "数据结构作业", completionCriteria: "红黑树的插入和删除都通过测试",
                                                      userPlan: homeworkPlan),
                                     status: .active, startedAt: at(120),
                                     processes: [run("红黑树删除", .completed, started: 30, ended: 4)], taskColorIndex: 0)
        let websitePlan = try #require(AnchorUserPlan(steps: ["整理项目清单", "做项目页", "部署上线"])
            .marking(step: 0, done: true, at: at(90)))
        let website = AnchorSession(goal: AnchorGoal(title: "个人网站", completionCriteria: "作品集上线", userPlan: websitePlan),
                                    status: .active, startedAt: at(300), taskColorIndex: 1)
        let deletion = codexConversation("rb-delete", .completed(at: at(4), duration: 1_560), modified: at(4),
                                         title: "红黑树删除", workspace: "homework",
                                         reply: "已实现 delete 和 fixup，所有测试通过。另外补了一个回归测试，覆盖删除根节点的情况。")
        let notes = codexConversation("notes", .completed(at: at(20), duration: 95), modified: at(20),
                                      title: "整理笔记格式", workspace: "notes", reply: "已把 12 篇笔记统一成同一种标题格式。")
        let actions = MacTaskActions(setStep: { _, _, _ in }, markReviewed: { _ in }, open: { _ in },
                                     assign: { _, _ in }, ignore: { _ in })
        for scheme in [ColorScheme.light, .dark] {
            let page = VStack(alignment: .leading, spacing: MacMetrics.pageSpacing) {
                MacTaskCard(task: homework, conversations: [deletion],
                            steps: ["rb-delete": homeworkPlan.items[1].id], otherTasks: [website],
                            now: now, actions: actions)
                MacTaskCard(task: website, conversations: [], steps: [:], otherTasks: [homework],
                            now: now, actions: actions)
                MacUnsortedCard(conversations: [notes], candidates: [:], tasks: [homework, website],
                                now: now, actions: actions)
            }
            .padding(24)
            .frame(width: 900)
            .background(AnchorPalette.canvas)
            .environment(\.colorScheme, scheme)
            .environment(\.locale, AnchorStrings.interfaceLocale)
            try export(page, name: "mac-task-cards-\(scheme == .dark ? "dark" : "light")")
        }
    }

    private func export<Content: View>(_ view: Content, name: String) throws {
        guard let destination = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"] else { return }
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            Issue.record("Could not render \(name)")
            return
        }
        let folder = URL(fileURLWithPath: destination)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try png.write(to: folder.appending(path: name + ".png"))
    }
}
