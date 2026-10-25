#if os(iOS)
import AnchorDesign
import SwiftUI

/// The pet's corner of the desk: a millennium-era nook drawn in the pet's own
/// pixels. Every pet has a window whose sky follows the hour, a desk with a
/// lamp and a computer, and a plant on the sill; each also has things of its
/// own (the crab's pegboard and toolbox, the squid kid's poster and boombox,
/// the octopus's books and lava lamp, the hermit's shell shelf and cactus,
/// the jellyfish's fish tank). Things can be touched: the blinds, the lamp,
/// the computer, the plant, and the pet's own thing, which it walks over to use.
enum DeskScene {
    /// The nook in cells: 78 × 66 at 3 points each.
    static let columns = 78
    static let rows = 66
    /// The floor line; the pet's feet stand just above it.
    static let floor = 62

    /// Something in the nook that answers a touch.
    enum Thing: Hashable {
        case blinds, lamp, computer, plant, own
    }

    /// Where each thing sits, in cells; a touch inside it reaches it.
    static func frame(of thing: Thing, for kind: DeskPetKind) -> CGRect {
        switch thing {
        case .blinds: CGRect(x: 3, y: 4, width: 22, height: 21)
        case .lamp: CGRect(x: 68, y: 33, width: 9, height: 13)
        case .computer: CGRect(x: 49, y: 30, width: 18, height: 16)
        case .plant: CGRect(x: 17, y: 15, width: 8, height: 10)
        case .own: own(kind).frame
        }
    }

    static func thing(at cell: CGPoint, for kind: DeskPetKind) -> Thing? {
        [Thing.own, .lamp, .computer, .plant, .blinds].first { frame(of: $0, for: kind).contains(cell) }
    }

    /// The pet's own thing: where it stands, where the pet goes to use it, and what it does there.
    struct Own {
        let frame: CGRect
        let standAt: Int
        let act: DeskPetAct
    }

    static func own(_ kind: DeskPetKind) -> Own {
        switch kind {
        case .crab, .off: Own(frame: CGRect(x: 29, y: 8, width: 14, height: 54), standAt: 3, act: .build)
        case .squid: Own(frame: CGRect(x: 28, y: 7, width: 14, height: 55), standAt: 1, act: .dance)
        case .octopus: Own(frame: CGRect(x: 27, y: 14, width: 16, height: 48), standAt: 16, act: .read)
        case .hermit: Own(frame: CGRect(x: 27, y: 16, width: 16, height: 6), standAt: 16, act: .polish)
        case .jelly: Own(frame: CGRect(x: 27, y: 50, width: 16, height: 12), standAt: 1, act: .glow)
        }
    }

    /// What the nook remembers between touches.
    struct State: Equatable {
        var blindsDown = false
        /// `nil` follows the hour: on in the evening and at night.
        var lampOn: Bool?
        var screensaver = false
        /// Leaves grown from watering, 0 to 3; kept across launches.
        var growth = 0
        /// The tick the plant was last watered.
        var wateredAt = -1_000
        /// The tick the pet's own thing was last touched.
        var ownAt = -1_000
    }

    /// What the computer shows.
    enum Screen {
        case off, desktop, code, stars
    }
}

/// Draws the nook behind the pet.
struct DeskSceneRenderer {
    let kind: DeskPetKind
    let context: GraphicsContext
    let pixel: CGFloat
    let tick: Int
    let hour: Int
    let state: DeskScene.State
    let screen: DeskScene.Screen
    /// The pet is dancing, so the boombox plays.
    let music: Bool

    private var lampOn: Bool { state.lampOn ?? (hour >= 18 || hour < 7) }

    func draw() {
        floor()
        window()
        plant()
        own()
        desk()
        computer()
        lamp()
    }

    // MARK: Shared things

    private func floor() {
        fill(0, DeskScene.floor, DeskScene.columns, 1, 0xDDEFF5)
        fill(0, DeskScene.floor + 1, DeskScene.columns, 1, 0xE9F6FA)
    }

