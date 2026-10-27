#if os(iOS)
import Foundation

/// The small things a pet sets out to do, roughly every ten minutes. Each is a
/// short plan of a few steps (walk over, look, do it, settle), picked by how
/// much it makes sense right now: its needs, its nook, the person's work, its
/// nature and what it has learned the person likes. The last four are never
/// picked at random; the day or the person brings them on.
enum DeskPetIntent: String, CaseIterable, Sendable {
    case wander, glance, stretch, show, own, plant, lamp, blinds, window, screen, nap, coffee, find, greet, nudge
    case bedtime, celebrate, welcome, milestone

    static let chosen: [DeskPetIntent] = [
        .wander, .glance, .stretch, .show, .own, .plant, .lamp, .blinds, .window, .screen, .nap, .coffee, .find,
        .greet, .nudge,
    ]

    /// Gentle enough to do beside a running agent.
    var quiet: Bool { [.glance, .stretch, .screen, .nap, .coffee, .nudge, .show, .lamp].contains(self) }
}

/// One step of a plan.
enum DeskPetStep: Equatable, Sendable {
    /// Walk to a column in the nook; skipped when it has no room to walk.
    case go(Int, DeskPetGait = .walk)
    case act(DeskPetAct, ticks: Int? = nil)
    case face(Int)
    case effect(DeskPetEffect)
}

enum DeskPetGait: Sendable {
    case walk, carry, dash
}

/// What a step changes in the pet's world.
enum DeskPetEffect: Equatable, Sendable {
    case lamp(Bool), blinds(Bool), screensaver(Bool)
    case water, keep, coffee, goal, star, own
}

/// Everything a choice depends on, as one value.
struct DeskPetSituation {
    let kind: DeskPetKind
    let nature: DeskPetNature
    let memory: DeskPetMemory
    let context: DeskPetContext
    let now: Date
    let hour: Int
    let room: Int?
    let width: Int
    let x: Int
    let last: DeskPetIntent?
    /// Seconds since the person last touched it.
    let sinceTouch: TimeInterval
    /// An agent stopped running in the last few minutes.
    let justWorked: Bool

    var nook: Bool { room != nil }
    var today: Date { Calendar.current.startOfDay(for: now) }
    var dark: Bool { hour >= 18 || hour < 7 }
    var lampOn: Bool { memory.lampOn ?? dark }
    var late: Bool { hour >= 22 || hour < 2 }
    var cactus: Bool { kind == .hermit }

    var dry: Bool {
        guard let watered = memory.wateredAt else { return true }
        return now.timeIntervalSince(watered) > (cactus ? 4 : 0.85) * 86_400
    }

    /// Days the plant has gone without water, for how much it pulls.
    var daysDry: Double {
        guard let watered = memory.wateredAt else { return 1 }
        return now.timeIntervalSince(watered) / 86_400
    }

    /// The left edge that puts the pet's middle at a nook column.
    func spot(_ center: Int) -> Int { min(max(0, center - width / 2), room ?? 0) }

    var windowSpot: Int { spot(14) }
    var plantSpot: Int { spot(21) }
    var computerSpot: Int { spot(58) }
    var lampSpot: Int { room ?? 0 }
    var ownSpot: Int { min(DeskScene.own(kind).standAt, room ?? 0) }
}

