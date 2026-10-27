#if os(iOS)
import Foundation

/// Everything a pet can be doing. Small things are plans made of these; desk
/// events and touches start them directly.
enum DeskPetAct: String, CaseIterable, Sendable {
    // Daily life
    case idle, move, look, yawn, stretch, nap, sleep, coffee, gaze, reach, water, found, offer
    // Desk events
    case type, celebrate, wave, fail, think
    // Touch
    case happy, petted, startled, angry, sulk, flee, dizzy, hide, peek, zap
    // Each pet's own
    case build, snap, dance, shades, dash, juggle, read, ink, pebble, polish, glow, meditate, sway

    /// Acts that travel to a target column.
    var travels: Bool { [.move, .flee, .dash, .pebble].contains(self) }

    /// Busy acts that tire it faster.
    var lively: Bool { [.dance, .dash, .flee, .celebrate, .juggle, .happy, .angry, .build].contains(self) }
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
    /// Its show-off acts, done where it stands.
    let shows: [DeskPetAct]
    /// How much each small thing draws it; 1 is neutral.
    let leanings: [DeskPetIntent: Double]
    /// The hours it wakes up and goes to bed.
    let wakes: Int
    let sleeps: Int
    /// Below 1 its small things come more often; above 1, less.
    let pace: Double

    func night(at hour: Int) -> Bool {
        sleeps > wakes ? (hour >= sleeps || hour < wakes) : (hour >= sleeps && hour < wakes)
    }

    static func of(_ kind: DeskPetKind) -> DeskPetNature {
        switch kind {
        case .crab, .off:
            // A busy early riser with a short fuse; fixes things.
            DeskPetNature(temper: 0.9, timidity: 0.1, stepEvery: 2, stepSize: 1, shows: [.snap],
                          leanings: [.own: 1.6, .lamp: 1.4, .blinds: 1.2, .plant: 0.8, .window: 0.6, .find: 0.8],
                          wakes: 6, sleeps: 22, pace: 0.95)
        case .squid:
            // A show-off night owl with energy to spare.
            DeskPetNature(temper: 0.3, timidity: 0.1, stepEvery: 1, stepSize: 1, shows: [.shades, .dance],
                          leanings: [.show: 1.8, .wander: 1.5, .greet: 1.4, .own: 1.4, .nap: 0.6, .window: 0.7],
                          wakes: 9, sleeps: 1, pace: 0.8)
        case .octopus:
            // Shy and warm; reads, tends the plant.
            DeskPetNature(temper: 0.2, timidity: 0.6, stepEvery: 3, stepSize: 1, shows: [.juggle],
                          leanings: [.own: 1.6, .plant: 1.5, .window: 1.1, .greet: 0.8, .wander: 0.8],
                          wakes: 7, sleeps: 23, pace: 1)
        case .hermit:
            // Timid, slow, a collector.
            DeskPetNature(temper: 0.1, timidity: 0.95, stepEvery: 4, stepSize: 1, shows: [.polish],
                          leanings: [.find: 2.2, .own: 1.3, .window: 1, .wander: 0.6, .greet: 0.5],
                          wakes: 7, sleeps: 22, pace: 1.2)
        case .jelly:
            // Calm and dreamy; drifts, and loves the night sky.
            DeskPetNature(temper: 0.4, timidity: 0.3, stepEvery: 3, stepSize: 1, shows: [.sway, .meditate],
                          leanings: [.window: 1.8, .show: 1.3, .own: 1.2, .wander: 1.2],
                          wakes: 8, sleeps: 0, pace: 1)
        }
    }
}

/// When something in the nook was just used, so it can show it.
struct DeskPetMarks: Equatable, Sendable {
    var water = -1_000
    var own = -1_000
    var star = -1_000
}

