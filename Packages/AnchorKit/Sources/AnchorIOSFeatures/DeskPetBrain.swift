#if os(iOS)
import Foundation

/// Everything a pet can be doing. Desk events and touches start acts; the
/// rest is daily life, picked by weight when nothing else is going on.
enum DeskPetAct: String, CaseIterable, Sendable {
    // Daily life
    case idle, move, look, yawn, stretch, nap, sleep, coffee
    // Desk events
    case type, celebrate, wave, fail, think
    // Touch
    case happy, petted, startled, angry, sulk, flee, dizzy, hide, peek, zap
    // Each pet's own
    case build, snap, dance, shades, dash, juggle, read, ink, pebble, polish, glow, meditate, sway

    /// Acts that travel to a target column.
    var travels: Bool { [.move, .flee, .dash, .pebble].contains(self) }
}

/// What the desk tells the pet, as it happens.
enum DeskPetEvent: Sendable {
    case result, failure, question
}

/// One pet's character. Never shown in the app; the owner finds it out.
struct DeskPetNature: Sendable {
    /// How quickly poking turns into anger.
    let temper: Double
    /// How easily it is frightened.
    let timidity: Double
    /// Ticks between steps, and pixels per step, when it travels.
    let stepEvery: Int
    let stepSize: Int
    /// Daily acts and how often each is picked.
    let routine: [(DeskPetAct, Double)]
    /// The big acts; at most one every few minutes.
    let signature: Set<DeskPetAct>

    static func of(_ kind: DeskPetKind) -> DeskPetNature {
        switch kind {
        case .crab, .off:
            // A busy worker with a short fuse.
            DeskPetNature(temper: 0.9, timidity: 0.1, stepEvery: 2, stepSize: 1,
                          routine: [(.idle, 40), (.move, 26), (.look, 8), (.stretch, 5), (.snap, 8), (.build, 6)],
                          signature: [.build, .snap])
        case .squid:
            // A show-off with energy to spare.
            DeskPetNature(temper: 0.3, timidity: 0.1, stepEvery: 1, stepSize: 1,
                          routine: [(.idle, 30), (.move, 20), (.dash, 10), (.look, 8), (.dance, 8), (.shades, 6), (.wave, 4)],
                          signature: [.dance, .shades, .dash])
        case .octopus:
            // Shy and warm.
            DeskPetNature(temper: 0.2, timidity: 0.6, stepEvery: 3, stepSize: 1,
                          routine: [(.idle, 40), (.move, 22), (.look, 10), (.juggle, 7), (.read, 7), (.yawn, 4)],
                          signature: [.juggle, .read])
        case .hermit:
            // Timid, slow, a collector.
            DeskPetNature(temper: 0.1, timidity: 0.95, stepEvery: 4, stepSize: 1,
                          routine: [(.idle, 44), (.move, 18), (.look, 12), (.pebble, 6), (.polish, 6), (.hide, 4)],
                          signature: [.pebble, .polish])
        case .jelly:
            // Calm and dreamy; it drifts rather than walks.
            DeskPetNature(temper: 0.4, timidity: 0.3, stepEvery: 3, stepSize: 1,
                          routine: [(.idle, 36), (.move, 26), (.glow, 10), (.sway, 8), (.meditate, 6), (.yawn, 4)],
                          signature: [.meditate, .sway])
        }
    }
}

/// A pet's life, one step per 8 fps tick. Three layers, highest first:
/// desk events, touch, then daily life. Slow needs (energy, boredom,
/// annoyance, trust) decide which act a moment turns into, so the same tap
/// can get a different answer.
struct DeskPetBrain {
    let kind: DeskPetKind
    let nature: DeskPetNature

    private(set) var tick = 0
    private(set) var act = DeskPetAct.idle
    private(set) var actStart = 0
    private(set) var actEnd = 24
    /// Left edge, in sprite pixels.
    private(set) var x = 0
    private(set) var facing = 1

    /// Falls slowly while awake and refills in sleep.
    private(set) var energy = 1.0
    /// Builds while idle and makes play acts likelier.
    private(set) var boredom = 0.0
    /// Rises with poking and cools within a minute.
    private(set) var annoyance = 0.0
    /// Grows with gentle touches, kept across launches.
    private(set) var trust: Double