enum DeskPetPlanner {
    /// How much each small thing makes sense now; zero means not now.
    static func score(_ intent: DeskPetIntent, in s: DeskPetSituation) -> Double {
        let m = s.memory
        let bored = 1 + m.boredom
        let base: Double = switch intent {
        case .wander: s.nook ? 1.0 * bored : 0
        case .glance: 0.6
        case .stretch: 0.5 + (s.late ? 0.6 : 0) + (s.justWorked ? 1.2 : 0) + (m.energy < 0.5 ? 0.3 : 0)
        case .show: (m.energy > 0.25 ? 0.8 : 0.1) * bored
        case .own: s.nook ? 0.9 * bored : 0
        case .plant: s.nook ? (s.dry ? 1.4 + min(1.5, s.daysDry * 0.4) : 0.25) : 0
        case .lamp: s.nook && s.lampOn != s.dark ? (s.dark ? 2.2 : 0.9) : 0
        case .blinds:
            if !s.nook { 0 }
            else if m.blindsDown, (6..<11).contains(s.hour) { 1.5 }
            else if !m.blindsDown, (12..<16).contains(s.hour), m.energy < 0.6 { 0.9 }
            else { 0 }
        case .window: s.nook ? 0.5 + (s.hour >= 20 || s.hour < 6 ? 0.7 : 0) : 0
        case .screen: s.nook ? (s.context.running ? 0.9 : (s.dark && m.screensaver ? 0.8 : 0.2)) : 0
        case .nap: m.energy < 0.45 ? (0.45 - m.energy) * 8 + ((13..<16).contains(s.hour) ? 0.5 : 0) : 0
        case .coffee: (6..<11).contains(s.hour) && m.coffeeDay != s.today ? 3 : 0
        case .find:
            if !s.nook || m.collection >= DeskPetMemory.collectionLimit { 0 }
            else if let last = m.lastFind, s.now.timeIntervalSince(last) < 5 * 3_600 { 0 }
            else { 0.45 * bored }
        case .greet: m.trust >= 0.45 && s.sinceTouch > 15 * 60 ? 0.3 + m.trust * 0.6 : 0
        case .nudge: s.nook && s.context.waiting ? 1 : 0
        case .bedtime, .celebrate, .welcome, .milestone: 0
        }
        guard base > 0 else { return 0 }
        var weight = base * (s.nature.leanings[intent] ?? 1) * m.likes(intent)
        if s.context.running { weight *= intent.quiet ? 1 : 0 }
        if intent == s.last { weight *= 0.3 }
        return weight
    }

    static func choose(in s: DeskPetSituation, random: inout DeskPetRandom) -> DeskPetIntent {
        let options = DeskPetIntent.chosen.map { ($0, score($0, in: s)) }.filter { $0.1 > 0 }
        let total = options.reduce(0) { $0 + $1.1 }
        var roll = random.unit() * total
        for (intent, weight) in options {
            roll -= weight
            if roll <= 0 { return intent }
        }
        return .glance
    }

