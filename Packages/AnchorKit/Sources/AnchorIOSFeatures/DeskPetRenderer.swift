#if os(iOS)
import AnchorDesign
import SwiftUI

/// One moment of a pet, enough to draw it.
struct DeskPetFrame {
    var act = DeskPetAct.idle
    var progress = 0
    var length = 1
    var tick = 0
    var facing = 1
    /// Reduced motion: hold the pose, no blinks or wiggles.
    var still = false
}

/// Draws a pet from its look and the act it is in: a pose (offset, eyes,
/// arm, turned away, hidden) and the props the act brings (laptop, hard hat,
/// headphones, glasses, bubbles, a cup, a bulb, z's, hearts, notes).
struct DeskPetRenderer {
    let look: DeskPetLook
    let kind: DeskPetKind
    let context: GraphicsContext
    /// Canvas column of the sprite's left edge and row of its feet.
    let left: Int
    let ground: Int
    let pixel: CGFloat

    private enum Eyes { case open, shut, happy, cross, left, right, angry }

    private struct Pose {
        var dx = 0
        var dy = 0
        var eyes = Eyes.open
        var back = false
        var hidden = false
        var peek = false
        var armUp = false
        var stepping = false
        var glow = 0
        var curlStrand = false
    }

    func draw(_ frame: DeskPetFrame) {
        let pose = pose(for: frame)
        let flip = kind == .hermit && frame.facing < 0
        let top = ground - look.height + 1 + pose.dy
        let paint = Painter(context: context, left: left + pose.dx, top: top, width: look.width,
                            flip: flip, pixel: pixel)

        if !look.strands.isEmpty, !pose.hidden { strands(paint, frame, pose) }
        body(paint, frame, pose)
        if !pose.hidden { eyes(paint, pose.eyes) }
        if pose.armUp, !look.raised.isEmpty {
            let wiggle = frame.still ? 0 : (frame.tick / 2) % 2
            paint.grid(look.raised, at: look.raisedAt.x + wiggle, look.raisedAt.y) { look.color($0) }
        }
        props(paint, frame, pose)
    }

    // MARK: Pose

    private func pose(for frame: DeskPetFrame) -> Pose {
        var pose = Pose()
        let k = frame.progress, t = frame.tick
        let hop = [0, -1, -2, -3, -3, -2, -1, 0]
        if kind == .jelly { pose.dy = frame.still ? -2 : -2 + Int((sin(Double(t) / 7) * 1.4).rounded()) }

        switch frame.act {
        case .idle, .coffee, .type, .shades, .juggle, .read, .think, .build:
            break
        case .move, .pebble:
            pose.stepping = true
        case .flee, .dash:
            pose.stepping = true
            if kind == .squid { pose.eyes = .happy }
        case .look:
            pose.eyes = k < frame.length / 2 ? .left : .right
        case .yawn:
            pose.eyes = .shut
        case .stretch:
            pose.armUp = true
            pose.dy -= k > 3 && k < 12 ? 1 : 0
        case .nap, .sleep:
            pose.eyes = .shut
            pose.dy = kind == .jelly ? 0 : 1
        case .celebrate:
            pose.dy += hop[k % 8]
            pose.eyes = .happy
        case .wave:
            pose.armUp = true
            pose.eyes = .happy
            pose.curlStrand = true
        case .fail:
            pose.eyes = .cross
            pose.dy += 1
        case .happy:
            pose.dy += kind == .jelly ? -min(k, 4) : hop[min(k, 7)]
            pose.eyes = .happy
        case .petted:
            pose.eyes = .happy
        case .startled:
            pose.dx = k % 2 == 0 ? 1 : -1
            pose.dy -= k < 3 ? 1 : 0
        case .angry:
            pose.eyes = .angry
            pose.dx = (k / 2) % 2 == 0 ? 1 : 0
            pose.armUp = kind == .crab && (k / 3) % 2 == 0
        case .sulk:
            pose.back = true
        case .dizzy:
            pose.eyes = .cross
            pose.dx = [0, 1, 1, 0, -1, -1][(k / 2) % 6]
        case .hide:
            pose.hidden = true
        case .peek:
            pose.hidden = k < frame.length / 2
            pose.peek = pose.hidden
        case .zap:
            pose.eyes = .shut
            pose.glow = 2
        case .snap:
            pose.armUp = (k / 2) % 2 == 0
            pose.eyes = .happy
        case .dance:
            pose.dx = [0, 1, 2, 1, 0, -1, -2, -1][(k / 2) % 8]
            pose.dy += k % 4 < 2 ? -1 : 0
            pose.eyes = .happy
            pose.armUp = (k / 4) % 2 == 0
        case .ink:
            pose.eyes = .shut
            pose.dx = min(4, k / 3) * (frame.facing < 0 ? -1 : 1)
        case .polish:
            pose.armUp = (k / 3) % 2 == 0
            pose.eyes = .happy
        case .glow:
            pose.glow = k % 16 < 8 ? 1 : 2
            pose.eyes = .happy
        case .meditate:
            pose.eyes = .shut
            pose.dy = -3 - Int((sin(Double(k) / 10) * 1.5).rounded())
        case .sway:
            pose.dx = [0, 1, 1, 0, -1, -1][(k / 3) % 6]
            pose.eyes = .happy
        }
        if frame.still {
            pose.dx = 0
            pose.stepping = false
        } else if pose.eyes == .open, (t + kind.rawValue.count * 7) % 36 == 0 {
            pose.eyes = .shut
        }
        return pose
    }