    private var mood = DeskPetMood.yourMove
    private var hour = 12
    private var room = 0
    private var target = 0
    private var taps: [Int] = []
    private var then: DeskPetAct?
    private var lastBig = -10_000
    private var ignoreUntil = 0
    private var awakeUntil = 0
    private var hadCoffee = false
    private var random: DeskPetRandom

    /// Taps closer together than this count as one burst.
    static let burst = 12
    /// At most one signature act this often.
    static let bigGap = 1_440

    init(kind: DeskPetKind, trust: Double = 0.3, seed: UInt64 = .random(in: 1...UInt64.max)) {
        self.kind = kind
        nature = .of(kind)
        self.trust = trust
        random = DeskPetRandom(seed: seed)
    }

    var progress: Int { tick - actStart }
    var length: Int { max(1, actEnd - actStart) }
    var sleeping: Bool { act == .sleep || act == .nap }

    // MARK: Inputs

    mutating func set(mood newMood: DeskPetMood, hour newHour: Int) {
        hour = newHour
        guard newMood != mood else { return }
        let old = mood
        mood = newMood
        switch newMood {
        case .working:
            start(sleeping ? .yawn : .type, then: sleeping ? .type : nil)
        case .yourMove where old == .working:
            start(.stretch)
        case .quiet, .yourMove:
            break
        }
    }

    /// A desk event always wins over whatever the pet is doing.
    mutating func hear(_ event: DeskPetEvent) {
        awakeUntil = tick + 120
        switch event {
        case .result:
            switch kind {
            case .octopus, .hermit: start(.wave)
            case .jelly: start(.glow, then: .wave)
            case .crab, .squid, .off: start(.celebrate)
            }
        case .failure:
            switch kind {
            case .crab: start(.angry)
            case .hermit: start(.hide, for: 48, then: .peek)
            case .octopus: start(.startled, then: .fail)
            case .squid, .jelly, .off: start(.fail)
            }
        case .question:
            start(.think, then: .wave)
        }
    }

    mutating func tap() {
        taps = taps.filter { tick - $0 < Self.burst } + [tick]
        let burst = taps.count
        annoyance = min(1, annoyance + 0.1 + nature.temper * 0.12)
        trust = burst >= 3 ? max(0, trust - 0.01) : (annoyance < 0.3 ? min(1, trust + 0.004) : trust)
        guard tick >= ignoreUntil else { return }

        if sleeping {
            awakeUntil = tick + 120
            if nature.timidity > 0.6 { start(.startled) }
            else if nature.temper > 0.6 { start(.angry, for: 12) }
            else { start(.yawn) }
            return
        }
        if act == .hide {
            // Poking a hidden hermit only keeps it inside.
            actEnd = max(actEnd, tick + 24)
            return
        }

        switch kind {
        case .crab, .off:
            if burst >= 3 || annoyance > 0.6 {
                if act != .angry && act != .sulk { start(.angry, then: annoyance > 0.85 ? .sulk : nil) }
            } else {
                start(annoyance < 0.35 ? .happy : .snap)
            }
        case .squid:
            if annoyance > 0.9 { start(.dizzy) }
            else if burst >= 3 { if act != .dance { start(.dance) } }
            else { start(chance(0.5) ? .happy : .wave) }
        case .octopus:
            if burst >= 3 || annoyance > 0.7 {
                if act != .ink && act != .flee { start(.ink, then: .flee) }
            } else if burst == 2 {
                start(.startled)
            } else {
                start(.petted)
            }
        case .hermit:
            if burst >= 2 || annoyance > 0.4 || trust < 0.2 {
                // Longer inside when poked hard; shorter once it trusts you.
                let stay = 40 + Int(annoyance * 80) - Int(trust * 40)
                start(.hide, for: max(24, stay), then: .peek)
            } else {
                start(trust > 0.5 ? .happy : .startled)
            }
        case .jelly:
            if burst >= 4 {
                ignoreUntil = tick + 80
                start(.zap, then: .flee)
            } else {
                start(.happy)
            }
        }
    }

    /// The person touched the pet's own thing in its nook: it walks over and
    /// uses it, waking first if it slept.
    mutating func visit(_ column: Int, then next: DeskPetAct) {
        awakeUntil = tick + 120
        guard !(act == .hide || act == .angry || act == .sulk) else { return }
        act = .move
        actStart = tick
        then = next
        target = min(max(0, column), room)
        facing = target >= x ? 1 : -1
        actEnd = tick + 160
    }