    private func window() {
        let (x0, y0, w, h) = (3, 4, 22, 21)
        let night = hour >= 20 || hour < 6
        let dusk = (17..<20).contains(hour)
        let sky: UInt32 = night ? 0x2A3F6B : (dusk ? 0xFCDCCB : 0xBFE9FA)
        fill(x0, y0, w, h, sky)
        if night {
            for (i, star) in [(5, 7), (9, 6), (14, 9), (19, 13), (6, 16), (12, 14), (20, 21)].enumerated() {
                // Each star dims now and then, out of step with the others.
                let twinkle = (tick / 6 + i * 5) % 17 == 0
                dot(star.0, star.1, twinkle ? 0x8EA3C8 : 0xFFF2B3)
            }
            fill(17, 6, 3, 2, 0xFFF6D6)
            dot(16, 7, 0xFFF6D6)
            dot(18, 8, 0xFFF6D6)
        } else if dusk {
            fill(6, 15, 4, 3, 0xFFE9A8)
            fill(7, 14, 2, 1, 0xFFE9A8)
        } else {
            // A cloud drifts across the pane and comes round again.
            let drift = (tick / 24) % 26 - 4
            for (dx, dy) in [(1, 0), (2, 0), (3, 0), (0, 1), (1, 1), (2, 1), (3, 1), (4, 1)] {
                let x = x0 + 1 + (drift + dx + 26) % 20
                dot(x, 8 + dy, 0xFFFFFF)
            }
            fill(16, 6, 3, 3, 0xFFF2B3)
        }
        if state.blindsDown {
            for y in stride(from: y0, to: y0 + h, by: 2) {
                fill(x0, y, w, 1, 0xF2F7FA)
                fill(x0, y + 1, w, 1, 0xE3EEF2)
            }
            fill(x0 + w - 2, y0 + h - 1, 1, 3, 0x9AAAB6)
        }
        // Frame and cross bars.
        fill(x0, y0, w, 1, 0xFFFFFF)
        fill(x0, y0 + h - 1, w, 1, 0xFFFFFF)
        fill(x0, y0, 1, h, 0xFFFFFF)
        fill(x0 + w - 1, y0, 1, h, 0xFFFFFF)
        if !state.blindsDown {
            fill(x0 + 10, y0, 2, h, 0xFFFFFF)
            fill(x0, y0 + 10, w, 1, 0xFFFFFF)
        }
        // The sill.
        fill(1, 25, 26, 1, 0xFFFFFF)
        fill(1, 26, 26, 1, 0xE3EEF2)
    }

    private func plant() {
        let art = kind == .hermit ? DeskSceneArt.cactus : DeskSceneArt.plant
        let x = 17, y = 25 - art.count
        grid(art, x, y) { DeskSceneArt.color($0) }
        // Leaves grown from watering, one more each time, up to three.
        let leaf: UInt32 = kind == .hermit ? 0x6CC7A8 : 0x7AD3B6
        let grown = [(3, -1), (5, -1), (1, -2)].prefix(state.growth)
        for cell in grown { dot(x + cell.0, y + cell.1, leaf) }
        let since = tick - state.wateredAt
        if since >= 0, since < 24 {
            // Drops fall onto the leaves.
            for (i, column) in [1, 3, 5].enumerated() {
                let fall = (since + i * 3) % 8
                dot(x + column, y - 6 + fall, 0x8FD9E6)
            }
        }
    }

    private func desk() {
        fill(44, 46, 34, 1, 0xFBF4EA)
        fill(44, 47, 34, 1, 0xEEDFCB)
        for column in [46, 47, 75, 76] { fill(column, 48, 1, 14, 0xE9DCC8) }
        fill(62, 48, 14, 7, 0xF6ECDF)
        fill(62, 54, 14, 1, 0xE9DCC8)
        fill(68, 51, 2, 1, 0xC9B79C)
        grid(DeskSceneArt.keyboard, 51, 44) { $0 == "k" ? Color(anchorHex: 0xFFFFFF) : Color(anchorHex: 0xD8E4EA) }
    }

    private func computer() {
        let crt = kind == .crab || kind == .off
        let art = crt ? DeskSceneArt.crt : DeskSceneArt.imac
        let (x0, y0) = (49, 30)
        let shell: (UInt32, UInt32) = switch kind {
        case .crab, .off: (0xEDE7D9, 0xD8D0BF)
        case .squid: (0xBDB3F4, 0xD4CCFA)
        case .octopus: (0xF7B3CC, 0xFFD3E2)
        case .hermit: (0x9CC6F2, 0xC9E0F8)
        case .jelly: (0x8FD9E6, 0xC4EEF5)
        }
        grid(art, x0, y0) { letter in
            switch letter {
            case "B", "C": Color(anchorHex: shell.0)
            case "b", "c": Color(anchorHex: shell.1)
            case "w", "i": Color(anchorHex: 0xFFFFFF)
            case "l": Color(anchorHex: 0xB7AE9C)
            case "g": Color(anchorHex: screen == .off ? 0xB7AE9C : 0x7AD3B6)
            case "s": nil
            default: nil
            }
        }
        let area = crt ? CGRect(x: x0 + 2, y: y0 + 2, width: 14, height: 9) : CGRect(x: x0 + 3, y: y0 + 3, width: 12, height: 8)
        display(in: area)
    }