    // MARK: Body

    private func body(_ paint: Painter, _ frame: DeskPetFrame, _ pose: Pose) {
        let lift = (frame.tick / 2) % 2
        for (y, row) in look.rows.enumerated() {
            for (x, c) in row.enumerated() where c != "." {
                if pose.hidden {
                    guard look.shell.contains(c) else { continue }
                    // The shell sinks to the ground with everything tucked in.
                    let drop = look.rows.count - 1 - look.shellBottom
                    paint.dot(x, y + drop, look.color(c))
                    continue
                }
                if pose.armUp, c == "R" { continue }
                var letter = c
                if pose.back, c == "e" || c == "E" || look.face.contains(c) { letter = look.backOfHead ?? look.lid }
                var dy = 0
                if pose.stepping, y >= look.feetFrom { dy = (x < look.width / 2) == (lift == 0) ? -1 : 0 }
                var color = look.color(letter)
                if pose.glow > 0, letter == look.lid {
                    color = Color(anchorHex: pose.glow == 1 ? 0xDDF7FB : 0xF4FDFE)
                }
                paint.dot(x, y + dy, color)
            }
        }
        if pose.peek {
            let drop = look.rows.count - 1 - look.shellBottom
            for eye in look.peekEyes { paint.dot(eye.x, eye.y + drop, DeskPetLook.ink) }
        }
    }

    private func strands(_ paint: Painter, _ frame: DeskPetFrame, _ pose: Pose) {
        let color = Color(anchorHex: look.strandColor)
        let base = look.rows.count
        let still = frame.still || frame.act == .meditate || frame.act == .fail
        for (i, column) in look.strands.enumerated() {
            if pose.curlStrand, i == look.strands.count - 1 {
                for cell in look.curl { paint.dot(cell.x, cell.y, color) }
                continue
            }
            for r in 0..<look.strandLength {
                let sway = still ? 0 : ((r + frame.tick / 3 + i * 2) % 6 < 3 ? 0 : 1)
                let droop = frame.act == .fail ? 0 : sway
                paint.dot(column + droop, base + r, color)
            }
        }
    }

