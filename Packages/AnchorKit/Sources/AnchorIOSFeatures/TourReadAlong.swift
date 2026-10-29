#if os(iOS)
import Foundation

/// How much of a line the person has read aloud during the tour, as a
/// language lesson listens: what the recognizer heard is lined up with the
/// line, letters and characters only and in order, so a misheard word or
/// two still counts and the line lights up as far as the voice has reached.
struct TourReadAlong: Equatable {
    /// Characters of the line lit so far, from its start.
    let lit: Int
    /// The share of the line heard, 0 to 1.
    let heard: Double

    init(heard transcript: String, line: String) {
        let characters = Array(line)
        let wanted = characters.indices.filter { characters[$0].isLetter || characters[$0].isNumber }
        let goal = wanted.map { Self.fold(characters[$0]) }
        let said = transcript.filter { $0.isLetter || $0.isNumber }.map(Self.fold)
        guard !goal.isEmpty, !said.isEmpty else {
            lit = 0
            heard = 0
            return
        }
        // The longest run of the line found in order in what was said.
        var table = Array(repeating: Array(repeating: 0, count: goal.count + 1), count: said.count + 1)
        for i in 1...said.count {
            for j in 1...goal.count {
                table[i][j] = said[i - 1] == goal[j - 1]
                    ? table[i - 1][j - 1] + 1 : max(table[i - 1][j], table[i][j - 1])
            }
        }
        var furthest = -1
        var i = said.count, j = goal.count
        while i > 0, j > 0 {
            if said[i - 1] == goal[j - 1] {
                furthest = max(furthest, j - 1)
                i -= 1
                j -= 1
            } else if table[i - 1][j] >= table[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        heard = Double(table[said.count][goal.count]) / Double(goal.count)
        guard furthest >= 0 else {
            lit = 0
            return
        }
        // An English word lights whole; the punctuation after it comes along.
        var end = wanted[furthest] + 1
        if !Self.isIdeograph(characters[end - 1]) {
            while end < characters.count, characters[end].isLetter || characters[end].isNumber,
                  !Self.isIdeograph(characters[end]) {
                end += 1
            }
        }
        while end < characters.count, characters[end].isPunctuation { end += 1 }
        lit = end
    }

    /// Enough of the line heard while the person is still talking.
    var isRead: Bool { heard >= 0.6 }
    /// Enough heard once they stop.
    var isEnough: Bool { heard >= 0.3 }

    private static func isIdeograph(_ character: Character) -> Bool {
        character.unicodeScalars.first?.properties.isIdeographic ?? false
    }

    private static func fold(_ character: Character) -> Character {
        character.lowercased().first ?? character
    }
}
#endif