    /// The screen: dark when the pet sleeps, code while agents run, a starfield
    /// when the screensaver is on, otherwise a desktop of the era.
    private func display(in area: CGRect) {
        let (x0, y0, w, h) = (Int(area.minX), Int(area.minY), Int(area.width), Int(area.height))
        switch screen {
        case .off:
            fill(x0, y0, w, h, 0x2E4A6B)
            dot(x0 + 1, y0 + 1, 0x4A6789)
        case .code:
            fill(x0, y0, w, h, 0x203654)
            let colors: [UInt32] = [0x8FD9E6, 0xBDB3F4, 0x91DEC4, 0xF7B3CC]
            for row in 0..<(h - 1) {
                // Lines scroll up as the agent writes.
                let line = row + tick / 3
                let indent = (line * 7) % 3
                let length = 3 + (line * 5) % (w - 4)
                fill(x0 + 1 + indent, y0 + row + 1, min(length, w - 2 - indent), 1, colors[line % colors.count])
            }
        case .stars:
            fill(x0, y0, w, h, 0x1B2A44)
            for i in 0..<7 {
                let age = (tick / 2 + i * 9) % 12
                let angle = Double(i) * 2.4
                let x = x0 + w / 2 + Int((cos(angle) * Double(age) * 0.6).rounded())
                let y = y0 + h / 2 + Int((sin(angle) * Double(age) * 0.4).rounded())
                if x >= x0, x < x0 + w, y >= y0, y < y0 + h { dot(x, y, age > 6 ? 0xFFFFFF : 0x8EA3C8) }
            }
        case .desktop:
            fill(x0, y0, w, h, 0x6CC7D9)
            fill(x0 + 1, y0 + 1, 2, 2, 0xFFFFFF)
            fill(x0 + 1, y0 + 4, 2, 2, 0xFFF2B3)
            fill(x0, y0 + h - 1, w, 1, 0xD8E4EA)
            fill(x0, y0 + h - 1, 3, 1, 0x91DEC4)
        }
    }

    private func lamp() {
        let (x0, y0) = (68, 33)
        if lampOn {
            // A soft pool of light under the shade.
            for row in 0..<10 {
                let spread = 1 + row / 2
                fill(x0 + 4 - spread, y0 + 3 + row, spread * 2 + 1, 1, 0xFFF2B3, opacity: 0.35)
            }
        }
        grid(DeskSceneArt.lamp, x0, y0) { letter in
            switch letter {
            case "S": Color(anchorHex: 0xFFC2D6)
            case "a": Color(anchorHex: 0x9AAAB6)
            case "l": Color(anchorHex: lampOn ? 0xFFF2B3 : 0xE3EEF2)
            default: nil
            }
        }
    }

    // MARK: The pet's own things

