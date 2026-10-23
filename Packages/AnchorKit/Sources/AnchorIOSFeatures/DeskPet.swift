#if os(iOS)
import AnchorDesign
import SwiftUI

/// Which pet keeps the landscape desk company; chosen in Settings.
enum DeskPetKind: String, CaseIterable, Identifiable {
    case crab
    case octopus
    case off

    static let defaultsKey = "anchor.desk.pet"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crab: AnchorStrings.value("settings.deskPet.crab", default: "Crab")
        case .octopus: AnchorStrings.value("settings.deskPet.octopus", default: "Octopus")
        case .off: AnchorStrings.value("settings.deskPet.off", default: "Off")
        }
    }
}

/// What the desk is doing, which is all the pet acts out.
enum DeskPetMood: Hashable {
    /// An agent runs: the pet types.
    case working
    /// Nothing runs and it is the person's move: the pet idles and sometimes walks.
    case yourMove
    /// Nothing has happened for a long while: the pet sleeps.
    case quiet
}

/// A small pixel pet at the foot of the desk clock. Its pose follows real
/// work only (typing while an agent runs, one wave per arriving result,
/// sleep after a long quiet); a tap makes it hop. Drawn at 8 fps from pixel
/// rectangles in harbor colors, never in state colors. With reduced motion it
/// holds still and only changes pose.
struct DeskPet: View {
    let kind: DeskPetKind
    let mood: DeskPetMood
    /// Rises by one for every result that arrives; each rise waves once.
    var waves = 0
    /// The Settings preview stays in place.
    var walks = true

    @AnchorReducedMotion private var reduceMotion
    @State private var pet = DeskPetState()
    @State private var columns = 0
    @State private var taps = 0

    /// Points per sprite pixel.
    static let pixel: CGFloat = 4
    /// Sprite rows plus room above for a hop and the sleep z's.
    static let rows = 15
    static let height = CGFloat(rows) * pixel

    var body: some View {
        Canvas { context, _ in
            draw(in: context)
        }
        .frame(height: Self.height)
        .onGeometryChange(for: Int.self) { Int($0.size.width / Self.pixel) } action: { columns = $0 }
        .contentShape(.rect)
        .onTapGesture {
            taps += 1
            pet.tap(mood: mood)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: taps)
        .onChange(of: waves) { old, new in
            if new > old, mood != .working { pet.wave() }
        }
        // Restarts on a new mood, so the loop never steps with a stale one.
        .task(id: Loop(still: reduceMotion, mood: mood)) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                pet.step(mood: mood, room: max(0, columns - sprite.width - 4), walks: walks)
                try? await Task.sleep(for: .milliseconds(125))
            }
        }
        .accessibilityHidden(true)
    }

    private struct Loop: Hashable {
        let still: Bool
        let mood: DeskPetMood
    }

    private var sprite: DeskPetSprite { kind == .octopus ? .octopus : .crab }

    private func draw(in context: GraphicsContext) {
        // Reduced motion: the pose follows the mood, with nothing that moves.
        let pose = reduceMotion ? DeskPetState.restingPose(for: mood) : pet.pose
        let frame = reduceMotion ? 0 : pet.tick
        let lift = reduceMotion ? 0 : DeskPetState.lift(pet.hop)
        let originX = min(pet.x, max(0, columns - sprite.width - 4))
        let originY = Self.rows - sprite.height - lift
        let pixels = DeskPetPixels(context: context, x: originX, y: originY)
        sprite.draw(pixels, pose: pose, frame: frame, eyesShut: !reduceMotion && pet.eyesShut)
        if pose == .sleep {
            let count = reduceMotion ? 3 : (pet.tick / 4) % 3 + 1
            for i in 0..<count {
                let point = CGPoint(x: CGFloat(originX + sprite.width + i * 2) * Self.pixel,
                                    y: CGFloat(originY - i * 2 + 1) * Self.pixel)
                context.draw(Text("z").font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AnchorIOSStyle.secondaryText), at: point, anchor: .bottomLeading)
            }
        }
    }
}

/// The pet's moment-to-moment behavior, one step per 8 fps tick.
struct DeskPetState {
    enum Pose { case idle, walk, type, wave, sleep }