    /// A long press: petting. It calms, and trust grows.
    mutating func press() {
        trust = min(1, trust + 0.03)
        annoyance = max(0, annoyance - 0.5)
        ignoreUntil = 0
        if act == .hide { start(.peek, then: .petted) } else { start(.petted) }
    }

    // MARK: Time

    mutating func step(room newRoom: Int) {
        tick += 1
        room = max(0, newRoom)
        x = min(x, room)
        annoyance = max(0, annoyance - 0.004)
        energy = sleeping ? min(1, energy + 0.002) : max(0, energy - 0.00001)
        boredom = act == .idle ? min(1, boredom + 0.002) : max(0, boredom - 0.001)

        if act.travels { walk() }
        if tick >= actEnd { finish() }
    }

    private mutating func walk() {
        let speed = act == .dash || act == .flee ? max(1, nature.stepEvery / 2) : nature.stepEvery
        guard tick % speed == 0 else { return }
        let size = act == .dash || act == .flee ? nature.stepSize * 2 : nature.stepSize
        if x == target {
            actEnd = tick
            return
        }
        facing = target > x ? 1 : -1
        x = target > x ? min(target, x + size) : max(target, x - size)
    }

    private mutating func finish() {
        if let next = then {
            then = nil
            start(next)
        } else {
            start(choose())
        }
    }

    private mutating func choose() -> DeskPetAct {
        switch mood {
        case .working:
            return act == .type && chance(0.2) ? (chance(0.5) ? .look : .stretch) : .type
        case .quiet where tick >= awakeUntil:
            return .sleep
        case .quiet, .yourMove:
            break
        }
        if (6..<10).contains(hour), !hadCoffee {
            hadCoffee = true
            return .coffee
        }
        if energy < 0.25, chance(0.3) { return .nap }

        let late = hour >= 23 || hour < 5
        let bigReady = tick - lastBig >= Self.bigGap
        let options = nature.routine.compactMap { option -> (DeskPetAct, Double)? in
            let (candidate, weight) = option
            if nature.signature.contains(candidate) {
                return bigReady ? (candidate, weight * (1 + boredom * 2)) : nil
            }
            if candidate == .yawn || candidate == .stretch { return (candidate, late ? weight * 3 : weight) }
            return option
        }
        let total = options.reduce(0) { $0 + $1.1 }
        var roll = random.unit() * total
        for (candidate, weight) in options {
            roll -= weight
            if roll <= 0 { return candidate }
        }
        return .idle
    }

    private mutating func start(_ next: DeskPetAct, for ticks: Int? = nil, then follow: DeskPetAct? = nil) {
        act = next
        actStart = tick
        // Whatever sent it into its shell, it peeks before coming out.
        then = follow ?? (next == .hide ? .peek : nil)
        if nature.signature.contains(next) {
            lastBig = tick
            boredom = 0
        }
        if next.travels {
            target = destination(for: next)
            facing = target >= x ? 1 : -1
        }
        actEnd = tick + (ticks ?? duration(of: next))
    }

    private mutating func destination(for next: DeskPetAct) -> Int {
        guard room > 0 else { return 0 }
        switch next {
        case .flee:
            return x > room / 2 ? 0 : room
        case .dash:
            return x > room / 2 ? random.int(in: 0...max(0, room / 4)) : random.int(in: (room * 3 / 4)...room)
        default:
            var spot = random.int(in: 0...room)
            if abs(spot - x) < 4 { spot = x > room / 2 ? max(0, x - 6) : min(room, x + 6) }
            return spot
        }
    }

    private mutating func duration(of next: DeskPetAct) -> Int {
        switch next {
        case .idle: random.int(in: 16...48)
        case .move, .flee, .dash, .pebble: 160
        case .look: random.int(in: 12...20)
        case .yawn, .happy: 12
        case .stretch, .peek: 16
        case .nap: random.int(in: 160...320)
        case .sleep: 80
        case .coffee, .think, .build, .shades, .juggle: 48
        case .type: random.int(in: 60...160)
        case .celebrate, .wave, .snap: 16
        case .fail: 28
        case .petted, .ink: 20
        case .startled, .zap: 12
        case .angry, .dizzy, .polish: 24
        case .sulk: 48
        case .hide: 56
        case .dance, .sway: 40
        case .read, .meditate: 64
        case .glow: 32
        }
    }

    private mutating func chance(_ p: Double) -> Bool { random.unit() < p }
}

/// A small seeded generator, so tests can replay a pet's day.
struct DeskPetRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}
#endif
