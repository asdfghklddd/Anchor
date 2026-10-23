import Foundation
import NaturalLanguage

/// Turns a typed or dictated plan into steps (I3): each line is a step, and a
/// spoken sequence ("先…然后…最后…", "…and then…") splits where the person
/// moved on. Dictation also loses its fillers, hedges and "I need to"s, and a
/// sentence with no action in it ("这件事的第一步") stays in the note rather
/// than becoming a step. The person sees and can edit the result before starting.
public enum PlanStepSplitter {
    public static func steps(from text: String) -> [String] {
        text.components(separatedBy: .newlines).flatMap(steps(inLine:))
    }

    /// A line typed as one step stays as written; a line that was said as
    /// several steps keeps only the parts that ask for an action.
    private static func steps(inLine line: String) -> [String] {
        let pieces = sentences(in: dropFillers(line))
            .flatMap(splitSpoken)
            .map { (said: $0, step: clean($0)) }
            .filter { !$0.step.isEmpty }
        guard pieces.count > 1 else {
            return pieces.map { startsUppercase($0.said) ? capitalized($0.step) : $0.step }
        }
        // Each step stands alone on the boards, so each starts like a sentence.
        return pieces.map(\.step)
            .filter { $0.count >= 2 && hasAction($0) }
            .map(capitalized)
    }

    // MARK: Splitting

    /// Sounds and padding that carry no meaning. Chinese ones only count when
    /// they stand alone, so "金额" and "那个文件" keep their words.
    private static func dropFillers(_ line: String) -> String {
        line
            .replacing(#/(^|[，,。！？!?\s])[嗯呃啊额哎]+[，,]?\s*/#) { $0.output.1 }
            .replacing(#/(^|[，,。！？!?\s])(?:那个|就是说?)[，,]\s*/#) { $0.output.1 }
            .replacing(#/(?i)\b(?:um+|uh+|erm+|hmm+)\b[,，]?\s*/#, with: "")
            .replacing(#/(?i)\byou know,\s*/#, with: "")
    }

    private static func sentences(in line: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = line
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: line.startIndex..<line.endIndex) { range, _ in
            sentences.append(String(line[range]))
            return true
        }
        return sentences.isEmpty ? [line] : sentences
    }

    /// Where a spoken plan moves on to its next step.
    private static func splitSpoken(_ sentence: String) -> [String] {
        sentence.split(
            separator: #/(?i)[,，]?\s*\b(?:and\s+)?(?:then|after that|afterwards|finally|ultimately|lastly)\b[,，]?\s*|(?:^|[,，]\s*)next[,，]\s*|然后呢?|接着|之后再|之后[，,]|再然后|最后|最终|；|;/#,
            omittingEmptySubsequences: true
        )
        .map(String.init)
    }

    // MARK: Cleaning

    /// Ordinals, connectives, hedges and "I need to" are how the plan was
    /// said, not part of the step. A purpose said first ("to finish X, I need
    /// to…") is context, so the step starts where the person did.
    private static func clean(_ piece: String) -> String {
        var step = trimmed(piece)
        step = step.replacing(/^(?:\d+[.、)）]\s*|[-•*]\s+|第[一二三四五六七八九十\d]+步[：:，,]?\s*)/, with: "")
        // Openers stack ("maybe I also need to first go look"), so peel until none is left.
        for _ in 0..<6 {
            let before = step
            step = step
                .replacing(#/(?i)^(?:so|okay|ok|well|and|also|first(?:ly)?|maybe|probably|perhaps|i think|i guess|i (?:also )?(?:need|have) to|i[’']ll|i will|i[’']m going to|i want to|i should|we (?:also )?(?:need|have) to|we[’']ll)(?:[,，]\s*|\s+)/#, with: "")
                .replacing(#/(?i)^go\s+(?:and\s+)?(?=(?:look|check|see|read|find|ask|get|talk|grab|buy|write|review)\b)/#, with: "")
                .replacing(#/(?i)^(?:in order )?to\b[^,，]*[,，]\s*(?=(?:(?:maybe|probably)\s+)?(?:i|we)\b)/#, with: "")
                .replacing(/^(?:我觉得|我想|可能|大概|也许)(?:[，,]\s*|(?=我|还|要|需要|得|会|去|先))/, with: "")
                .replacing(/^(?:我还?(?:需要|要|得|会|打算|准备)|还需要|还要|需要)(?!的)/, with: "")
                .replacing(/^(?:为了|要)[^，,]*[，,]\s*(?=(?:可能)?我)/, with: "")
                .replacing(/^(?:首先|其次|再|又|先)(?=\S{2})/, with: "")
            step = trimmed(step)
            if step == before { break }
        }
        step = step
            .replacing(#/(?i)[,，]\s*(?:i[’']ll|i will|i (?:also )?need to|i[’']m going to)\s+/#, with: ", ")
            .replacing(/[，,]\s*我(?:还需要|需要|会|要)/, with: "，")
            .replacing(#/(?i)[,，]?\s*\b(?:and|but|so)$/#, with: "")
        return trimmed(step)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: "，,。.、；;！!？? ").union(.whitespacesAndNewlines))
    }

    // MARK: Reading

    /// Is something to be done here? Any verb counts except the ones that
    /// only link words ("here's the plan" has no action in it). A bare English
    /// step is an imperative, which the tagger misreads on its own ("book the
    /// room" tags "book" as a noun), so it is also read after "Please".
    private static func hasAction(_ piece: String) -> Bool {
        if hasVerb(piece) { return true }
        guard let first = piece.first, first.isASCII, first.isLetter else { return false }
        return hasVerb("Please " + piece)
    }

    private static func hasVerb(_ text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var found = false
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            if tag == .verb, !linkingVerbs.contains(text[range].lowercased()) { found = true }
            return !found
        }
        return found
    }

    private static let linkingVerbs: Set<String> = [
        "is", "'s", "’s", "are", "'re", "’re", "was", "were", "be", "been", "am", "'m", "’m",
        "have", "has", "had", "do", "does", "did",
    ]

    private static func startsUppercase(_ text: String) -> Bool {
        trimmed(text).first?.isUppercase ?? false
    }

    /// "look at…" becomes "Look at…"; "iPhone" and "eBay" keep their shape.
    private static func capitalized(_ step: String) -> String {
        guard let first = step.first, first.isLowercase else { return step }
        if let second = step.dropFirst().first, second.isUppercase { return step }
        return first.uppercased() + step.dropFirst()
    }
}