    private(set) var tick = 0
    /// Left edge, in sprite pixels.
    private(set) var x = 0
    private(set) var pose = Pose.idle
    private(set) var hop = 0
    private var facing = 1
    private var poseUntil = 0
    private var squint = 0
    /// Ticks left awake after a tap woke it from sleep.
    private var awake = 0

    var eyesShut: Bool { squint > 0 || (pose != .sleep && tick % 30 == 7) }

    static func restingPose(for mood: DeskPetMood) -> Pose {
        switch mood {
        case .working: .type
        case .yourMove: .idle
        case .quiet: .sleep
        }
    }

    /// Hop height for the ticks left in a hop.
    static func lift(_ hop: Int) -> Int { [0, 1, 2, 2, 1][min(max(hop, 0), 4)] }

    mutating func step(mood: DeskPetMood, room: Int, walks: Bool) {
        tick += 1
        hop = max(0, hop - 1)
        squint = max(0, squint - 1)
        awake = max(0, awake - 1)
        x = min(x, room)
        if pose == .wave, tick < poseUntil { return }

        switch mood {
        case .working:
            pose = .type
        case .quiet where awake == 0:
            pose = .sleep
        case .yourMove, .quiet:
            if tick >= poseUntil || pose == .type || pose == .sleep || pose == .wave {
                // Mostly still; now and then a few steps sideways.
                pose = walks && Int.random(in: 0..<10) < 4 ? .walk : .idle
                poseUntil = tick + Int.random(in: 16...48)
                if Bool.random() { facing = -facing }
            }
        }

        guard pose == .walk else { return }
        if tick % 2 == 0 { x += facing }
        if x <= 0 { x = 0; facing = 1 }
        if x >= room { x = room; facing = -1 }
    }

    mutating func wave() {
        pose = .wave
        poseUntil = tick + 12
    }

    mutating func tap(mood: DeskPetMood) {
        hop = 4
        squint = 6
        if mood == .quiet {
            awake = 80
            pose = .idle
            poseUntil = tick + 16
        }
    }
}

/// Paints sprite-pixel rectangles at the pet's origin.
struct DeskPetPixels {
    let context: GraphicsContext
    let x: Int
    let y: Int

    func callAsFunction(_ px: Int, _ py: Int, _ width: Int, _ height: Int, _ color: Color) {
        let p = DeskPet.pixel
        context.fill(Path(CGRect(x: CGFloat(x + px) * p, y: CGFloat(y + py) * p,
                                 width: CGFloat(width) * p, height: CGFloat(height) * p)), with: .color(color))
    }
}

/// The two pets. Harbor colors only: red, amber and green carry state on the desk.
enum DeskPetSprite {
    case crab
    case octopus

    var width: Int { self == .crab ? 16 : 14 }
    var height: Int { 11 }

    private static let outline = Color(anchorHex: AnchorColorTokens.deepSea)
    private static let shine = Color(anchorHex: 0xFFFFFF)
    private static let seafoam = Color(anchorHex: AnchorColorTokens.seafoam)
    private static let seafoamLight = Color(anchorHex: 0xCFF5EA)
    private static let sea = Color(anchorHex: AnchorColorTokens.oceanSurface.light)
    private static let seaLight = Color(anchorHex: 0xC6F1FA)
    private static let laptop = Color(anchorHex: AnchorColorTokens.borderStrong.light)
    private static let laptopBase = Color(anchorHex: AnchorColorTokens.textSecondary.light)
    private static let laptopLogo = Color(anchorHex: AnchorColorTokens.brand.light)

    func draw(_ r: DeskPetPixels, pose: DeskPetState.Pose, frame: Int, eyesShut: Bool) {
        switch self {
        case .crab: Self.crab(r, pose: pose, frame: frame, eyesShut: eyesShut)
        case .octopus: Self.octopus(r, pose: pose, frame: frame, eyesShut: eyesShut)
        }
    }