    private func own() {
        let since = tick - state.ownAt
        switch kind {
        case .crab, .off:
            grid(DeskSceneArt.pegboard, 29, 8) { DeskSceneArt.color($0) }
            grid(DeskSceneArt.toolbox, 30, DeskScene.floor - 7) { DeskSceneArt.color($0) }
            if since >= 0, since < 20, since % 4 < 2 { dot(36, DeskScene.floor - 9, 0xFFF2B3) }
        case .squid:
            grid(DeskSceneArt.poster, 30, 7) { $0 == "P" ? Color(anchorHex: 0xFFE1EC) : DeskSceneArt.color($0) }
            let beat = music && (tick / 2) % 2 == 0
            grid(DeskSceneArt.boombox, 28, DeskScene.floor - 7) { letter in
                letter == "O" && beat ? Color(anchorHex: 0xF7B3CC) : DeskSceneArt.color(letter)
            }
            if music {
                for i in 0..<2 {
                    let rise = (tick / 3 + i * 5) % 10
                    dot(31 + i * 8, DeskScene.floor - 9 - rise, i == 0 ? 0x289CB8 : 0xA99CF0)
                    dot(32 + i * 8, DeskScene.floor - 10 - rise, i == 0 ? 0x289CB8 : 0xA99CF0)
                }
            }
        case .octopus:
            grid(DeskSceneArt.bookshelf, 27, 14) { DeskSceneArt.color($0) }
            let (x0, y0) = (36, DeskScene.floor - 10)
            grid(DeskSceneArt.lava, x0, y0) { DeskSceneArt.color($0) }
            // Two blobs rise and sink in the glass.
            for i in 0..<2 {
                let phase = Double(tick + i * 37) / 22
                let y = y0 + 4 + Int(((sin(phase) + 1) * 1.6).rounded())
                fill(x0 + 2 + i, y, 2, 1, 0xF08DB3)
            }
        case .hermit:
            grid(DeskSceneArt.shells, 27, 16) { DeskSceneArt.color($0) }
            if since >= 0, since < 24 || (tick / 8) % 23 == 0 {
                dot(37, 16, 0xFFFFFF)
                dot(36, 17, 0xFFFFFF)
            }
        case .jelly:
            let (x0, y0) = (27, DeskScene.floor - 12)
            grid(DeskSceneArt.tank, x0, y0) { DeskSceneArt.color($0) }
            // Two fish cross the tank, faster just after a touch.
            let quick = since >= 0 && since < 40
            for (i, color) in [UInt32(0xF7B3CC), 0xFFE1A8].enumerated() {
                let pace = quick ? 1 : 3
                let span = 10
                let step = (tick / pace + i * 7) % (span * 2)
                let x = x0 + 2 + (step < span ? step : span * 2 - step)
                let y = y0 + 3 + i * 3
                fill(x, y, 2, 1, color)
                dot(step < span ? x - 1 : x + 2, y, color)
            }
            for i in 0..<3 {
                let rise = (tick / 4 + i * 3) % 7
                dot(x0 + 4 + i * 4, y0 + 8 - rise, 0xFFFFFF)
            }
        }
    }

    // MARK: Painting

    private func dot(_ x: Int, _ y: Int, _ hex: UInt32, opacity: Double = 1) {
        fill(x, y, 1, 1, hex, opacity: opacity)
    }

    private func fill(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ hex: UInt32, opacity: Double = 1) {
        context.fill(Path(CGRect(x: CGFloat(x) * pixel, y: CGFloat(y) * pixel,
                                 width: CGFloat(w) * pixel, height: CGFloat(h) * pixel)),
                     with: .color(Color(anchorHex: hex).opacity(opacity)))
    }

    private func grid(_ rows: [String], _ x: Int, _ y: Int, _ color: (Character) -> Color?) {
        for (r, row) in rows.enumerated() {
            for (c, letter) in row.enumerated() where letter != "." {
                guard let fill = color(letter) else { continue }
                context.fill(Path(CGRect(x: CGFloat(x + c) * pixel, y: CGFloat(y + r) * pixel,
                                         width: pixel, height: pixel)), with: .color(fill))
            }
        }
    }
}