    private func eyes(_ paint: Painter, _ style: Eyes) {
        guard style != .open else { return }
        let lid = look.color(look.lid)
        let ink = DeskPetLook.ink
        for (i, box) in look.eyes.enumerated() {
            if style == .angry {
                // Brows slanting down toward the middle.
                let inner = i == 0 ? box.x1 : box.x0, outer = i == 0 ? box.x0 : box.x1
                paint.dot(outer, box.y0 - 2, ink)
                paint.dot(inner, box.y0 - 1, ink)
                continue
            }
            for y in box.y0...box.y1 { for x in box.x0...box.x1 { paint.dot(x, y, lid) } }
            switch style {
            case .shut:
                for x in box.x0...box.x1 { paint.dot(x, box.y1, ink) }
            case .happy:
                // A three-pixel ^ per eye, a smile with the eyes.
                let x = i == 0 ? box.x0 - 1 : box.x0
                paint.dot(x, box.y0 + 1, ink)
                paint.dot(x + 1, box.y0, ink)
                paint.dot(x + 2, box.y0 + 1, ink)
            case .cross:
                let cx = box.x0, cy = box.y0
                for (x, y) in [(cx - 1, cy), (cx + 1, cy), (cx, cy + 1), (cx - 1, cy + 2), (cx + 1, cy + 2)] {
                    paint.dot(x, y, ink)
                }
            case .left, .right:
                for y in box.y0...box.y1 { for x in box.x0...box.x1 { paint.dot(x, y, ink) } }
                paint.dot(style == .left ? box.x0 : box.x1, box.y0, DeskPetLook.white)
            case .open, .angry:
                break
            }
        }
    }

    // MARK: Props

    private func props(_ paint: Painter, _ frame: DeskPetFrame, _ pose: Pose) {
        let k = frame.progress, t = frame.tick
        let w = look.width, cx = look.width / 2, h = look.height
        switch frame.act {
        case .type:
            paint.grid(Prop.laptop, at: cx - 6, h - 4, Prop.color)
            if !frame.still, t % 2 == 0 { paint.dot(cx - 3 + (t / 2) % 6, h - 5, Prop.color("c")) }
        case .nap, .sleep:
            let count = frame.still ? 3 : (k / 6) % 3 + 1
            for i in 0..<count { paint.glyph(Prop.z, at: w - 1 + i * 3, -1 - i * 4, Prop.color) }
        case .coffee:
            paint.grid(Prop.mug, at: look.hand.x, look.hand.y - 2, Prop.color)
            if (k / 3) % 2 == 0 { paint.dot(look.hand.x + 1, look.hand.y - 4, Prop.color("g")) }
            else { paint.dot(look.hand.x + 2, look.hand.y - 5, Prop.color("g")) }
        case .celebrate:
            for i in 0..<7 {
                let colors: [Character] = ["s", "c", "v", "h", "w"]
                paint.dot((i * 7 + k * 2) % (w + 6) - 3, (i * 5 + k) % 9 - 6, Prop.color(colors[i % colors.count]))
            }
        case .fail:
            paint.glyph(Prop.bang, at: w, 0, Prop.color)
            paint.glyph(Prop.drop, at: w - 3, 2, Prop.color)
        case .think:
            if k > 6 { paint.glyph(Prop.bulb, at: cx - 2, -8, Prop.color) }
        case .petted:
            paint.glyph(Prop.heart, at: cx + 3, -3 - min(k / 3, 4), Prop.color)
        case .startled, .flee, .ink:
            paint.glyph(Prop.drop, at: w - 3, 1, Prop.color)
            if frame.act == .ink {
                let r = min(5, 1 + k / 3)
                // The puff stays behind as it scoots off, on the side with room.
                for i in 0..<r { for j in 0..<r where (i + j + k) % 3 != 0 {
                    paint.dot(w + i, h - 1 - j, DeskPetLook.ink)
                } }
            }
        case .angry:
            let rise = (k % 8) / 2
            paint.glyph(Prop.puff, at: 1, -2 - rise, Prop.color)
            paint.glyph(Prop.puff, at: w - 4, -3 - (rise + 2) % 4, Prop.color)
        case .dizzy:
            for i in 0..<3 {
                let a = Double(k + i * 4) / 3
                paint.dot(cx + Int((cos(a) * 7).rounded()), -2 + Int((sin(a) * 2).rounded()), Prop.color("w"))
            }
        case .zap:
            for i in 0..<6 {
                let a = Double(k * 2 + i * 3)
                paint.dot(cx + Int((cos(a) * 12).rounded()), h / 2 + Int((sin(a) * 7).rounded()),
                          Prop.color(i % 2 == 0 ? "w" : "c"))
            }
        case .build:
            paint.grid(Prop.hardHat, at: cx - 5, look.crown - 3, Prop.color)
            paint.grid((k / 4) % 2 == 0 ? Prop.hammerUp : Prop.hammerDown, at: look.hand.x, look.hand.y - 1, Prop.color)
        case .dance:
            headphones(paint)
            paint.glyph(Prop.note, at: w + 1, 2 - (k % 16) / 4, Prop.color)
        case .sway:
            headphones(paint)
            paint.glyph(Prop.note, at: w, 1 - (k % 16) / 4, Prop.color)
        case .shades:
            shades(paint)
        case .juggle:
            for i in 0..<3 {
                let a = Double(k) / 4 + Double(i) * 2.1
                paint.grid(Prop.bubble, at: cx - 1 + Int((cos(a) * 6).rounded()), -5 + Int((sin(a) * 3).rounded()), Prop.color)
            }
        case .read:
            glasses(paint)
            if let eye = look.eyes.first { paint.grid(Prop.book, at: cx - 4, eye.y1 + 3, Prop.color) }
        case .pebble:
            paint.grid(Prop.pebble, at: look.hand.x, look.hand.y, Prop.color)
        case .polish:
            if (k / 3) % 2 == 0 { paint.glyph(Prop.sparkle, at: w / 2 + 2, 2 + (k / 6) % 3, Prop.color) }
        case .glow, .meditate:
            if frame.act == .glow, (k / 4) % 2 == 0 { paint.glyph(Prop.sparkle, at: w - 2, 0, Prop.color) }
        case .idle, .move, .look, .yawn, .stretch, .wave, .happy, .sulk, .hide, .peek, .snap, .dash:
            break
        }
    }