    /// A square seafoam body on six legs, eyes on stalks, a claw each side.
    private static func crab(_ r: DeskPetPixels, pose: DeskPetState.Pose, frame: Int, eyesShut: Bool) {
        let k = outline
        let sleeping = pose == .sleep
        let sink = sleeping ? 1 : 0
        let stepping = pose == .walk && frame % 2 == 1
        for leg in stepping ? [3, 5, 10, 12] : [4, 6, 9, 11] { r(leg, 10, 1, 1, k) }
        r(3, 4 + sink, 10, 6, k)
        r(4, 5 + sink, 8, 4, seafoam)
        r(4, 5 + sink, 3, 1, seafoamLight)
        if sleeping {
            r(5, 6 + sink, 2, 1, k)
            r(9, 6 + sink, 2, 1, k)
        } else {
            r(5, 3, 1, 1, k)
            r(10, 3, 1, 1, k)
            eye(r, 5, 1, shut: eyesShut)
            eye(r, 9, 1, shut: eyesShut)
        }
        switch pose {
        case .type:
            r(4, 6, 8, 4, laptop)
            r(7, 7, 2, 2, laptopLogo)
            r(2, 10, 12, 1, laptopBase)
            let tap = frame % 2
            claw(r, 1, 5 + tap, open: false)
            claw(r, 12, 6 - tap, open: false)
        case .wave:
            let open = frame % 4 < 2
            claw(r, 0, 5, open: true)
            r(13, 4, 1, 1, k)
            claw(r, 13, open ? 1 : 2, open: open)
        default:
            claw(r, 0, 5 + sink, open: !sleeping)
            claw(r, 13, 5 + sink, open: !sleeping)
        }
    }

    /// A round sea-blue head with four short arms.
    private static func octopus(_ r: DeskPetPixels, pose: DeskPetState.Pose, frame: Int, eyesShut: Bool) {
        let k = outline
        let sleeping = pose == .sleep
        let y = sleeping ? 1 : 0
        r(4, 0 + y, 4, 1, k)
        r(2, 1 + y, 2, 1, k)
        r(8, 1 + y, 2, 1, k)
        r(4, 1 + y, 4, 1, sea)
        r(1, 2 + y, 1, 2, k)
        r(10, 2 + y, 1, 2, k)
        r(2, 2 + y, 8, 2, sea)
        r(0, 4 + y, 1, 4, k)
        r(11, 4 + y, 1, 4, k)
        r(1, 4 + y, 10, 4, sea)
        r(1, 8, 1, 1, k)
        r(10, 8, 1, 1, k)
        r(2, 8, 8, 1, sea)
        r(3, 2 + y, 2, 1, seaLight)
        r(2, 3 + y, 1, 1, seaLight)
        r(1, 9, 10, 1, sea)
        r(0, 9, 1, 1, k)
        r(11, 9, 1, 1, k)
        let stepping = pose == .walk && frame % 2 == 1
        for tip in stepping ? [2, 5, 6, 9] : [1, 4, 7, 10] { r(tip, 10, 1, 1, k) }
        if sleeping {
            r(3, 6, 2, 1, k)
            r(7, 6, 2, 1, k)
        } else if eyesShut {
            r(3, 6, 1, 1, k)
            r(8, 6, 1, 1, k)
        } else {
            r(3, 5, 1, 2, k)
            r(8, 5, 1, 2, k)
            r(3, 5, 1, 1, shine)
            r(8, 5, 1, 1, shine)
        }
        switch pose {
        case .type:
            r(2, 6, 8, 4, laptop)
            r(5, 7, 2, 2, laptopLogo)
            r(0, 10, 12, 1, laptopBase)
            for (i, tip) in [1, 3, 8, 10].enumerated() { r(tip, 5 + (i + frame) % 2, 1, 1, k) }
        case .wave:
            let raise = frame % 4 < 2 ? 0 : 1
            r(12, 6, 1, 1, sea)
            r(12, 5, 1, 1, sea)
            r(13, 4 - raise, 1, 1, sea)
            r(13, 3 - raise, 1, 1, k)
        default:
            break
        }
    }

    private static func eye(_ r: DeskPetPixels, _ x: Int, _ y: Int, shut: Bool) {
        if shut {
            r(x, y + 1, 2, 1, outline)
        } else {
            r(x, y, 2, 2, outline)
            r(x, y, 1, 1, shine)
        }
    }

    private static func claw(_ r: DeskPetPixels, _ x: Int, _ y: Int, open: Bool) {
        r(x, y, 1, 1, outline)
        r(x + 2, y, 1, 1, outline)
        if !open { r(x + 1, y, 1, 1, outline) }
        r(x, y + 1, 1, 1, outline)
        r(x + 1, y + 1, 1, 1, seafoam)
        r(x + 2, y + 1, 1, 1, outline)
        r(x, y + 2, 3, 1, outline)
    }
}
#endif