/// The nook's pixel art. Letters name colors in `color(_:)`.
private enum DeskSceneArt {
    static let crt = [
        ".BBBBBBBBBBBBBBBB.",
        "BBBBBBBBBBBBBBBBBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBssssssssssssssBB",
        "BBBBBBBBBBBBBBBBBB",
        "BBBBBBBBBBBBBlBgBB",
        ".BBBBBBBBBBBBBBBB.",
        "......bbbbbb......",
        "....bbbbbbbbbb....",
    ]
    static let imac = [
        "...CCCCCCCCCCCC...",
        ".CCCCCCCCCCCCCCCC.",
        "CCwwwwwwwwwwwwwwCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwsssssssssssswCC",
        "CCwwwwwwwwwwwwwwCC",
        "CCCCCCCCiCCCCCCCCC",
        ".CcCcCcCcCcCcCcCC.",
        "...CCCCCCCCCCCC...",
        ".....cccccccc.....",
    ]
    static let keyboard = [
        "kkkkkkkkkkkkkk",
        "KKKKKKKKKKKKKK",
    ]
    static let lamp = [
        "..SSSSS..",
        ".SSSSSSS.",
        "SSSSSSSSS",
        "...lll...",
        "....a....",
        ".....a...",
        "......a..",
        ".....a...",
        "....a....",
        "...a.....",
        "...a.....",
        "..aaaa...",
        ".aaaaaa..",
    ]
    static let plant = [
        "...L....",
        ".L.LL...",
        "LLLL.L.L",
        ".LLLLLL.",
        "..LLLL..",
        "...LL...",
        ".PPPPPP.",
        ".PpPPPP.",
        "..PPPP..",
    ]
    static let cactus = [
        "..G.....",
        ".GG..G..",
        ".GG.GG..",
        ".GGGGG..",
        "..GGG...",
        "..GG....",
        "..GG....",
        ".PPPPP..",
        "..PPP...",
    ]
    static let pegboard = [
        "bbbbbbbbbbbbbb",
        "bobobobobobobo",
        "bbwwbbbbbhbbbb",
        "bowwbobobhbobo",
        "bbbwbbbbbhbbbb",
        "bobwbobobdbobo",
        "bbbwbbbbbdbbbb",
        "bobobobobdbobo",
        "bbbbbbbbbbbbbb",
    ]
    static let toolbox = [
        "...hhhhhh...",
        "...h....h...",
        "TTTTTTTTTTTT",
        "TtttttttttTT",
        "TTTTTLLTTTTT",
        "TTTTTTTTTTTT",
        "TTTTTTTTTTTT",
    ]
    static let boombox = [
        "....hhhhhh....",
        "...h......h...",
        "XXXXXXXXXXXXXX",
        "XoooXXccXXoooX",
        "XoOoXXccXXoOoX",
        "XoooXXXXXXoooX",
        "XXXXXXXXXXXXXX",
    ]
    static let poster = [
        "PPPPPPPPPPPP",
        "PPPPPPPPPPPP",
        "PPPPPYPPPPPP",
        "PPPPYYYPPPPP",
        "PPYYYYYYYPPP",
        "PPPYYYYYPPPP",
        "PPPYYPYYPPPP",
        "PPYYPPPYYPPP",
        "PPPPPPPPPPPP",
        "PPPPPPPPPPPP",
    ]
    static let bookshelf = [
        "..1.2...........",
        ".11223.4.5......",
        ".112234455.66...",
        ".11223445566.7..",
        ".1122344556677..",
        "WWWWWWWWWWWWWWWW",
        "..............h.",
    ]
    static let lava = [
        "..mm..",
        ".mmmm.",
        ".gggg.",
        ".gggg.",
        "gggggg",
        "gggggg",
        "gggggg",
        ".gggg.",
        ".mmmm.",
        "mmmmmm",
    ]
    static let shells = [
        "...........u....",
        "..vv.....uuu..x.",
        ".vvvv...uuuuu.xx",
        "vvvvvv..uuuuu.xx",
        "WWWWWWWWWWWWWWWW",
        "..h..........h..",
    ]
    static let tank = [
        "gggggggggggggggg",
        "gqqqqqqqqqqqqqqg",
        "gqqqqqqqqqqqqqqg",
        "gqqqqqqqqqqqqqqg",
        "gqqqqqqqqqqqqqqg",
        "gqqqqqqqqqqqqqqg",
        "gqqqqqqqqqqqqqqg",
        "gqqqqqqqqqqqqqqg",
        "gqssqqqqqssqqqqg",
        "gsssssssssssssss",
        "gggggggggggggggg",
        "..TT........TT..",
    ]

    static func color(_ c: Character) -> Color? {
        let hex: UInt32? = switch c {
        case "L": 0x7AD3B6
        case "G": 0x6CC7A8
        case "P": 0xF7B3CC
        case "p": 0xFFE1EC
        case "b": 0xF2F7FA
        case "o": 0xC9DCE4
        case "w": 0x9AAAB6
        case "h": 0x9AAAB6
        case "d": 0x5BB8CC
        case "T": 0x5BB8CC
        case "t": 0x8FD9E6
        case "X": 0xA99CF0
        case "O": 0xFFFFFF
        case "c": 0x2E4A6B
        case "Y": 0xFFF2B3
        case "1": 0xF7B3CC
        case "2": 0xA99CF0
        case "3": 0x8FD9E6
        case "4": 0x91DEC4
        case "5": 0xFFE1A8
        case "6": 0xF4A6C0
        case "7": 0xBDB3F4
        case "W": 0xFFFFFF
        case "m": 0xF08DB3
        case "g": 0xC4EEF5
        case "u": 0xFFF1DC
        case "v": 0xF7B3CC
        case "x": 0x8FD9E6
        case "q": 0xE3F7FB
        case "s": 0xE9DCC8
        default: nil
        }
        return hex.map { Color(anchorHex: $0) }
    }
}
#endif
