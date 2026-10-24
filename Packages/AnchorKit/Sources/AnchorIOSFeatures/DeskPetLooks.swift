#if os(iOS)
import AnchorDesign
import SwiftUI

/// What a pet looks like: one pixel grid in flat colors with no outline
/// (the Clawd style), plus the few points its props hang from. Harbor and
/// pastel colors only; red, amber and green carry state on the desk.
///
/// Grid letters: `e` dark eye, `E` eye shine, `R` the right arm (hidden while
/// the raised arm is drawn), `.` empty; every other letter is a palette color.
struct DeskPetLook: Sendable {
    let rows: [String]
    let palette: [Character: UInt32]
    /// The color that closes an eye and fills a turned-away face.
    let lid: Character
    /// Letters drawn as `lid` when the pet turns its back.
    let face: Set<Character>
    /// The right arm raised for a wave, as a patch drawn at `raisedAt`.
    let raised: [String]
    let raisedAt: (x: Int, y: Int)
    /// Where a held thing sits (cup, hammer, pebble).
    let hand: (x: Int, y: Int)
    /// The row a hat brim or headphone band rests on.
    let crown: Int
    /// Headphone cups: left and right column, and their top row.
    let ears: (left: Int, right: Int, y: Int)
    /// Rows from here down lift in turn while it walks.
    let feetFrom: Int
    /// Jellyfish strands: columns, drawn below the grid.
    var strands: [Int] = []
    var strandColor: UInt32 = 0
    /// Hermit crab: only these letters stay out when it hides.
    var shell: Set<Character> = []
    /// What the face turns into from behind, when not `lid`.
    var backOfHead: Character?

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count + (strands.isEmpty ? 0 : 8) }

    /// Each eye as a bounding box, left eye first.
    var eyes: [(x0: Int, y0: Int, x1: Int, y1: Int)] {
        var cells: [(Int, Int)] = []
        for (y, row) in rows.enumerated() {
            for (x, c) in row.enumerated() where c == "e" || c == "E" { cells.append((x, y)) }
        }
        let mid = width / 2
        return [cells.filter { $0.0 < mid }, cells.filter { $0.0 >= mid }].compactMap { group in
            guard let first = group.first else { return nil }
            return group.reduce((x0: first.0, y0: first.1, x1: first.0, y1: first.1)) {
                (min($0.x0, $1.0), min($0.y0, $1.1), max($0.x1, $1.0), max($0.y1, $1.1))
            }
        }
    }

    func color(_ c: Character) -> Color? {
        switch c {
        case "e": DeskPetLook.ink
        case "E": DeskPetLook.white
        case "R": palette["R"].map { Color(anchorHex: $0) }
        default: palette[c].map { Color(anchorHex: $0) }
        }
    }

    static let ink = Color(anchorHex: AnchorColorTokens.deepSea)
    static let white = Color(anchorHex: 0xFFFFFF)

    static func of(_ kind: DeskPetKind) -> DeskPetLook {
        switch kind {
        case .squid: squid
        case .octopus: octopus
        case .hermit: hermit
        case .jelly: jelly
        case .crab, .off: crab
        }
    }

    // MARK: The five pets

    /// A wide seafoam block, eyes on stalks, a claw raised each side.
    static let crab = DeskPetLook(
        rows: [
            "......Ee......Ee......",
            "......ee......ee......",
            "C.C....B......B....R.R",
            "CCCBBBBBBBBBBBBBBBBRRR",
            ".CBLLBBBBBBBBBBBBBBBR.",
            "..BLBBBBBBBBBBBBBBBB..",
            "..BBBBpBBBBBBBBpBBBB..",
            "..BBBBBBBBmmBBBBBBBB..",
            "..BBBBBBBBBBBBBBBBBB..",
            "...DDDDDDDDDDDDDDDD...",
            "...D.D.D......D.D.D...",
            "..D.D.D........D.D.D.."
        ],
        palette: ["B": 0x91DEC4, "L": 0xCFF5EA, "D": 0x6CC7A8, "C": 0x7AD3B6, "R": 0x7AD3B6,
                  "p": 0xF4A6C0, "m": AnchorColorTokens.deepSea],
        lid: "B", face: ["p", "m"],
        raised: ["R.R", "RRR", ".R.", ".R."], raisedAt: (19, -2),
        hand: (19, 1), crown: -1, ears: (2, 19, 3), feetFrom: 10
    )

    /// The hooded squid kid: face in a window, round hands at its sides.
    static let squid = DeskPetLook(
        rows: [
            "........HHHHHH........",
            "......HHHHHHHHHH......",
            "....HHLLHHHHHHHHHH....",
            "...HHLHHHHHHHHHHHHH...",
            "..HHHHHHHHHHHHHHHHHH..",
            "..HHHHHHHHHHHHHHHHHH..",
            "..HHHFFFFFFFFFFFFHHH..",
            "..HHFFFEeFFFFEeFFFHH..",
            "..HHFFFeeFFFFeeFFFHH..",
            "..HHFppFFFmmFFFppFHH..",
            "...HHFFFFFFFFFFFFHH...",
            "..AAbbbbbbbbbbbbbbRR..",
            ".AA.bbbbbbbbbbbbbb.RR.",
            ".AA.bbbbbbbbbbbbbb.RR.",
            "AAAA.bbbbbbbbbbbb.RRRR",
            "AAAA.bbbbbbbbbbbb.RRRR",
            ".AA...ff......ff...RR.",
            "......ff......ff......"
        ],
        palette: ["H": 0xA99CF0, "L": 0xD4CCFA, "F": 0xFFF6EC, "b": 0xBDB3F4, "A": 0x9A8BE8,
                  "R": 0x9A8BE8, "f": 0x8E80E0, "p": 0xF4A6C0, "m": AnchorColorTokens.deepSea],
        lid: "F", face: ["p", "m", "F"],
        raised: ["...RR.", "..RRRR", "...RR.", "...RR.", "...RR.", "..RR..", ".RR...", "RR...."],
        raisedAt: (17, 4), hand: (19, 13), crown: 0, ears: (1, 20, 6), feetFrom: 16,
        backOfHead: "H"
    )

    /// The little octopus: round pink head, shiny low eyes, curled feet.
    static let octopus = DeskPetLook(
        rows: [
            ".......OOOOOOOO.......",
            ".....OOOOOOOOOOOO.....",
            "...OOllOOOOOOOOOOOO...",
            "..OOlOOOOOOOOOOOOOOO..",
            ".OOOOOOOOOOOOOOOOOOOO.",
            ".OOOOOOOOOOOOOOOOOOOO.",
            ".OOOOOEeOOOOOOEeOOOOO.",
            ".OOOOOeeOOOOOOeeOOOOO.",
            ".OOOppOOOOmmOOOOppOOO.",
            ".OOOOOOOOOOOOOOOOOOOO.",
            "..OOOOOOOOOOOOOOOOOO..",
            "..OOO..OOO..OOO..RRR..",
            "..OOO..OOO..OOO..RRR..",
            ".OOO..OOO....OOO..RRR.",
            "OO....OO......OO....RR"
        ],
        palette: ["O": 0xF7B3CC, "l": 0xFFE1EC, "R": 0xF7B3CC, "p": 0xF08DB3, "m": 0xC2547F],
        lid: "O", face: ["p", "m"],
        raised: ["..RR", "...R", "..RR", "..RR", ".RR.", ".RR.", "RR.."], raisedAt: (18, 4),
        hand: (20, 9), crown: 0, ears: (0, 21, 5), feetFrom: 11
    )

    /// The hermit crab: tall striped cone shell, two big notched claws.
    static let hermit = DeskPetLook(
        rows: [
            "..............SS......",
            ".............SSS......",
            "............SSSS......",
            "...........TTSSS......",
            "..........SSTTSS......",
            ".........SSSSTTSS.....",
            "........TTSSSSTTS.....",
            ".......SSTTSSSSTTS....",
            "......SSSSTTSSSSTTS...",
            ".....TTSSSSTTSSSSTTS..",
            "....SSTTSSSSTTSSSSTTS.",
            "....SSSSTTSSSSTTSSSSS.",
            "....CCCCCCCCCCCCCSSSS.",
            "...CCCCEeCCCCEeCCSSS..",
            "...CCCCeeCCCCeeCCSS...",
            "...CCpCeeCCCCeeCpCS...",
            ".KKKK.CCCCCCCC.RRRR...",
            "KKKKKKCCCCCCCCRRRRRR..",
            "KKK.KKCCCCCCCCRR.RRR..",
            "KKKKKKCCCCCCCCRRRRRR..",
            ".KKKK.l.l..l.l.RRRR..."
        ],
        palette: ["S": 0xFFF1DC, "T": 0x5BB8CC, "C": 0x9CC6F2, "K": 0x7FAEE6, "R": 0x7FAEE6,
                  "p": 0xF4A6C0, "l": 0x5E8FD0],
        lid: "C", face: ["p"],
        raised: ["RR.RR", "RRRRR", ".RRR.", ".RR..", "RR...", "R...."], raisedAt: (15, 10),
        hand: (16, 15), crown: 12, ears: (2, 18, 13), feetFrom: 20,
        shell: ["S", "T"]
    )

    /// The jellyfish: a small pale dome with a flared brim and four strands.
    static let jelly = DeskPetLook(
        rows: [
            "........JJJJJJ........",
            "......JJJJJJJJJJ......",
            "....JJllJJJJJJJJJJ....",
            "...JJlJJJJJJJJJJJJJ...",
            "..JJJJJJJJJJJJJJJJJJ..",
            "..JJJJJEeJJJJJEeJJJJ..",
            "..JJJJJeeJJJJJeeJJJJ..",
            ".JJJJJpJJJJJJJJpJJJJJ.",
            "dddddddddddddddddddddd",
            "...dddddddddddddddd..."
        ],
        palette: ["J": 0xBFEFF6, "l": 0xFFFFFF, "d": 0x8FD9E6, "p": 0xF4A6C0],
        lid: "J", face: ["p"],
        raised: [], raisedAt: (0, 0), hand: (19, 6), crown: 0, ears: (1, 20, 4), feetFrom: 99,
        strands: [6, 9, 12, 15], strandColor: 0xB7B4F5
    )
}
#endif
