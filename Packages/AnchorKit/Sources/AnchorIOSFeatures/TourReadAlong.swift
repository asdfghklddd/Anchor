// Role: decides how much of a line has been read aloud. Takes the shortest prefix holding the best match, so an early word never lights the whole line.

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
        let best = table[said.count][goal.count]
        heard = Double(best) / Double(goal.count)
        guard best > 0 else {
            lit = 0
            return
        }
        // The voice has reached the shortest start of the line that holds all of
        // that run, never the same letters found further along, and it can't be
        // far ahead of how much was said.
        let reached = (1...goal.count).first { table[said.count][$0] == best } ?? goal.count
        let furthest = min(reached, said.count + Self.slack) - 1
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

    /// How many characters a misheard or skipped word may put the voice ahead of what was said.
    private static let slack = 8

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
