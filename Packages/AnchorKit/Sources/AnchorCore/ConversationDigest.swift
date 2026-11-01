import Foundation
import NaturalLanguage

/// What a person needs to pick a conversation back up, read from its log on
/// the Mac without a model: what it is waiting for, how far it got, the last
/// few things it did, a decision the person made, and words and files to
/// recognise. The Mac writes it when a turn starts or ends; it travels to the
/// phone with the conversation's latest turn, like the request and the reply
/// openings, over the local link only.
public struct ConversationDigest: Codable, Hashable, Sendable {
    /// A fixed fact about where the work stands, worded by the phone.
    public enum Fact: Codable, Hashable, Sendable {
        case committed(String?)
        case pushed
        case notPushed
        case testsPassed
        case testsMostlyPassed
        case testsFailed
        case testsRan
        case unverified
        case interrupted
        case stoppedByError
        case filesChanged(Int)
    }

    /// Something the agent's last reply left for the person.
    public struct Waiting: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Hashable, Sendable {
            /// It asked the person a question.
            case answer
            /// It asked the person to do something, like trying the app.
            case act
        }

        public var kind: Kind
        public var text: String

        public init(kind: Kind, text: String) {
            self.kind = kind
            self.text = text
        }
    }

    /// The opening of each of the last few replies, oldest first; the last is where it stands now.
    public var path: [String]
    public var waiting: Waiting?
    public var facts: [Fact]
    /// The latest choice the person stated, in their words.
    public var decision: String?
    /// The person's own recurring words in the conversation.
    public var keywords: [String]
    /// Files the work touched or delivered, by name.
    public var cues: [String]
    /// The gist of the person's latest request that said more than "continue".
    public var latestRequest: String?

    public init(path: [String] = [], waiting: Waiting? = nil, facts: [Fact] = [], decision: String? = nil,
                keywords: [String] = [], cues: [String] = [], latestRequest: String? = nil) {
        self.path = path
        self.waiting = waiting
        self.facts = facts
        self.decision = decision
        self.keywords = keywords
        self.cues = cues
        self.latestRequest = latestRequest
    }

    public var isEmpty: Bool { path.isEmpty && waiting == nil && facts.isEmpty && decision == nil && latestRequest == nil }

    /// The digest of the log at `url`; `nil` when it holds no request yet.
    /// `follower` carries the reading state from the last call, so a log read
    /// at every turn is read past its tail only once.
    public static func read(at url: URL, title: String?, follower: inout ConversationTranscript.Follower?) -> ConversationDigest? {
        guard let transcript = ConversationTranscript.follow(url, with: &follower) else { return nil }
        let digest = ConversationDigest(transcript, title: title)
        return digest.isEmpty ? nil : digest
    }

    public init(_ transcript: ConversationTranscript, title: String?) {
        let rounds = transcript.rounds
        let span = Self.sinceLastAsk(rounds)
        let latestReply = rounds.last?.reply
        path = rounds.suffix(3).compactMap { $0.reply.flatMap(DigestText.headline) }
            .map { DigestText.cut($0, 22) }.filter { !$0.isEmpty && $0 != "…" }
        waiting = latestReply.flatMap(Self.waiting)
        facts = Self.facts(span: span, latest: rounds.last, reply: latestReply)
        decision = Self.decision(in: rounds)
        keywords = DigestKeywords.pick(from: rounds.map(\.request), excluding: title)
        var cues: [String] = []
        for round in span {
            for file in round.files {
                let name = (file as NSString).lastPathComponent
                if !cues.contains(name) { cues.append(name) }
            }
        }
        for match in DigestText.clean(latestReply ?? "").matches(of: Self.deliverable) where cues.count < 3 {
            let name = String(match.0)
            if !cues.contains(name) { cues.append(name) }
        }
        self.cues = Array(cues.prefix(3))
        latestRequest = rounds.last(where: { DigestText.isSubstantive($0.request) })
            .map { DigestText.requestGist($0.request, budget: 30) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    // MARK: Reading the rounds

    /// Rounds since the latest request that said more than "commit" or "continue":
    /// those short follow-ups belong to the request before them.
    static func sinceLastAsk(_ rounds: [ConversationTranscript.Round]) -> ArraySlice<ConversationTranscript.Round> {
        var start = rounds.count - 1
        while start > 0, !DigestText.isSubstantive(rounds[start].request) { start -= 1 }
        return rounds[max(0, start)...]
    }

    nonisolated(unsafe) private static let deliverable = /[\w\p{Han}\-.]+\.(?:pdf|zip|key|docx|xlsx|pptx|png|jpg|mp4|mov|html|dmg|ipa)\b/
        .ignoresCase()
    /// A short commit hash: hex with a digit and a letter, or exactly seven digits (dates have eight).
    nonisolated(unsafe) private static let commitHash = /\b(?:(?=[0-9a-f]*\d)(?=[0-9a-f]*[a-f])[0-9a-f]{7,10}|\d{7})\b/
    nonisolated(unsafe) private static let commitCommand = /\bgit (?:-C \S+ )?commit\b/
    nonisolated(unsafe) private static let pushCommand = /\bgit (?:-C \S+ )?push\b/
    nonisolated(unsafe) private static let testCommand = /xcodebuild[^\n|]*\b(?:test|build)\b|swift (?:test|build)|pytest|npm (?:run )?(?:test|build)|vitest|jest|cargo test|go test/
    nonisolated(unsafe) private static let notPushed = /not pushed|isn't pushed|hasn't been pushed|nothing is pushed|未推送|没有推送|还没推送|没推送|没有推/
        .ignoresCase()
    nonisolated(unsafe) private static let pushed = /\bpushed\b|已推送|推送到|推上去了/.ignoresCase()
    nonisolated(unsafe) private static let failed = /fail(?:ed|s|ing)?\b|失败|报错|没通过|\berror/.ignoresCase()
    nonisolated(unsafe) private static let passed = /pass(?:es|ed)?\b|通过|succeed|成功/.ignoresCase()
    nonisolated(unsafe) private static let unverified = /not (?:yet )?(?:verified|tested|tried)|haven't (?:tried|tested|run|verified)|未验证|还没(?:在|有)?(?:真机|设备)?(?:上)?(?:试|测|验证)/
        .ignoresCase()

    static func facts(span: ArraySlice<ConversationTranscript.Round>, latest: ConversationTranscript.Round?,
                      reply: String?) -> [Fact] {
        let commands = span.flatMap(\.commands).joined(separator: "\n")
        let text = DigestText.clean(reply ?? "")
        let clauses = DigestText.clauses(text, keepCommas: true)
        var facts: [Fact] = []
        if latest?.interrupted == true, latest?.reply == nil {
            facts.append(.interrupted)
        } else if text.contains("API Error") || text.contains("Connection lost") {
            facts.append(.stoppedByError)
        }
        let isNotPushed = text.contains(notPushed)
        if commands.contains(commitCommand) {
            facts.append(.committed(text.firstMatch(of: commitHash).map { String($0.0.prefix(7)) }))
            if (commands.contains(pushCommand) || text.contains(pushed)) && !isNotPushed {
                facts.append(.pushed)
            } else if isNotPushed {
                facts.append(.notPushed)
            }
        } else if let said = clauses.first(where: { $0.contains(commitHash) && $0.localizedCaseInsensitiveContains("commit") || $0.contains(commitHash) && $0.contains("提交") }),
                  let match = said.firstMatch(of: commitHash) {
            facts.append(.committed(String(match.0.prefix(7))))
            if isNotPushed { facts.append(.notPushed) } else if text.contains(pushed) { facts.append(.pushed) }
        }
        if commands.contains(testCommand) {
            var verdict = Fact.testsRan
            for clause in clauses where clause.contains(/test|测试|build|构建|编译/.ignoresCase()) {
                if clause.contains(passed), clause.contains(/except|除了|other than/.ignoresCase()) {
                    verdict = .testsMostlyPassed
                } else if clause.contains(failed), !clause.contains(/0 fail|no fail|没有失败|全部通过/.ignoresCase()) {
                    verdict = .testsFailed
                } else if clause.contains(passed) {
                    verdict = .testsPassed
                }
            }
            facts.append(verdict)
        }
        if text.contains(unverified) { facts.append(.unverified) }
        let files = Set(span.flatMap(\.files))
        if !files.isEmpty { facts.append(.filesChanged(files.count)) }
        return Array(facts.prefix(4))
    }

    nonisolated(unsafe) private static let askBack = /要不要|是否|你想|你要|want me to|should i|do you want|would you like|which (?:one|way)/
        .ignoresCase()
    nonisolated(unsafe) private static let doThis = /when you have a moment|you can now|try it|run the|open the|please check|建议先|你可以先|请你|麻烦你|需要你|你来|试一下|打开.*看/
        .ignoresCase()

    /// The last question or request to the person in a reply, past its opening.
    static func waiting(in reply: String) -> Waiting? {
        let lines = DigestText.lines(of: reply)
        let tail = DigestText.clean((lines.count > 1 ? lines.dropFirst() : lines[...]).joined(separator: "\n"))
        guard !tail.isEmpty else { return nil }
        let questions = tail.matches(of: /[^。！!\n?？]*?[?？]/).map { String($0.0).trimmingCharacters(in: .whitespaces) }
            .filter { DigestText.width($0) >= 6 }
        if let question = questions.last {
            let text = question.trimmingCharacters(in: CharacterSet(charactersIn: "?？"))
            return Waiting(kind: .answer, text: DigestText.cut(text, 40) + "？")
        }
        let clauses = DigestText.clauses(tail, keepCommas: true).filter { DigestText.width($0) >= 6 }
        if let ask = clauses.first(where: { $0.contains(askBack) }) { return Waiting(kind: .answer, text: DigestText.cut(ask, 40)) }
        if let act = clauses.first(where: { $0.contains(doThis) }) { return Waiting(kind: .act, text: DigestText.cut(act, 40)) }
        return nil
    }

    nonisolated(unsafe) private static let decided = /采纳|就用|就选|选方案|决定|定了|按方案|用方案|go with|let'?s use|we'?ll use|option [A-Z]\b|方案\s*[A-Za-z一二三四]/
        .ignoresCase()

    /// The newest clause where the person stated a choice.
    static func decision(in rounds: [ConversationTranscript.Round]) -> String? {
        for round in rounds.reversed() {
            let clauses = DigestText.clauses(DigestText.prepared(round.request))
            if let clause = clauses.first(where: { $0.contains(decided) && DigestText.width($0) >= 4 }) {
                return DigestText.cut(DigestText.trimFiller(clause), 28)
            }
        }
        return nil
    }
}

/// Text handling for the digest: cleaning Markdown and paths away, splitting
/// clauses, and measuring in display width (a CJK character counts as one, a
/// Latin letter a little over half).
enum DigestText {
    static func width(_ text: some StringProtocol) -> Double {
        text.unicodeScalars.reduce(0) { $0 + (isWide($1) ? 1 : 0.55) }
    }

    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3000...0x303F, 0x3400...0x9FFF, 0xFF00...0xFFEF: true
        default: false
        }
    }

    /// Shortened to a width budget, preferring a clause boundary near the end.
    static func cut(_ text: String, _ budget: Double) -> String {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " ，,;；:：、"))
        guard width(trimmed) > budget else { return trimmed }
        var out = ""
        var total = 0.0
        var lastBreak: String.Index?
        for character in trimmed {
            let w = width(String(character))
            if total + w > budget { break }
            total += w
            out.append(character)
            if "，,；;、:：".contains(character) || (character == " " && !(out.dropLast().last.map { isWide($0.unicodeScalars.first!) } ?? false)) {
                lastBreak = out.index(before: out.endIndex)
            }
        }
        if let lastBreak, out.distance(from: out.startIndex, to: lastBreak) > Int(Double(out.count) * 0.6) {
            out = String(out[..<lastBreak])
        }
        return out.trimmingCharacters(in: CharacterSet(charactersIn: " ，,;；:：、")) + "…"
    }

    static func clean(_ text: String) -> String {
        var t = text
        t = t.replacing(/```[\s\S]*?```/, with: " ")
        t = t.replacing(/:codex-file-citation\{[^}]*\}/, with: " ")
        t = t.replacing(/<[^>\n]{1,80}>/, with: " ")
        t = t.replacing(/!?\[([^\]]*)\]\([^)]*\)/) { String($0.1) }
        t = t.replacing(/https?:\/\/\S+/, with: " ")
        t = t.replacing(/@"([^"]+)"/) { ($0.1 as Substring).split(separator: "/").last.map(String.init) ?? "" }
        t = t.replacing(/(^|[^\w.])((?:\/[\w.\-\p{Han}]+){2,})\/?/) { match in
            String(match.1) + (String(match.2).split(separator: "/").last.map(String.init) ?? "")
        }
        t = t.replacing("`", with: "").replacing("**", with: "")
        t = t.replacing(/(?m)^\s{0,3}(?:#{1,6}|[-*+]|\d+[.)])\s+/, with: "")
        t = t.replacing(/[ \t]+/, with: " ")
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func lines(of text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func clauses(_ text: String, keepCommas: Bool = false) -> [String] {
        // An English sentence ends at a period after a word; "另外" opens a new point.
        var marked = text.replacing(/([a-z0-9)])\.\s+/) { String($0.1) + "\n" }
        if !keepCommas {
            marked = marked.replacing(/([\s，,])(另外|此外|还有就是|然后呢)/) { String($0.1) + "\n" }
        }
        let pieces = marked.split(separator: /[。！？!?；;\n]+/)
        return pieces.map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " ，,、")) }.filter { !$0.isEmpty }
    }

    /// The opening line of a reply: its bold lead when it has one, past a bare heading.
    static func headline(_ reply: String) -> String? {
        guard !reply.hasPrefix("No response requested"), !reply.hasPrefix("API Error") else { return nil }
        var lines = lines(of: reply)
        while lines.count > 1, width(clean(lines[0]).trimmingCharacters(in: CharacterSet(charactersIn: "#*：: "))) < 6 {
            lines.removeFirst()
        }
        guard let first = lines.first else { return nil }
        if let bold = first.firstMatch(of: /\*\*(.+?)\*\*/), width(bold.1) >= 6 {
            return clean(String(bold.1)).trimmingCharacters(in: CharacterSet(charactersIn: "。."))
        }
        let parts = clauses(clean(first), keepCommas: true)
        guard var lead = parts.first else { return nil }
        if width(lead) < 6, parts.count > 1 { lead = parts[1] }
        let trimmed = lead.trimmingCharacters(in: CharacterSet(charactersIn: "。."))
        return trimmed.isEmpty ? nil : trimmed
    }

    nonisolated(unsafe) private static let greeting = /^(?:(?:good\s+(?:morning|afternoon|evening|night)|hi|hello|hallo|hola|hey|嗨|你好|早上好|晚上好)[\s,，!！~]*(?:my friend\s*)?(?:claude|codex|gpt)?[\s,，!！~.。]*)+/
        .ignoresCase()
    nonisolated(unsafe) private static let opener = /^(?:(?:before i (?:go|get) to bed|i just (?:have|had) dinner|this (?:morning|evening|afternoon|week)|tonight|today|ok(?:ay)?|so|dear)[^,，!！。]*[,，!！。]\s*)+/
        .ignoresCase()
    nonisolated(unsafe) private static let trivial = /^(?:ok(?:ay)?|好的?|可以|yes|yep|继续|continue|go(?: on| ahead)?|just continue|commit|push|try again|再试|重试|嗯|行|对)\b/
        .ignoresCase()
    nonisolated(unsafe) private static let filler = /(?:另外|此外|我希望是|我希望|我想要|我想|你可以|请你|帮我|然后|那个|这个部分|就是|的话|一下|对吧|其实|大概|大约|稍微|可能|嗯|呢|啊|吧|\bplease\b|\bi want to\b|\bi'd like to\b|\bcan you\b|\bhelp me\b)\s*/
        .ignoresCase()
    nonisolated(unsafe) private static let intent = /我希望|希望|我想|想要|想让|想把|帮我|请你|请|需要|首选|目标|要求|改成|改为|做一[个份版]|做个|做好|修复|删掉|去掉|加上|添加|实现|优化|调整|\bhelp me\b|\bplease\b|\bi want\b|\bi'd like\b|\blet's\b|\bmake\b|\bfix\b|\badd\b|\bbuild\b|\bcreate\b|\bremove\b/
        .ignoresCase()
    nonisolated(unsafe) private static let strongIntent = /^(?:我希望|希望|首选|帮我|我想|想要|想让|想把|目标|help me|i want|i'd like|let's)/.ignoresCase()

    static func prepared(_ request: String) -> String {
        guard !isCarriedOver(request) else { return "" }
        return clean(request).replacing(greeting, with: "").replacing(opener, with: "")
    }

    /// A summary the agent wrote of an earlier, too-long part of the
    /// conversation, sent as if typed: not the person's words.
    static func isCarriedOver(_ request: String) -> Bool {
        ["This session is being continued from a previous conversation", "<artifact-content",
         "The summarized conversation"].contains { request.hasPrefix($0) }
    }

    static func trimFiller(_ clause: String) -> String {
        clause.replacing(filler, with: "").replacing(/\s+/, with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ，,"))
    }

    /// A request that says more than "ok", "commit" or "continue".
    static func isSubstantive(_ request: String) -> Bool {
        guard !isCarriedOver(request) else { return false }
        let t = clean(request).replacing(greeting, with: "").trimmingCharacters(in: CharacterSet(charactersIn: " ，,。.!！"))
        return width(t) >= 14 && !(t.contains(trivial) && t.firstRange(of: trivial)?.lowerBound == t.startIndex && width(t) < 40)
    }

    /// The clause of a request that says what the person wants, in their words.
    static func requestGist(_ request: String, budget: Double) -> String {
        let parts = clauses(prepared(request))
        guard !parts.isEmpty else { return "" }
        var best = parts[0]
        var bestScore = -Double.infinity
        for (index, clause) in parts.prefix(12).enumerated() {
            if clause.firstRange(of: trivial)?.lowerBound == clause.startIndex, width(clause) < 30 { continue }
            var score = 0.0
            if let match = clause.firstMatch(of: intent) {
                score += String(match.0).contains(strongIntent) ? 4 : 2.5
            }
            if clause.hasSuffix("对吧") || clause.hasSuffix("是吗") || clause.hasSuffix("吗") { score -= 2 }
            if clause.contains(/^(?:目前|现在|之前|刚才|currently|right now)/.ignoresCase()), clause.firstMatch(of: intent) == nil {
                score -= 1.5
            }
            if width(clause) < 5 { score -= 3 }
            score -= Double(index) * 0.35
            if score > bestScore { best = clause; bestScore = score }
        }
        return cut(trimFiller(best), budget)
    }
}

/// The person's own recurring words: nouns (and Chinese verbs) from their
/// requests, counted, with the conversation's name and common words left out.
enum DigestKeywords {
    private static let stop: Set<String> = Set("""
    我们 你们 这个 那个 一下 一个 一些 一点 有些 什么 怎么 这样 那样 然后 另外 还有 就是 的话 目前 现在 之前 刚才 已经 可以 可能 应该 需要 希望 想要 帮我
    比较 稍微 大概 大约 其实 感觉 觉得 好像 貌似 部分 方面 问题 东西 时候 地方 这里 那里 里面 上面 下面 一样 之后 以后 以及 因为 所以 如果 虽然 但是 不过 对吧
    看看 保留 继续 开始 完成 进行 提升 支持 使用 帮助 实现 处理 我觉得 知道 告诉 一份 一种 做到 程度 情况 内容 进一步 直接 确认 效果 方式 方案 版本
    thing things way ways time something anything everything lot part kind stuff idea ideas claude codex gpt friend hours minutes today tonight morning evening
    """.split(whereSeparator: \.isWhitespace).map(String.init))

    static func pick(from requests: [String], excluding title: String?, limit: Int = 4) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        var counts: [String: Double] = [:]
        var surface: [String: String] = [:]
        for (index, request) in requests.enumerated() {
            let text = DigestText.prepared(request)
            let weight = DigestText.isSubstantive(request) ? (index == 0 ? 1.5 : 1) : 0.3
            for (word, tag) in words(in: text, tagger: tagger) where isTerm(word, tag: tag) {
                let key = word.lowercased()
                counts[key, default: 0] += weight
                surface[key] = surface[key] ?? word
            }
        }
        let titleWords = Set(words(in: title ?? "", tagger: tagger).map { $0.0.lowercased() })
        let ranked = counts
            .filter { !titleWords.contains($0.key) && ($0.value >= 2 || $0.key.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }) }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        var picked: [String] = []
        for (key, _) in ranked where !picked.contains(where: { $0.lowercased().contains(key) || key.contains($0.lowercased()) }) {
            picked.append(surface[key] ?? key)
            if picked.count == limit { break }
        }
        return picked
    }

    private static func words(in text: String, tagger: NLTagger) -> [(String, NLTag?)] {
        guard !text.isEmpty else { return [] }
        tagger.string = text
        var words: [(String, NLTag?)] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            words.append((String(text[range]), tag))
            return true
        }
        return words
    }

    private static func isTerm(_ word: String, tag: NLTag?) -> Bool {
        let han = word.unicodeScalars.filter { (0x4E00...0x9FFF).contains($0.value) }.count
        guard tag == .noun || tag == .personalName || tag == .placeName || tag == .organizationName
                || (han > 0 && tag == .verb) else { return false }
        let lower = word.lowercased()
        guard !stop.contains(lower), lower.firstMatch(of: /^[\d.\-_\/:%x×*]+$/) == nil else { return false }
        if han > 0 { return han >= 2 }
        // Plain words only: tool names and ids ("mcp__x", "bda7") are not what the person talks about.
        return word.wholeMatch(of: /[A-Za-z][A-Za-z\-]{2,}/) != nil
    }
}
