#if os(iOS)
import AnchorDesign
import SwiftUI

/// What a pet looks like: one pixel grid (26 cells wide) in flat colors with no outline
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
    var strandLength = 8
    /// The last strand lifted for a wave, cell by cell from its root.
    var curl: [(x: Int, y: Int)] = []
    /// Hermit crab: only these letters stay out when it hides.
    var shell: Set<Character> = []
    /// The shell's lowest row, which rests on the ground while it hides.
    var shellBottom = 0
    /// Where two dark dots look out from under the shell.
    var peekEyes: [(x: Int, y: Int)] = []
    /// What the face turns into from behind, when not `lid`.
    var backOfHead: Character?
    /// Which way the grid is drawn looking: 0 straight ahead, never mirrored;
    /// 1 or -1 a side view, mirrored when it turns the other way.
    var profile = 0
    /// What shows where the right arm was while it is raised, when not empty.
    var underArm: Character?
    /// Where water leaves the head (the whale's blowhole).
    var spout: (x: Int, y: Int) = (0, 0)
    /// The body colors of a soft and a bright glow.
    var glow: (soft: UInt32, bright: UInt32) = (0xDDF7FB, 0xF4FDFE)
    /// Rows left out while it presses itself flat.
    var squash: [Int] = []

    var width: Int { rows.first?.count ?? 0 }
    var height: Int { rows.count + (strands.isEmpty ? 0 : strandLength) }

    /// Whether the grid is drawn mirrored for a pet facing this way.
    func mirrored(facing: Int) -> Bool { profile != 0 && facing != profile }

    /// Each eye as a bounding box, left eye first.
    var eyes: [(x0: Int, y0: Int, x1: Int, y1: Int)] {
        var cells: [(Int, Int)] = []
        for (y, row) in rows.enumerated() {
            for (x, c) in row.enumerated() where c == "e" || c == "E" { cells.append((x, y)) }
        }
        // Split halfway between the outermost eye cells: a side-view face sits off center.
        guard let low = cells.map(\.0).min(), let high = cells.map(\.0).max() else { return [] }
        let mid = (low + high + 1) / 2
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
        case .whale: whale
        case .octopus: octopus
        case .hermit: hermit
        case .jelly: jelly
        case .starfish: starfish
        case .crab, .off: crab
        }
    }

    // MARK: The six pets

    /// A wide seafoam block, eyes on stalks, a claw raised each side.
    static let crab = DeskPetLook(
        rows: [
            "......Ee..........Ee......",
            "......ee..........ee......",
            "C.C....S..........S....R.R",
            "CCC....S..........S....RRR",
            "CCCC...BBBBBBBBBBBB...RRRR",
            ".CCC.BBBBBBBBBBBBBBBB.RRR.",
            "..CCBLLBBBBBBBBBBBBBBBRR..",
            "...BLLBBBBBBBBBBBBBBBBB...",
            "...BLBBBBBBBBBBBBBBBBBB...",
            "...BBBppBBBBBBBBBBppBBB...",
            "...BBBBBBBBBmmBBBBBBBBB...",
            "...BBBBBBBBBBBBBBBBBBBB...",
            "....DDDDDDDDDDDDDDDDDD....",
            "....D.D.D........D.D.D....",
            "...D.D.D..........D.D.D..."
        ],
        palette: ["B": 0x91DEC4, "L": 0xCFF5EA, "D": 0x6CC7A8, "C": 0x7AD3B6, "R": 0x7AD3B6, "S": 0x6CC7A8,
                  "p": 0xF4A6C0, "m": AnchorColorTokens.deepSea],
        lid: "B", face: ["p", "m"],
        raised: ["R.R.", "RRR.", ".RR.", ".RR.", ".RR."], raisedAt: (22, -3),
        hand: (22, 1), crown: -1, ears: (3, 22, 6), feetFrom: 13
    )

    /// The little whale, lying on its belly: head to the left, a cream belly,
    /// two front flippers on the ground and its tail fluke up behind.
    static let whale = DeskPetLook(
        rows: [
            "......WWWWWW..............",
            "....WWwwWWWWWW............",
            "...WWwLLWWWWWWWW..........",
            "..WWwLWWWWWWWWWWW.........",
            ".WWLLWWWWWWWWWWWWW........",
            ".WWWWWWWWWWWWWWWWWW.......",
            "WWWWEeWWWWWEeWWWWWWW....T.",
            "WWWWeeWWWWWeeWWWWWWWW..TT.",
            "WWppWWWWmWWWWppWWWWWW..TT.",
            "WWWFFFFmFmFFFFFWWWWWWDTTTT",
            "WWFFFFFFFFFFFFFFWWWWWDDTTT",
            "WWFFFFFFFFFFFFFFFWWWWWDTTT",
            "KKKKKFFFFFFRRRRkFFFFFF.TTT",
            "KKKKkFFFFFFRRRkFFFFFF....."
        ],
        palette: ["W": 0xB4AEDF, "w": 0xF4F2FC, "L": 0xD6D2F2, "F": 0xF4EFE9, "K": 0xA79FDA, "R": 0xA79FDA,
                  "k": 0x948BD0, "D": 0x9C93D3, "T": 0xB4AEDF, "p": 0xF08DB3, "m": AnchorColorTokens.deepSea],
        lid: "W", face: ["p", "m", "F"],
        raised: ["....RR", "...RRk", "..RRk.", ".RRk..", "RRk..."], raisedAt: (12, 7),
        hand: (16, 8), crown: 0, ears: (1, 19, 6), feetFrom: 12,
        backOfHead: "W", profile: -1, underArm: "F", spout: (8, 0), glow: (0xD6D2F2, 0xEDEBFA)
    )

    /// The little octopus: round pink head, shiny low eyes, curled feet.
    static let octopus = DeskPetLook(
        rows: [
            ".........OOOOOOOO.........",
            "......OOOOOOOOOOOOOO......",
            ".....OOllOOOOOOOOOOOO.....",
            "....OOllOOOOOOOOOOOOOO....",
            "...OOlOOOOOOOOOOOOOOOOO...",
            "..OOOOOOOOOOOOOOOOOOOOOO..",
            "..OOOOOOOOOOOOOOOOOOOOOO..",
            ".OOOOOOOEeOOOOOOEeOOOOOOO.",
            ".OOOOOOOeeOOOOOOeeOOOOOOO.",
            ".OOOOOOOeeOOOOOOeeOOOOOOO.",
            ".OOOOppOOOOOmmOOOOOppOOOO.",
            ".OOOOOOOOOOOOOOOOOOOOOOOO.",
            "..dddddddddddddddddddddd..",
            "..OOOO..OOOO..OOOO..RRRR..",
            "..OOOO..OOOO..OOOO..RRRR..",
            ".OOOO..OOOO....OOOO..RRRR.",
            ".OOO..OOO........OOO..RRR.",
            "OO.....OO........OO....RR."
        ],
        palette: ["O": 0xF7B3CC, "l": 0xFFE1EC, "R": 0xF7B3CC, "d": 0xF09DBE, "p": 0xF08DB3, "m": 0xC2547F],
        lid: "O", face: ["p", "m"],
        raised: ["..RR", "...R", "...R", "..RR", "..RR", ".RR.", ".RR.", "RR.."], raisedAt: (21, 5),
        hand: (23, 10), crown: 0, ears: (1, 24, 6), feetFrom: 13
    )

    /// The hermit crab: tall striped cone shell, two big notched claws.
    static let hermit = DeskPetLook(
        rows: [
            "................SS........",
            "...............SSS........",
            "..............SSSS........",
            ".............TTSSS........",
            "............SSTTSS........",
            "...........SSSSTTS........",
            "..........TTSSSSTTS.......",
            ".........SSTTSSSSTTS......",
            "........SSSSTTSSSSTTS.....",
            ".......TTSSSSTTSSSSTTS....",
            "......SSTTSSSSTTSSSSTTS...",
            ".....SSSSTTSSSSTTSSSSTTS..",
            ".....SSSSSSTTSSSSTTSSSSS..",
            ".....SSSSSSSSTTSSSSTTSSS..",
            ".....CCCCCCCCCCCCCCCSSSS..",
            "....CCCCCCCCCCCCCCCCCSSS..",
            "....CCCCEeCCCCCEeCCCCSS...",
            "....CCCCeeCCCCCeeCCCCS....",
            "....CCpCeeCCCCCeeCpCCS....",
            ".KKKKK.CCCCCCCCCC.RRRRR...",
            "KKKKKKKCCCCCCCCCCRRRRRRR..",
            "KKKK.KKCCCCCCCCCCRR.RRRR..",
            "KKK..KKCCCCCCCCCCRR..RRR..",
            "KKKKKKKCCCCCCCCCCRRRRRRR..",
            ".KKKKK.l.l.l..l.l.RRRRR..."
        ],
        palette: ["S": 0xFFF1DC, "T": 0x5BB8CC, "C": 0x9CC6F2, "K": 0x7FAEE6, "R": 0x7FAEE6,
                  "p": 0xF4A6C0, "l": 0x5E8FD0],
        lid: "C", face: ["p"],
        raised: ["RR..RR", "RRRRRR", ".RRRR.", "..RR..", ".RR...", "RR....", "R....."], raisedAt: (17, 12),
        hand: (19, 18), crown: 14, ears: (3, 21, 16), feetFrom: 24,
        shell: ["S", "T"], shellBottom: 13, peekEyes: [(8, 13), (11, 13)], profile: 1
    )

    /// The jellyfish: a small pale dome with a flared brim and four strands.
    static let jelly = DeskPetLook(
        rows: [
            "..........JJJJJJ..........",
            "........JJJJJJJJJJ........",
            "......JJllJJJJJJJJJJ......",
            ".....JJllJJJJJJJJJJJJ.....",
            "....JJlJJJJJJJJJJJJJJJ....",
            "...JJJJJJJJJJJJJJJJJJJJ...",
            "...JJJJJEeJJJJJJEeJJJJJ...",
            "...JJJJJeeJJJJJJeeJJJJJ...",
            "..JJJJJpJJJJJJJJJJpJJJJJ..",
            "..JJJJJJJJJJJJJJJJJJJJJJ..",
            "dddddddddddddddddddddddddd",
            "...dddddddddddddddddddd..."
        ],
        palette: ["J": 0xBFEFF6, "l": 0xFFFFFF, "d": 0x8FD9E6, "p": 0xF4A6C0],
        lid: "J", face: ["p"],
        raised: [], raisedAt: (0, 0), hand: (22, 7), crown: 0, ears: (2, 23, 5), feetFrom: 99,
        strands: [7, 11, 14, 18], strandColor: 0xB7B4F5, strandLength: 10,
        curl: [(18, 11), (19, 10), (20, 9), (21, 8), (22, 7), (22, 6), (21, 5)]
    )

    /// The starfish: five plump points, a cream shine down its left edges,
    /// darker freckles, the right arm free to lift.
    static let starfish = DeskPetLook(
        rows: [
            "............SS............",
            "...........SSSS...........",
            "...........uSSS...........",
            "..........SuSSSS..........",
            "..........uSSSSS..........",
            ".........SuSSSSSS.........",
            ".........uSSSSSSS.........",
            "..SuuuuuSSSSSSSSSSSSRRRR..",
            ".SSOSSSSSSSSSSSSSSSSRRRRR.",
            "SSSSSSSSSEeSSSSEeSSSRRRRRR",
            "SSSSSSSSSeeSSSSeeSSSRRRRRR",
            ".SSSSSSppSSSmmSSSppSRRRRR.",
            "...OSSSSSSSSSSSSSSSSOS....",
            ".....SSSSSSSSSSSSSSSS.....",
            ".....SSSSSOSSSSSSSSSS.....",
            ".....SSSSSSO..SSSSSSS.....",
            "....SSSSSSS....SSOSSSS....",
            "....SSSSSS......SSSOSS....",
            "...SuSSSS........SSSSSS...",
            "...SuSSS..........SSSSS...",
            "...SuSS............SSSS...",
            "....SS..............SS...."
        ],
        palette: ["S": 0xF7D488, "R": 0xF7D488, "u": 0xFDF0D2, "O": 0xF0B85A, "p": 0xF08DB3, "m": 0xB5566E],
        lid: "S", face: ["p", "m"],
        raised: [".....RR", "....RRR", "...RRRR", "..RRRR.", ".RRRRR.", "RRRRR..", "RRRR...", "RRR....", "RR....."],
        raisedAt: (19, 2), hand: (21, 10), crown: 0, ears: (1, 24, 9), feetFrom: 15,
        glow: (0xF9DD9C, 0xFBE7B6), squash: [1, 3, 5]
    )
}
#endif