    private func headphones(_ paint: Painter) {
        let band = Prop.color("t"), (l, r, y) = look.ears
        // The band hugs the head: one pixel outside its outline, row by row.
        let top = max(0, look.crown)
        if let first = look.rows[top].firstIndex(where: { $0 != "." }),
           let last = look.rows[top].lastIndex(where: { $0 != "." }) {
            let from = look.rows[top].distance(from: look.rows[top].startIndex, to: first)
            let to = look.rows[top].distance(from: look.rows[top].startIndex, to: last)
            for x in from...to { paint.dot(x, top - 1, band) }
        }
        for row in top..<min(y, look.rows.count) {
            let line = Array(look.rows[row])
            guard let first = line.firstIndex(where: { $0 != "." }),
                  let last = line.lastIndex(where: { $0 != "." }) else { continue }
            paint.dot(first - 1, row, band)
            paint.dot(last + 1, row, band)
        }
        for yy in y...(y + 2) { paint.dot(l - 1, yy, band); paint.dot(l, yy, band); paint.dot(r, yy, band); paint.dot(r + 1, yy, band) }
    }

    private func shades(_ paint: Painter) {
        let boxes = look.eyes
        guard boxes.count == 2 else { return }
        for box in boxes {
            for y in box.y0...box.y1 { for x in (box.x0 - 1)...(box.x1 + 1) { paint.dot(x, y, DeskPetLook.ink) } }
            paint.dot(box.x0, box.y0, DeskPetLook.white)
        }
        for x in stride(from: boxes[0].x1 + 2, through: boxes[1].x0 - 2, by: 1) { paint.dot(x, boxes[0].y0, DeskPetLook.ink) }
    }

    private func glasses(_ paint: Painter) {
        let boxes = look.eyes
        guard boxes.count == 2 else { return }
        for box in boxes {
            for x in (box.x0 - 1)...(box.x1 + 1) { paint.dot(x, box.y0 - 1, DeskPetLook.ink); paint.dot(x, box.y1 + 1, DeskPetLook.ink) }
            for y in (box.y0 - 1)...(box.y1 + 1) { paint.dot(box.x0 - 1, y, DeskPetLook.ink); paint.dot(box.x1 + 1, y, DeskPetLook.ink) }
        }
        for x in stride(from: boxes[0].x1 + 2, through: boxes[1].x0 - 2, by: 1) { paint.dot(x, boxes[0].y0, DeskPetLook.ink) }
    }
}