/// A pet's life, one step per 8 fps tick. Desk events and touches answer at
/// once; between them it rests (blinking, glancing, typing beside a running
/// agent, sleeping at night) and, about every ten minutes, sets out to do one
/// small thing picked by `DeskPetPlanner`. Its memory outlives the app: time
/// away is lived on return, coarsely, and what it learns stays.
struct DeskPetBrain {
    let kind: DeskPetKind
    let nature: DeskPetNature
    let width: Int

    private(set) var memory: DeskPetMemory
    private(set) var context = DeskPetContext()
    private(set) var stage = DeskPetStage.compact
    private(set) var now: Date

    private(set) var tick = 0
    private(set) var act = DeskPetAct.idle
    private(set) var actStart = 0
    private(set) var actEnd = 24
    private(set) var facing = 1
    private(set) var marks = DeskPetMarks()
    /// Rises with poking and cools within a minute.
    private(set) var annoyance = 0.0
    /// The small thing under way, if any.
    private(set) var intent: DeskPetIntent?

    private var plan: [DeskPetStep] = []
    private var target = 0
    private var taps: [Int] = []
    private var ignoreUntil = 0
    private var awakeUntil = 0
    private var lastTouch: Date
    private var workedAt: Date?
    private var lastIntent: DeskPetIntent?
    private var watch: Watch?
    private var nextBlink = 24
    private var blinkAt = -10
    private var blinkAgain = -10
    /// Back from time away: it will be somewhere new once the nook is known.
    private var place = false
    private var placeAt: Int?
    private var random: DeskPetRandom

    /// A small thing waiting to learn whether the person noticed it.
    private struct Watch {
        let intent: DeskPetIntent
        let until: Date
        var noticed: Bool
    }

    /// Taps closer together than this count as one burst.
    static let burst = 12
    /// Away longer than this, and the return is an arrival.
    static let arrival: TimeInterval = 45 * 60

    init(kind: DeskPetKind, memory saved: DeskPetMemory? = nil, now: Date = .now,
         seed: UInt64 = .random(in: 1...UInt64.max)) {
        self.kind = kind
        nature = .of(kind)
        width = DeskPetLook.of(kind).width
        self.now = now
        lastTouch = now
        random = DeskPetRandom(seed: seed)
        if let saved {
            // Lived on the first step, once it knows where it is drawn.
            memory = saved
        } else {
            memory = DeskPetMemory()
            memory.firstMet = now
            memory.lastSeen = now
            let hour = Calendar.current.component(.hour, from: now)
            memory.lampOn = hour >= 18 || hour < 7
            memory.nextThing = now.addingTimeInterval(TimeInterval(random.int(in: 120...300)))
            noteDay()
        }
    }

    var x: Int { memory.x }
    var trust: Double { memory.trust }
    var energy: Double { memory.energy }
    var boredom: Double { memory.boredom }
    var progress: Int { tick - actStart }
    var length: Int { max(1, actEnd - actStart) }
    var sleeping: Bool { act == .sleep || act == .nap }
    var blinking: Bool { tick == blinkAt || tick == blinkAgain }
    var hour: Int { Calendar.current.component(.hour, from: now) }
    private var today: Date { Calendar.current.startOfDay(for: now) }

    /// Night by its own clock, with nobody at the desk, and nothing has woken it.
    var shouldSleep: Bool { nature.night(at: hour) && !context.linked && tick >= awakeUntil }

    var lampOn: Bool { memory.lampOn ?? (hour >= 18 || hour < 7) }

    // MARK: Inputs

    mutating func update(_ new: DeskPetContext) {
        let old = context
        context = new
        if new.running, !old.running, intent == nil, !shouldSleep {
            if sleeping { react(.yawn, then: [.type]) } else { begin(.type) }
        } else if !new.running, old.running {
            workedAt = now
            if act == .type {
                plan = []
                begin(.stretch)
            }
        }
    }

