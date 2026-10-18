import Foundation

/// Turns a typed or dictated plan into steps (I3): each line is a step, and a
/// spoken sequence ("先…然后…最后…", "…and then…") splits where the person
/// moved on. The person sees and can edit the result before starting.
public enum PlanStepSplitter {
    public static func steps(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .flatMap(splitSpoken)
            .map(clean)
            .filter { !$0.isEmpty }
    }

    /// Where a spoken plan moves on to its next step.
    private static func splitSpoken(_ line: String) -> [String] {
        line.split(separator: #/然后|接着|之后再|再然后|最后|；|;|,? and then |,? after that,? /#, omittingEmptySubsequences: true)
            .map(String.init)
    }

    /// Ordinals, leading connectives and trailing punctuation are how the plan
    /// was said, not part of the step.
    private static func clean(_ piece: String) -> String {
        var step = piece.trimmingCharacters(in: .whitespacesAndNewlines)
        step = step.replacing(/^(?:\d+[.、)）]\s*|[-•*]\s+|第[一二三四五六七八九十\d]+步[：:，,]?\s*)/, with: "")
        step = step.replacing(/^(?:首先|其次|再|又|先)(?=\S{2})/, with: "")
        step = step.trimmingCharacters(in: CharacterSet(charactersIn: "，,。.、 ").union(.whitespaces))
        return step
    }
}