/// Paints sprite pixels, mirrored when the pet faces left.
private struct Painter {
    let context: GraphicsContext
    let left: Int
    let top: Int
    let width: Int
    let flip: Bool
    let pixel: CGFloat

    func dot(_ x: Int, _ y: Int, _ color: Color?) {
        guard let color else { return }
        let column = flip ? width - 1 - x : x
        context.fill(Path(CGRect(x: CGFloat(left + column) * pixel, y: CGFloat(top + y) * pixel,
                                 width: pixel, height: pixel)), with: .color(color))
    }

    /// A patch that turns with the pet (arms, held things).
    func grid(_ rows: [String], at x: Int, _ y: Int, _ color: (Character) -> Color?) {
        for (r, row) in rows.enumerated() {
            for (c, letter) in row.enumerated() where letter != "." { dot(x + c, y + r, color(letter)) }
        }
    }

    /// A symbol that keeps reading the right way (z, !, a note): only its place turns.
    func glyph(_ rows: [String], at x: Int, _ y: Int, _ color: (Character) -> Color?) {
        let span = rows.first?.count ?? 0
        let start = flip ? width - x - span : x
        for (r, row) in rows.enumerated() {
            for (c, letter) in row.enumerated() where letter != "." {
                guard let fill = color(letter) else { continue }
                context.fill(Path(CGRect(x: CGFloat(left + start + c) * pixel, y: CGFloat(top + y + r) * pixel,
                                         width: pixel, height: pixel)), with: .color(fill))
            }
        }
    }
}

/// Small pixel props in harbor colors.
private enum Prop {
    static let laptop = [".GGGGGGGGGG.", ".GGGGccGGGG.", ".GGGGGGGGGG.", "DDDDDDDDDDDD"]
    static let z = ["zzzz", "..z.", ".z..", "zzzz"]
    static let mug = ["WWWW.", "WWWWW", "WWW.W", "WWWW.", ".WW.."]
    static let bang = ["k", "k", "k", ".", "k"]
    static let drop = [".c", "cc", "cc"]
    static let bulb = [".YYY.", "YYYYY", "YYYYY", ".YYY.", ".GGG.", "..G.."]
    static let heart = ["hh.hh", "hhhhh", ".hhh.", "..h.."]
    static let puff = [".g.", "ggg"]
    static let note = ["..t", "..t", "ttt", "tt."]
    static let hardHat = ["...WWWW...", "..WWWtWW..", ".WWWWtWWW.", "WWWWWWWWWW"]
    static let hammerUp = ["GGG", ".D.", ".D.", ".D."]
    static let hammerDown = ["...G", "DDDG", "...G"]
    static let bubble = [".b.", "b.b", ".b."]
    static let book = ["vwwwvwwwv", "vwwwvwwwv", "vvvvvvvvv"]
    static let pebble = [".G.", "GGG"]
    static let sparkle = [".w.", "wcw", ".w."]

    static func color(_ c: Character) -> Color? {
        switch c {
        case "G": Color(anchorHex: 0x9AAAB6)
        case "D": Color(anchorHex: AnchorColorTokens.textSecondary.light)
        case "c": Color(anchorHex: AnchorColorTokens.brand.light)
        case "t": Color(anchorHex: 0x289CB8)
        case "z", "g": Color(anchorHex: 0x9AAAB6)
        case "W", "w": Color(anchorHex: 0xFFFFFF)
        case "k": Color(anchorHex: AnchorColorTokens.deepSea)
        case "Y": Color(anchorHex: 0xFFF2B3)
        case "h": Color(anchorHex: 0xF08DB3)
        case "b": Color(anchorHex: 0x8FD9E6)
        case "v": Color(anchorHex: 0x9A8BE8)
        case "s": Color(anchorHex: AnchorColorTokens.seafoam)
        default: nil
        }
    }
}
#endif