    /// A desk event wins over whatever the pet is doing; asleep at night it only stirs.
    mutating func hear(_ event: DeskPetEvent) {
        if sleeping, shouldSleep {
            react(.yawn, then: [.sleep])
            return
        }
        awakeUntil = tick + 120
        switch event {
        case .result:
            switch kind {
            case .octopus, .hermit: react(.wave)
            case .jelly: react(.glow, then: [.wave])
            case .crab, .squid, .off: react(.celebrate)
            }
        case .failure:
            switch kind {
            case .crab: react(.angry)
            case .hermit: react(.hide, for: 48, then: [.peek])
            case .octopus: react(.startled, then: [.fail])
            case .squid, .jelly, .off: react(.fail)
            }
        case .question:
            react(.think, then: [.wave])
        }
    }

    mutating func tap() {
        noticed()
        taps = taps.filter { tick - $0 < Self.burst } + [tick]
        let burst = taps.count
        // Someone who mostly pokes makes it quicker to bristle.
        let wary = memory.gentle < 0.25 ? 1.4 : 1
        annoyance = min(1, annoyance + (0.1 + nature.temper * 0.12) * wary)
        if burst >= 3 {
            memory.trust = max(0, memory.trust - 0.01)
            memory.gentle += 0.15 * (0 - memory.gentle)
        } else if annoyance < 0.3 {
            memory.trust = min(1, memory.trust + 0.004)
        }
        guard tick >= ignoreUntil else { return }

        if sleeping {
            awakeUntil = tick + 120
            if nature.timidity > 0.6 { react(.startled) }
            else if nature.temper > 0.6 { react(.angry, for: 12) }
            else { react(.yawn) }
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
                if act != .angry && act != .sulk { react(.angry, then: annoyance > 0.85 ? [.sulk] : []) }
            } else {
                react(annoyance < 0.35 ? .happy : .snap)
            }
        case .squid:
            if annoyance > 0.9 { react(.dizzy) }
            else if burst >= 3 { if act != .dance { react(.dance) } }
            else { react(chance(0.5) ? .happy : .wave) }
        case .octopus:
            if burst >= 3 || annoyance > 0.7 {
                if act != .ink && act != .flee { react(.ink, then: [.flee]) }
            } else if burst == 2 {
                react(.startled)
            } else {
                react(.petted)
            }
        case .hermit:
            if burst >= 2 || annoyance > 0.4 || memory.trust < 0.2 {
                // Longer inside when poked hard; shorter once it trusts you.
                let stay = 40 + Int(annoyance * 80) - Int(memory.trust * 40)
                react(.hide, for: max(24, stay), then: [.peek])
            } else {
                react(memory.trust > 0.5 ? .happy : .startled)
            }
        case .jelly:
            if burst >= 4 {
                ignoreUntil = tick + 80
                react(.zap, then: [.flee])
            } else {
                react(.happy)
            }
        }
    }

    /// A long press: petting. It calms, and trust grows.
    mutating func press() {
        noticed()
        memory.trust = min(1, memory.trust + 0.03)
        memory.gentle += 0.1 * (1 - memory.gentle)
        annoyance = max(0, annoyance - 0.5)
        ignoreUntil = 0
        if act == .hide { react(.peek, then: [.petted]) } else { react(.petted) }
    }

    /// The person touched something in the nook.
    mutating func use(_ thing: DeskScene.Thing) {
        noticed()
        switch thing {
        case .blinds: memory.blindsDown.toggle()
        case .lamp: memory.lampOn = !lampOn
        case .computer: memory.screensaver.toggle()
        case .plant:
            water()
            if intent == nil, !sleeping { react(.happy) }
        case .own:
            // Its own thing draws it over to use it, waking first if it slept.
            awakeUntil = tick + 120
            guard !(act == .hide || act == .angry || act == .sulk) else { return }
            marks.own = tick
            let own = DeskScene.own(kind)
            settle()
            if let watch { memory.learn(watch.intent, noticed: true) }
            intent = .own
            watch = Watch(intent: .own, until: now.addingTimeInterval(90), noticed: true)
            plan = [.go(min(own.standAt, stage.room ?? 0)), .act(own.act, ticks: own.act == .read ? 128 : 64)]
            if !advancePlan() { finish() }
        }
    }

    // MARK: Time

    mutating func step(at time: Date, stage newStage: DeskPetStage) {
        set(stage: newStage)
        if let seen = memory.lastSeen, time.timeIntervalSince(seen) > 30 { catchUp(to: time) }
        now = time
        memory.lastSeen = time
        tick += 1
        if tick % 80 == 0 { noteDay() }

        annoyance = max(0, annoyance - 0.004)
        if sleeping {
            memory.energy = min(1, memory.energy + (act == .nap ? 2.1e-5 : 5.2e-6))
        } else {
            memory.energy = max(0, memory.energy - (act.lively ? 7e-6 : 1.74e-6))
            if intent == nil, plan.isEmpty, act == .idle || act == .look {
                memory.boredom = min(1, memory.boredom + 4.2e-5)
            }
        }
        if tick >= nextBlink {
            blinkAt = tick
            blinkAgain = chance(0.15) ? tick + 3 : -10
            nextBlink = tick + random.int(in: 24...64)
        }
        if let watch, now > watch.until {
            memory.learn(watch.intent, noticed: watch.noticed)
            self.watch = nil
        }

        if act.travels { walk() }
        if tick >= actEnd { finish() }
    }

    /// Lives the time since it was last seen, in ten-minute slices: sleep and
    /// tiredness, coffee, the lamp and blinds kept to the hour, the plant
    /// watered once it trusts the person enough, now and then a find. The
    /// person sees only where things ended up.
    mutating func catchUp(to time: Date) {
        let seen = memory.lastSeen ?? time
        let gap = time.timeIntervalSince(seen)
        memory.lastSeen = time
        guard gap > 30 else { return }
        settle()
        marks = DeskPetMarks()
        taps = []
        annoyance = 0
        let calendar = Calendar.current
        var t = max(seen, time.addingTimeInterval(-7 * 86_400))
        while t < time {
            let slot = min(600, time.timeIntervalSince(t))
            let hours = slot / 3_600
            let h = calendar.component(.hour, from: t)
            if nature.night(at: h) {
                memory.energy = min(1, memory.energy + 0.15 * hours)
                memory.lampOn = false
            } else {
                memory.energy = max(0, memory.energy - 0.05 * hours)
                memory.boredom = min(1, memory.boredom + hours * 1.2)
                if memory.energy < 0.3 { memory.energy += 0.1 }
                let day = calendar.startOfDay(for: t)
                if (6..<11).contains(h), memory.coffeeDay != day {
                    memory.coffeeDay = day
                    memory.energy = min(1, memory.energy + 0.15)
                }
                memory.lampOn = h >= 18 || h < 7
                if (6..<11).contains(h) { memory.blindsDown = false }
                let dryFor = memory.wateredAt.map { t.timeIntervalSince($0) } ?? .infinity
                if dryFor > 0.85 * 86_400, memory.trust >= 0.55, chance(0.3 * hours) { water(at: t) }
                let sinceFind = memory.lastFind.map { t.timeIntervalSince($0) } ?? .infinity
                if memory.collection < DeskPetMemory.collectionLimit, sinceFind > 5 * 3_600,
                   chance(0.08 * hours * (nature.leanings[.find] ?? 1)) {
                    memory.collection += 1
                    memory.lastFind = t
                }
            }
            t += slot
        }
        now = time
        noteDay()

        let arriving = gap >= Self.arrival
        if arriving { memory.noteArrival(at: hour) }
        place = true
        placeAt = nil
        if shouldSleep {
            begin(.sleep, ticks: random.int(in: 80...160))
        } else if arriving {
            if milestoneDue {
                start(.milestone)
            } else if memory.usualArrival(at: hour) {
                // It knew roughly when you would come, and waited by the window.
                placeAt = situation.windowSpot
                plan = [.face(-1), .act(.gaze, ticks: 24)]
                start(.welcome, keeping: true)
            } else {
                start(.welcome)
            }
        } else {
            rest()
        }
        memory.nextThing = time.addingTimeInterval(interval())
        if let room = stage.room { placeIn(room) }
    }

    private mutating func set(stage new: DeskPetStage) {
        guard new != stage else { return }
        stage = new
        if let room = new.room {
            placeIn(room)
        } else if act.travels {
            // No room to walk in: the walk ends where it is.
            actEnd = tick
        }
    }

    private mutating func placeIn(_ room: Int) {
        if place {
            memory.x = placeAt ?? random.int(in: 0...max(0, room))
            place = false
            placeAt = nil
        }
        memory.x = min(max(0, memory.x), room)
        target = min(target, room)
    }

    private mutating func walk() {
        let quick = act == .dash || act == .flee
        let speed = quick ? max(1, nature.stepEvery / 2) : nature.stepEvery
        guard tick % speed == 0 else { return }
        let size = quick ? nature.stepSize * 2 : nature.stepSize
        if memory.x == target {
            actEnd = tick
            return
        }
        facing = target > memory.x ? 1 : -1
        memory.x = target > memory.x ? min(target, memory.x + size) : max(target, memory.x - size)
    }

    private mutating func finish() {
        if advancePlan() { return }
        if intent != nil {
            lastIntent = intent
            intent = nil
        }
        if act == .sleep, !shouldSleep {
            // Morning, or woken: a stretch, then the day starts soon.
            memory.nextThing = now.addingTimeInterval(TimeInterval(random.int(in: 60...180)))
            plan = [.act(.yawn)]
            begin(.stretch)
            return
        }
        if shouldSleep {
            if sleeping { begin(.sleep, ticks: random.int(in: 80...160)) } else { start(.bedtime) }
            return
        }
        if context.goalReached, memory.goalDay != today {
            start(.celebrate)
            return
        }
        if milestoneDue {
            start(.milestone)
            return
        }
        if memory.nextThing.map({ now >= $0 }) ?? true {
            memory.nextThing = now.addingTimeInterval(interval())
            let s = situation
            let pick = DeskPetPlanner.choose(in: s, random: &random)
            start(pick, learn: true)
            return
        }
        rest()
    }

    /// Between small things: typing beside a running agent, otherwise sitting
    /// with the odd glance or yawn.
    private mutating func rest() {
        if context.running {
            begin(act == .type && chance(0.1) ? .look : .type)
            return
        }
        let roll = random.unit()
        if roll < 0.12 { begin(.look) }
        else if roll < 0.16, memory.energy < 0.4 { begin(.yawn) }
        else { begin(.idle, ticks: random.int(in: 32...96)) }
    }

    /// Sets out on a small thing.
    private mutating func start(_ next: DeskPetIntent, learn: Bool = false, keeping: Bool = false) {
        if let watch { memory.learn(watch.intent, noticed: watch.noticed) }
        watch = learn ? Watch(intent: next, until: now.addingTimeInterval(90), noticed: false) : nil
        switch next {
        case .show, .own, .find, .wander: memory.boredom *= 0.3
        default: memory.boredom = max(0, memory.boredom - 0.15)
        }
        if next == .milestone { memory.milestone = Self.milestones.last { memory.days >= $0 } ?? memory.milestone }
        intent = next
        let s = situation
        let steps = DeskPetPlanner.plan(next, in: s, random: &random)
        plan = (keeping ? plan : []) + steps
        if !advancePlan() {
            intent = nil
            rest()
        }
    }

    /// Runs plan steps until one takes time; false when the plan is done.
    private mutating func advancePlan() -> Bool {
        while !plan.isEmpty {
            switch plan.removeFirst() {
            case let .go(spot, gait):
                guard let room = stage.room else { continue }
                target = min(max(0, spot), room)
                guard target != memory.x else { continue }
                facing = target > memory.x ? 1 : -1
                begin(gait == .carry ? .pebble : gait == .dash ? .dash : .move, ticks: 600)
                return true
            case let .face(side):
                facing = side
            case let .effect(effect):
                apply(effect)
            case let .act(next, ticks):
                begin(next, ticks: ticks)
                return true
            }
        }
        return false
    }

    private mutating func apply(_ effect: DeskPetEffect) {
        switch effect {
        case let .lamp(on): memory.lampOn = on
        case let .blinds(down): memory.blindsDown = down
        case let .screensaver(on): memory.screensaver = on
        case .water: water()
        case .keep:
            memory.collection = min(DeskPetMemory.collectionLimit, memory.collection + 1)
            memory.lastFind = now
            marks.own = tick
        case .coffee:
            memory.coffeeDay = today
            memory.energy = min(1, memory.energy + 0.15)
        case .goal: memory.goalDay = today
        case .star:
            memory.starDay = today
            marks.star = tick
        case .own: marks.own = tick
        }
    }

    /// A touch or desk event: whatever small thing was under way is dropped.
    private mutating func react(_ next: DeskPetAct, for ticks: Int? = nil, then follow: [DeskPetAct] = []) {
        settle()
        plan = follow.map { .act($0) }
        if next == .hide, follow.isEmpty { plan = [.act(.peek)] }
        if next == .flee, let room = stage.room {
            target = memory.x > room / 2 ? 0 : room
            facing = target >= memory.x ? 1 : -1
        }
        begin(next, ticks: ticks)
    }

    private mutating func settle() {
        if intent != nil {
            lastIntent = intent
            intent = nil
        }
        plan = []
    }

    private mutating func begin(_ next: DeskPetAct, ticks: Int? = nil) {
        // Small and in place, it cannot run off: a fright shows as a start.
        act = stage.room == nil && next.travels ? .startled : next
        actStart = tick
        actEnd = tick + (ticks ?? duration(of: act))
    }

    private mutating func noticed() {
        lastTouch = now
        watch?.noticed = true
        memory.boredom = max(0, memory.boredom - 0.05)
    }

    private mutating func water(at time: Date? = nil) {
        let when = time ?? now
        let day = Calendar.current.startOfDay(for: when)
        if memory.wateredAt.map({ Calendar.current.startOfDay(for: $0) != day }) ?? true { memory.waterDays += 1 }
        memory.wateredAt = when
        if time == nil { marks.water = tick }
    }

    private mutating func noteDay() {
        guard memory.lastDay != today else { return }
        memory.lastDay = today
        memory.days += 1
    }

    static let milestones = [7, 30, 100, 365]

    private var milestoneDue: Bool { Self.milestones.contains { memory.days >= $0 && memory.milestone < $0 } }

    private var situation: DeskPetSituation {
        DeskPetSituation(kind: kind, nature: nature, memory: memory, context: context, now: now, hour: hour,
                         room: stage.room, width: width, x: memory.x, last: lastIntent,
                         sinceTouch: now.timeIntervalSince(lastTouch),
                         justWorked: workedAt.map { now.timeIntervalSince($0) < 300 } ?? false)
    }

    private mutating func interval() -> TimeInterval {
        DeskPetPlanner.interval(memory: memory, context: context, nature: nature, hour: hour, random: &random)
    }

    private mutating func duration(of next: DeskPetAct) -> Int {
        switch next {
        case .idle: random.int(in: 16...48)
        case .move, .flee, .dash, .pebble: 160
        case .look: random.int(in: 12...20)
        case .yawn, .happy: 12
        case .stretch, .peek, .reach: 16
        case .nap: random.int(in: 160...320)
        case .sleep: 80
        case .coffee, .think, .build, .shades, .juggle: 48
        case .type: random.int(in: 60...160)
        case .celebrate, .wave, .snap: 16
        case .fail: 28
        case .petted, .ink, .found: 20
        case .startled, .zap: 12
        case .angry, .dizzy, .polish, .offer: 24
        case .sulk: 48
        case .hide: 56
        case .dance, .sway: 40
        case .read, .meditate: 64
        case .glow, .water: 32
        case .gaze: 40
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
