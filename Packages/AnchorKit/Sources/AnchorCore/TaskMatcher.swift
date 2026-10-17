import Foundation
import NaturalLanguage

/// Places one piece of agent work (a conversation) on the task, and when it is
/// clear the step, that it serves. Evidence, strongest first:
/// 1. the person's own corrections, remembered;
/// 2. the folder a single task already works in;
/// 3. the words of the request against each task's title, criteria and steps;
/// 4. the task the person is on, for work that started while they were on it.
/// Anything else waits, unsorted, for one click. Request text is read here
/// transiently and is never stored.
public enum TaskMatcher {
    public struct Work: Sendable, Hashable {
        public let id: String
        /// The folder name the work runs in, never its full path.
        public let folder: String?
        public let request: String
        public let startedAt: Date?
        public let lastActivityAt: Date

        public init(id: String, folder: String?, request: String, startedAt: Date?, lastActivityAt: Date) {
            self.id = id
            self.folder = folder
            self.request = request
            self.startedAt = startedAt
            self.lastActivityAt = lastActivityAt
        }
    }

    /// What the person taught Anchor. Persisted on the Mac only.
    public struct Memory: Codable, Hashable, Sendable {
        public var corrections: [String: UUID] = [:]
        public var ignored: Set<String> = []
        /// Folder name to the tasks that worked there, most recent last.
        public var folders: [String: [UUID]] = [:]

        public init() {}

        public mutating func learn(folder: String?, task: UUID) {
            guard let folder, !folder.isEmpty else { return }
            var tasks = folders[folder, default: []].filter { $0 != task }
            tasks.append(task)
            folders[folder] = Array(tasks.suffix(5))
        }

        public mutating func correct(_ work: Work, to task: UUID) {
            corrections[work.id] = task
            ignored.remove(work.id)
            learn(folder: work.folder, task: task)
        }

        public mutating func ignore(_ work: Work) {
            ignored.insert(work.id)
            corrections[work.id] = nil
        }
    }

    public enum Reason: String, Sendable, Hashable {
        case corrected, folder, words, current
    }

    public enum Placement: Hashable, Sendable {
        case task(UUID, step: UUID?, reason: Reason)
        case unsorted(candidates: [UUID])
        case ignored
    }

    /// Words must clearly favor one task: at least this much evidence...
    static let wordThreshold = 2.0
    /// ...and at least this many times the next task's.
    static let wordMargin = 2.0

