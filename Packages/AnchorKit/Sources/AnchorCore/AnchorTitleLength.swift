import Foundation

/// How much room a task title takes on the boards (D05): a small landscape card
/// shows it on one line, a portrait card on two. A full-width character such as
/// 汉 counts as two, a Latin letter as one, so the limit means about 16 Chinese
/// characters or 32 Latin ones.
public enum AnchorTitleLength {
    public static let limit = 32
    /// How far back from the cut a natural break (a space, a comma) is still worth taking.
    static let breakReach = 12

    public static func units(of text: String) -> Int {
        text.reduce(0) { $0 + width(of: $1) }
    }

    /// The longest start of `text` that fits `limit`, and what is left over. The cut
    /// moves back to a nearby space or clause mark, so a word is not split in half.
    public static func split(_ text: String, limit: Int = limit) -> (title: String, rest: String) {
        var used = 0
        var end = text.startIndex
        for index in text.indices {
            used += width(of: text[index])
            if used > limit { break }
            end = text.index(after: index)
        }
        guard end < text.endIndex else { return (text, "") }
        if let pause = text[..<end].lastIndex(where: isBreak), pause > text.startIndex,
           units(of: String(text[pause..<end])) <= breakReach {
            end = text.index(after: pause)
        }
        return (String(text[..<end]).trimmingCharacters(in: trailing),
                String(text[end...]).trimmingCharacters(in: .whitespaces))
    }

    private static let clauseMarks: Set<Character> = ["，", ",", "。", "；", ";", "、", "：", ":", "！", "!", "？", "?"]
    private static let trailing = CharacterSet(charactersIn: "，,。；;、：:！!？?").union(.whitespaces)

    private static func isBreak(_ character: Character) -> Bool {
        character.isWhitespace || clauseMarks.contains(character)
    }

    private static func width(of character: Character) -> Int {
        character.unicodeScalars.contains(where: isWide) ? 2 : 1
    }

    private static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.isEmojiPresentation { return true }
        switch scalar.value {
        case 0x1100...0x115F, 0x2E80...0x303E, 0x3041...0x33FF, 0x3400...0x4DBF, 0x4E00...0x9FFF,
             0xA000...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF00...0xFF60,
             0xFFE0...0xFFE6, 0x20000...0x3FFFD:
            return true
        default:
            return false
        }
    }
}
