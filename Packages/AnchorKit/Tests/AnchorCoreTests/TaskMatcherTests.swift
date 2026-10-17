import Foundation
import Testing
@testable import AnchorCore

@Suite("Task matcher")
struct TaskMatcherTests {
    private let now = Date(timeIntervalSince1970: 1_792_137_600)
    private func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }

    private func task(_ title: String, criteria: String = "", steps: [String], started: Double = 120) -> AnchorSession {
        AnchorSession(goal: AnchorGoal(title: title, completionCriteria: criteria, userPlan: AnchorUserPlan(steps: steps)),
                      status: .active, startedAt: ago(started))
    }

    private func work(_ request: String, id: String = "w", folder: String? = nil, started: Double = 5) -> TaskMatcher.Work {
        TaskMatcher.Work(id: id, folder: folder, request: request, startedAt: ago(started), lastActivityAt: ago(1))
    }

    private let homework: AnchorSession
    private let website: AnchorSession

    init() {
        homework = AnchorSession(goal: AnchorGoal(
            title: "数据结构作业", completionCriteria: "红黑树的插入和删除都通过测试",
            userPlan: AnchorUserPlan(steps: ["实现插入", "实现删除操作", "补边界情况测试", "写实验报告"])),
            status: .active, startedAt: Date(timeIntervalSince1970: 1_792_137_600 - 7_200))
        website = AnchorSession(goal: AnchorGoal(
            title: "个人网站", completionCriteria: "作品集上线",
            userPlan: AnchorUserPlan(steps: ["整理项目清单", "做项目页", "部署上线"])),
            status: .active, startedAt: Date(timeIntervalSince1970: 1_792_137_600 - 7_200))
    }

    @Test("Chinese requests keep their content words, including rare terms the segmenter splits")
    func contentWords() {
        let words = TaskMatcher.words("帮我实现红黑树的删除操作")
        #expect(words.isSuperset(of: ["实现", "红黑树", "删除", "操作"]))
        #expect(!words.contains("帮我"))
        #expect(!words.contains("的"))
        #expect(TaskMatcher.words("Fix the build error in LoginView.swift please") == ["fix", "build", "error", "loginview", "swift"])
        #expect(TaskMatcher.words("继续").isEmpty)
    }

    @Test("A request about a step lands on its task and that step, not on the title")
    func matchesThroughSteps() {
        let tasks = [homework, website]
        let placement = TaskMatcher.place(work("帮我实现红黑树的删除操作"), tasks: tasks, current: nil, memory: .init())
        #expect(placement == .task(homework.id, step: homework.goal.userPlan!.items[1].id, reason: .words))

        let deploy = TaskMatcher.place(work("把作品集部署上线"), tasks: tasks, current: nil, memory: .init())
        #expect(deploy == .task(website.id, step: website.goal.userPlan!.items[2].id, reason: .words))
    }

    @Test("Unclear words wait unsorted instead of guessing")
    func unclearWaits() {
        let tasks = [homework, website]
        #expect(TaskMatcher.place(work("继续"), tasks: tasks, current: nil, memory: .init()) == .unsorted(candidates: []))
        // One shared word is not enough evidence on its own.
        if case let .unsorted(candidates) = TaskMatcher.place(work("看看测试"), tasks: tasks, current: nil, memory: .init()) {
            #expect(candidates == [homework.id])
        } else {
            Issue.record("Expected unsorted")
        }
    }

    @Test("New work started while on a task joins it, unless the words clearly name another")
    func currentTask() {
        let tasks = [homework, website]
        let current = (id: website.id, since: ago(10))
        #expect(TaskMatcher.place(work("继续", started: 5), tasks: tasks, current: current, memory: .init())
                == .task(website.id, step: nil, reason: .current))
        // Older work is not claimed just because a task is selected now.
        #expect(TaskMatcher.place(work("继续", started: 30), tasks: tasks, current: current, memory: .init())
                == .unsorted(candidates: []))
        // Clear words for another task win over the selection.
        if case .task(let id, _, .words) = TaskMatcher.place(work("帮我实现红黑树的删除操作", started: 5), tasks: tasks,
                                                            current: current, memory: .init()) {
            #expect(id == homework.id)
        } else {
            Issue.record("Expected a word match")
        }
    }

    @Test("Corrections, ignored work and folder memory come before words")
    func memoryFirst() {
        let tasks = [homework, website]
        let request = work("帮我实现红黑树的删除操作", folder: "portfolio")
        var memory = TaskMatcher.Memory()
        memory.correct(request, to: website.id)
        #expect(TaskMatcher.place(request, tasks: tasks, current: nil, memory: memory) == .task(website.id, step: nil, reason: .corrected))

        var folders = TaskMatcher.Memory()
        folders.learn(folder: "portfolio", task: website.id)
        let other = work("fix the build", id: "w2", folder: "portfolio")
        #expect(TaskMatcher.place(other, tasks: tasks, current: nil, memory: folders) == .task(website.id, step: nil, reason: .folder))
        // A folder shared by two tasks decides nothing.
        folders.learn(folder: "portfolio", task: homework.id)
        #expect(TaskMatcher.place(other, tasks: tasks, current: nil, memory: folders) == .unsorted(candidates: []))

        memory.ignore(request)
        #expect(TaskMatcher.place(request, tasks: tasks, current: nil, memory: memory) == .ignored)
    }

    @Test("A task never owns work that went quiet before it existed")
    func respectsTaskStart() {
        let fresh = task("个人网站", steps: ["部署上线"], started: 0.5)
        let old = TaskMatcher.Work(id: "old", folder: nil, request: "部署上线 作品集", startedAt: ago(90), lastActivityAt: ago(60))
        #expect(TaskMatcher.place(old, tasks: [fresh], current: nil, memory: .init()) == .unsorted(candidates: []))
    }
}