    public static func place(
        _ work: Work,
        tasks: [AnchorSession],
        current: (id: UUID, since: Date)?,
        memory: Memory
    ) -> Placement {
        if memory.ignored.contains(work.id) { return .ignored }
        // A task cannot own work that went quiet before the task existed.
        let open = tasks.filter { $0.status == .active && $0.startedAt <= work.lastActivityAt }
        guard !open.isEmpty else { return .unsorted(candidates: []) }
        let index = WordIndex(tasks: open)
        let requestWords = words(work.request)

        if let corrected = memory.corrections[work.id], let task = open.first(where: { $0.id == corrected }) {
            return .task(task.id, step: index.bestStep(in: task, for: requestWords), reason: .corrected)
        }
        if let folder = work.folder, let known = memory.folders[folder] {
            let owners = open.filter { known.contains($0.id) }
            if owners.count == 1, let owner = owners.first {
                return .task(owner.id, step: index.bestStep(in: owner, for: requestWords), reason: .folder)
            }
        }

        var ranked: [(task: AnchorSession, score: Double)] = open.map { task in
            (task: task, score: index.score(of: task, for: requestWords))
        }
        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.task.id.uuidString < rhs.task.id.uuidString
        }
        let runnerUp: Double = ranked.count > 1 ? ranked[1].score : 0
        if let best = ranked.first, best.score >= wordThreshold, best.score >= runnerUp * wordMargin {
            return .task(best.task.id, step: index.bestStep(in: best.task, for: requestWords), reason: .words)
        }
        if let current, let task = open.first(where: { $0.id == current.id }),
           let started = work.startedAt, started >= current.since,
           !ranked.contains(where: { $0.task.id != task.id && $0.score >= wordThreshold }) {
            return .task(task.id, step: index.bestStep(in: task, for: requestWords), reason: .current)
        }
        return .unsorted(candidates: ranked.filter { $0.score > 0 }.map { $0.task.id })
    }

    // MARK: Words

    /// Content words of a text. Apple's segmenter finds common words; runs of
    /// single characters it could not join (红|黑|树) become one term, because the
    /// same rule applies to the task and the request.
    public static func words(_ text: String) -> Set<String> {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if let language = NLLanguageRecognizer.dominantLanguage(for: text) { tokenizer.setLanguage(language) }
        var result = Set<String>()
        var run = ""
        func flush() {
            if run.count >= 2, !stopWords.contains(run) { result.insert(run) }
            run = ""
        }
        for range in tokenizer.tokens(for: text.startIndex..<text.endIndex) {
            let token = text[range].lowercased()
            let isHan = token.unicodeScalars.allSatisfy { (0x3400...0x9FFF).contains(Int($0.value)) }
            if isHan && token.count == 1 && !joiners.contains(token) {
                run += token
                continue
            }
            flush()
            if isHan {
                if token.count >= 2, !stopWords.contains(token) { result.insert(token) }
            } else if token.count >= 3, token.contains(where: \.isLetter), !stopWords.contains(token) {
                result.insert(token)
            }
        }
        flush()
        return result
    }

    /// Function characters that never belong to a term and break a run.
    private static let joiners: Set<String> = [
        "的", "了", "和", "与", "及", "是", "在", "都", "把", "被", "让", "给", "吗", "呢", "吧",
        "也", "就", "还", "又", "很", "请", "我", "你", "他", "她", "它", "做", "要", "再", "先",
    ]

    private static let stopWords: Set<String> = [
        "帮我", "一下", "一个", "这个", "那个", "然后", "我们", "你们", "可以", "需要", "进行", "现在",
        "问题", "看看", "继续", "一些", "什么", "怎么", "如何", "为什么", "还是", "已经", "所有", "如果",
        "the", "and", "for", "with", "this", "that", "these", "those", "please", "can", "could", "you",
        "your", "help", "into", "from", "have", "has", "what", "when", "then", "also", "just", "need",
        "want", "use", "using", "make", "let", "lets", "now", "again", "continue", "thanks", "thank",
        "should", "would", "will", "are", "was", "were", "been", "being", "its", "our", "out", "about",
    ]

    /// Words weighted by how few open tasks share them, so a word every task uses decides nothing.
    struct WordIndex {
        private let taskWords: [UUID: Set<String>]
        private let stepWords: [UUID: [(id: UUID, words: Set<String>)]]
        private let taskCount: [String: Int]

        init(tasks: [AnchorSession]) {
            var taskWords: [UUID: Set<String>] = [:]
            var stepWords: [UUID: [(id: UUID, words: Set<String>)]] = [:]
            var counts: [String: Int] = [:]
            for task in tasks {
                let steps = (task.goal.userPlan?.items ?? []).map { (id: $0.id, words: TaskMatcher.words($0.text)) }
                let all = TaskMatcher.words(task.goal.title)
                    .union(TaskMatcher.words(task.goal.completionCriteria))
                    .union(steps.flatMap(\.words))
                taskWords[task.id] = all
                stepWords[task.id] = steps
                for word in all { counts[word, default: 0] += 1 }
            }
            self.taskWords = taskWords
            self.stepWords = stepWords
            taskCount = counts
        }

        private func weight(_ word: String) -> Double {
            1 / Double(max(1, taskCount[word] ?? 1))
        }

        func score(of task: AnchorSession, for request: Set<String>) -> Double {
            request.intersection(taskWords[task.id] ?? []).reduce(0) { $0 + weight($1) }
        }

        /// The one step the request is clearly about, if any. Words several steps
        /// share count less, so "implement" alone never picks a step.
        func bestStep(in task: AnchorSession, for request: Set<String>) -> UUID? {
            let steps = stepWords[task.id] ?? []
            var withinTask: [String: Int] = [:]
            for step in steps { for word in step.words { withinTask[word, default: 0] += 1 } }
            let scored = steps.map { step in
                (step.id, request.intersection(step.words).reduce(0.0) {
                    $0 + weight($1) / Double(max(1, withinTask[$1] ?? 1))
                })
            }.sorted { $0.1 > $1.1 }
            guard let best = scored.first, best.1 >= 1 else { return nil }
            if let second = scored.dropFirst().first, second.1 >= best.1 { return nil }
            return best.0
        }
    }
}