    /// The steps that carry an intent out.
    static func plan(_ intent: DeskPetIntent, in s: DeskPetSituation, random: inout DeskPetRandom) -> [DeskPetStep] {
        let m = s.memory
        let own = DeskScene.own(s.kind)
        switch intent {
        case .wander:
            let room = s.room ?? 0
            var to = random.int(in: 0...max(0, room))
            if abs(to - s.x) < 6 { to = s.x > room / 2 ? max(0, s.x - 12) : min(room, s.x + 12) }
            let gait: DeskPetGait = s.kind == .squid && random.unit() < 0.4 ? .dash : .walk
            return [.go(to, gait), .act(.look), .act(.idle, ticks: random.int(in: 24...48))]
        case .glance:
            return [.act(.look), .act(.idle, ticks: 16), .act(.look)]
        case .stretch:
            return [.act(.stretch)] + (m.energy < 0.5 ? [.act(.yawn)] : [])
        case .show:
            let act = s.nature.shows[random.int(in: 0...(s.nature.shows.count - 1))]
            return [.act(act, ticks: act == .snap ? 24 : nil)]
        case .own:
            return [.go(s.ownSpot), .effect(.own), .act(own.act, ticks: own.act == .read ? 128 : 64)]
        case .plant:
            var steps: [DeskPetStep] = [.go(s.plantSpot), .face(-1), .act(.gaze, ticks: 24)]
            if s.dry, m.trust >= 0.5 {
                steps += [.act(.water, ticks: 32), .effect(.water), .act(.happy)]
            } else if s.dry {
                steps += [.act(.look), .act(.think)]
            } else {
                steps += [.act(.happy)]
            }
            return steps
        case .lamp:
            return [.go(s.lampSpot), .face(1), .act(.reach), .effect(.lamp(s.dark)), .act(s.dark ? .happy : .idle)]
        case .blinds:
            let down = !m.blindsDown
            return [.go(s.windowSpot), .face(-1), .act(.reach), .effect(.blinds(down))]
                + (down ? [.act(.yawn), .act(.nap, ticks: random.int(in: 1_440...2_880))] : [.act(.gaze, ticks: 32)])
        case .window:
            var steps: [DeskPetStep] = [.go(s.windowSpot), .face(-1), .act(.gaze, ticks: random.int(in: 40...80))]
            // Once in a long while, at night, a shooting star crosses the pane.
            let night = s.hour >= 21 || s.hour < 5
            if night, m.starDay != s.today, random.unit() < 0.08 {
                steps += [.effect(.star), .act(.gaze, ticks: 24), .act(.happy), .act(.petted)]
            }
            return steps
        case .screen:
            var steps: [DeskPetStep] = [.go(s.computerSpot), .face(1), .act(.gaze, ticks: random.int(in: 48...96))]
            if s.dark, !m.screensaver, !s.context.running {
                steps += [.act(.reach), .effect(.screensaver(true)), .act(.gaze, ticks: 48)]
            }
            return steps
        case .nap:
            let cozy = s.dark ? s.lampSpot : s.ownSpot
            return [.go(cozy), .act(.yawn), .act(.nap, ticks: random.int(in: 2_400...4_800))]
        case .coffee:
            return [.act(.coffee, ticks: 64), .effect(.coffee), .act(.stretch)]
        case .find:
            let room = s.room ?? 0
            var steps: [DeskPetStep] = [.go(random.int(in: 0...max(0, room))), .act(.look), .act(.found)]
            // Once it trusts the person, it shows them what it found first.
            if m.trust >= 0.75 { steps += [.face(1), .act(.offer)] }
            return steps + [.go(s.ownSpot, .carry), .act(.polish), .effect(.keep)]
        case .greet:
            return (s.nook ? [.go((s.room ?? 0) / 2)] : []) + [.act(.wave), .act(.happy)]
        case .nudge:
            // A glance toward the task library, then back to its day.
            return [.go(s.lampSpot), .face(1), .act(.gaze, ticks: 32), .act(.think)]
        case .bedtime:
            let lamp: [DeskPetStep] = s.nook && s.lampOn
                ? [.go(s.lampSpot), .face(1), .act(.reach), .effect(.lamp(false))] : []
            return lamp + [.act(.yawn), .act(.sleep)]
        case .celebrate:
            return [.act(.celebrate, ticks: 24), .act(.happy), .effect(.goal)]
        case .welcome:
            if m.trust >= 0.6 {
                return (s.nook ? [.go((s.room ?? 0) / 2, .dash)] : []) + [.act(.happy), .act(.wave)]
            }
            if m.trust >= 0.3 { return [.act(.wave)] }
            return s.kind == .hermit ? [.act(.hide, ticks: 32), .act(.peek)] : [.act(.look)]
        case .milestone:
            return [.act(.celebrate, ticks: 32), .act(.wave), .act(.petted)]
        }
    }

    /// The wait until the next small thing: about ten minutes on average, never
    /// the same twice. A free desk makes it livelier; a running agent, a task
    /// waiting on the person, tiredness or the late hours make it calmer;
    /// boredom and a person who enjoys watching bring it sooner.
    static func interval(memory m: DeskPetMemory, context: DeskPetContext, nature: DeskPetNature, hour: Int,
                         random: inout DeskPetRandom) -> TimeInterval {
        var mean = 680 * nature.pace
        if context.running { mean *= 1.4 } else if context.waiting { mean *= 1.15 } else { mean *= 0.8 }
        if context.tasks >= 3 { mean *= 1.1 }
        mean *= 1.4 - 0.5 * m.energy
        mean *= 1 - 0.3 * m.boredom
        mean *= 1.15 - 0.3 * m.interest
        if m.days < 3 { mean *= 1.1 }
        if hour >= 22 || hour < 2 { mean *= 1.25 }
        // The mean of two exponential draws: random gaps that are rarely tiny.
        let draw = (-log(1 - random.unit()) - log(1 - random.unit())) / 2
        return min(max(mean * draw, 90), 40 * 60)
    }
}
#endif
