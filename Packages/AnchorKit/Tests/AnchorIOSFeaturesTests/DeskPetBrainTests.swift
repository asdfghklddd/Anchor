#if os(iOS)
import Foundation
import Testing
@testable import AnchorIOSFeatures

@Suite("Desk pet brain")
struct DeskPetBrainTests {
    private static let calendar = Calendar.current

    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 15) -> Date {
        Self.calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    /// A pet that has known the person a few days, with its next small thing far off.
    private func memory(trust: Double = 0.3, seen: Date) -> DeskPetMemory {
        var memory = DeskPetMemory()
        memory.trust = trust
        memory.lastSeen = seen
        memory.nextThing = seen.addingTimeInterval(3_600)
        memory.days = 5
        memory.lastDay = Self.calendar.startOfDay(for: seen)
        memory.firstMet = seen.addingTimeInterval(-5 * 86_400)
        memory.coffeeDay = Self.calendar.startOfDay(for: seen)
        return memory
    }

    private func brain(_ kind: DeskPetKind, trust: Double = 0.3, at time: Date? = nil,
                       stage: DeskPetStage = .nook(room: 20)) -> DeskPetBrain {
        let time = time ?? at(14)
        var brain = DeskPetBrain(kind: kind, memory: memory(trust: trust, seen: time), now: time, seed: 7)
        brain.step(at: time.addingTimeInterval(0.125), stage: stage)
        return brain
    }

    private func run(_ brain: inout DeskPetBrain, ticks: Int, stage: DeskPetStage = .nook(room: 20),
                     each: (DeskPetBrain) -> Void = { _ in }) {
        for _ in 0..<ticks {
            brain.step(at: brain.now.addingTimeInterval(0.125), stage: stage)
            each(brain)
        }
    }

    // MARK: Touch and desk events

    @Test func calmCrabHopsOnOneTapButBurstMakesItAngry() {
        var crab = brain(.crab)
        crab.tap()
        #expect(crab.act == .happy)
        run(&crab, ticks: 40)
        crab.tap(); crab.tap(); crab.tap()
        #expect(crab.act == .angry)
    }

    @Test func hermitHidesOnPokesAndPeeksBeforeComingOut() {
        var hermit = brain(.hermit)
        hermit.tap(); hermit.tap()
        #expect(hermit.act == .hide)
        run(&hermit, ticks: hermit.length)
        #expect(hermit.act == .peek)
    }

    @Test func pettingCoaxesHermitOutAndBuildsTrust() {
        var hermit = brain(.hermit)
        hermit.tap(); hermit.tap()
        let before = hermit.trust
        hermit.press()
        #expect(hermit.act == .peek)
        #expect(hermit.trust > before)
        #expect(hermit.annoyance < 0.5)
    }

    @Test func jellyfishZapsThenIgnoresTaps() {
        var jelly = brain(.jelly)
        for _ in 0..<4 { jelly.tap() }
        #expect(jelly.act == .zap)
        run(&jelly, ticks: 20)
        let act = jelly.act
        jelly.tap()
        #expect(jelly.act == act)
    }

    @Test func shyOctopusInksAndFleesWhenPoked() {
        var octopus = brain(.octopus)
        octopus.tap()
        #expect(octopus.act == .petted)
        octopus.tap(); octopus.tap()
        #expect(octopus.act == .ink)
        run(&octopus, ticks: octopus.length)
        #expect(octopus.act == .flee)
    }

    @Test func smallAndInPlaceAFrightIsAStartNotARun() {
        var octopus = brain(.octopus, stage: .compact)
        octopus.tap(); octopus.tap(); octopus.tap()
        run(&octopus, ticks: octopus.length, stage: .compact)
        #expect(octopus.act == .startled)
    }

    @Test func deskEventsWinAndWorkResumes() {
        var squid = brain(.squid)
        squid.update(DeskPetContext(running: true, tasks: 1))
        #expect(squid.act == .type)
        squid.hear(.failure)
        #expect(squid.act == .fail)
        run(&squid, ticks: squid.length)
        #expect(squid.act == .type)
        squid.hear(.question)
        #expect(squid.act == .think)
        run(&squid, ticks: squid.length)
        #expect(squid.act == .wave)
    }

    // MARK: Its day

    @Test func sleepsAtNightUnlessThePersonIsAnchoredAndATapWakesIt() {
        var crab = brain(.crab, at: at(23, 30))
        run(&crab, ticks: 400)
        #expect(crab.sleeping)
        crab.tap()
        #expect(!crab.sleeping)

        var owl = brain(.crab, at: at(23, 30))
        owl.update(DeskPetContext(linked: true))
        run(&owl, ticks: 400)
        #expect(!owl.sleeping)
    }

    @Test func smallThingsComeAboutEveryTenMinutesAndCalmWhileAgentsWork() {
        var random = DeskPetRandom(seed: 3)
        var memory = DeskPetMemory()
        memory.energy = 0.6
        memory.days = 10
        let nature = DeskPetNature.of(.octopus)
        func mean(_ context: DeskPetContext) -> TimeInterval {
            let gaps = (0..<4_000).map { _ in
                DeskPetPlanner.interval(memory: memory, context: context, nature: nature, hour: 14, random: &random)
            }
            #expect(gaps.allSatisfy { (90...2_400).contains($0) })
            return gaps.reduce(0, +) / Double(gaps.count)
        }
        let free = mean(DeskPetContext())
        let waiting = mean(DeskPetContext(waiting: true, tasks: 1))
        let working = mean(DeskPetContext(running: true, tasks: 1))
        #expect((8 * 60...12 * 60).contains(free))
        #expect(free < waiting && waiting < working)
    }

    @Test func aMorningHoldsAHandfulOfSmallThings() {
        var crab = brain(.crab, at: at(9))
        var started = 0
        var last: DeskPetIntent?
        run(&crab, ticks: 3 * 3_600 * 8, stage: .nook(room: 40)) { pet in
            if let intent = pet.intent, intent != last, DeskPetIntent.chosen.contains(intent) { started += 1 }
            last = pet.intent
            #expect((0...40).contains(pet.x))
        }
        #expect((8...30).contains(started))
    }

    @Test func smallAndInPlaceItNeverWalks() {
        var squid = brain(.squid, stage: .compact)
        let x = squid.x
        run(&squid, ticks: 2 * 3_600 * 8, stage: .compact) { pet in
            #expect(!pet.act.travels)
        }
        #expect(squid.x == x)
    }

    @Test func todaysGoalIsCelebratedOnce() {
        var jelly = brain(.jelly)
        jelly.update(DeskPetContext(goalReached: true))
        var celebrations = 0
        var last = jelly.act
        run(&jelly, ticks: 20 * 60 * 8) { pet in
            if pet.act == .celebrate, last != .celebrate { celebrations += 1 }
            last = pet.act
        }
        #expect(celebrations == 1)
    }

    // MARK: What it learns

    @Test func whatThePersonEnjoysComesBackSooner() {
        var memory = DeskPetMemory()
        for _ in 0..<10 { memory.learn(.show, noticed: true) }
        #expect(memory.likes(.show) > 1.5)
        #expect(memory.interest > 0.8)
        var ignored = memory
        for _ in 0..<10 { ignored.learn(.wander, noticed: false) }
        #expect(ignored.likes(.wander) == 1)
        #expect(ignored.interest < memory.interest)

        var random = DeskPetRandom(seed: 5)
        var bored = DeskPetMemory()
        bored.interest = 0
        let nature = DeskPetNature.of(.crab)
        let eager = (0..<2_000).map { _ in DeskPetPlanner.interval(memory: memory, context: .init(), nature: nature, hour: 14, random: &random) }
        let shy = (0..<2_000).map { _ in DeskPetPlanner.interval(memory: bored, context: .init(), nature: nature, hour: 14, random: &random) }
        #expect(eager.reduce(0, +) < shy.reduce(0, +))
    }

    @Test func itLearnsWhenThePersonUsuallyComesBack() {
        var memory = DeskPetMemory()
        #expect(!memory.usualArrival(at: 9))
        for _ in 0..<4 { memory.noteArrival(at: 9) }
        memory.noteArrival(at: 20)
        #expect(memory.usualArrival(at: 9))
        #expect(memory.usualArrival(at: 10))
        #expect(!memory.usualArrival(at: 15))
    }

    // MARK: Time away

    @Test func timeAwayIsLivedAndLeavesTraces() {
        let seen = at(18, day: 13)
        var saved = memory(trust: 0.8, seen: seen)
        saved.days = 6
        saved.wateredAt = seen.addingTimeInterval(-86_400)
        saved.lampOn = false
        let wateredBefore = saved.wateredAt!
        var hermit = DeskPetBrain(kind: .hermit, memory: saved, now: at(19, day: 15), seed: 11)
        hermit.step(at: at(19, day: 15), stage: .nook(room: 40))
        #expect(hermit.memory.wateredAt! > wateredBefore)
        #expect(hermit.lampOn)
        #expect(hermit.memory.coffeeDay == Self.calendar.startOfDay(for: at(19, day: 15)))
        #expect(hermit.memory.days == 7)
        #expect(hermit.memory.arrivals.reduce(0, +) > 0)
        // A week together: it marks the day.
        #expect(hermit.intent == .milestone)
    }

    @Test func comingBackAtNightFindsItAsleep() {
        var crab = DeskPetBrain(kind: .crab, memory: memory(seen: at(21)), now: at(3, day: 16), seed: 2)
        crab.step(at: at(3, day: 16), stage: .nook(room: 40))
        #expect(crab.sleeping)
        #expect(!crab.lampOn)
    }

    @Test func atTheUsualHourItWaitsByTheWindow() {
        var saved = memory(trust: 0.5, seen: at(18, day: 14))
        for _ in 0..<5 { saved.noteArrival(at: 9) }
        var octopus = DeskPetBrain(kind: .octopus, memory: saved, now: at(9, 10), seed: 4)
        octopus.step(at: at(9, 10), stage: .nook(room: 40))
        #expect(octopus.act == .gaze)
        #expect(octopus.x == max(0, 14 - octopus.width / 2))
        #expect(octopus.intent == .welcome)
    }

    // MARK: Choices

    @Test func theNookPullsItToWhatNeedsDoing() {
        var dusk = memory(trust: 0.6, seen: at(18, 30))
        dusk.lampOn = false
        let s = situation(.crab, memory: dusk, hour: 18, now: at(18, 30))
        #expect(DeskPetPlanner.score(.lamp, in: s) > DeskPetPlanner.score(.wander, in: s))
        var random = DeskPetRandom(seed: 1)
        #expect(DeskPetPlanner.plan(.lamp, in: s, random: &random).contains(.effect(.lamp(true))))

        let compact = situation(.crab, memory: dusk, hour: 18, now: at(18, 30), room: nil)
        #expect(DeskPetPlanner.score(.lamp, in: compact) == 0)

        let waiting = situation(.crab, memory: dusk, hour: 14, now: at(14), context: DeskPetContext(waiting: true, tasks: 2))
        #expect(DeskPetPlanner.score(.nudge, in: waiting) > 0)
        #expect(DeskPetPlanner.score(.nudge, in: s) == 0)
    }

    @Test func itWatersThePlantOnlyOnceItTrustsThePerson() {
        var random = DeskPetRandom(seed: 1)
        var shy = memory(trust: 0.2, seen: at(14))
        shy.wateredAt = at(14, day: 12)
        var close = shy
        close.trust = 0.7
        let shyPlan = DeskPetPlanner.plan(.plant, in: situation(.octopus, memory: shy, hour: 14, now: at(14)), random: &random)
        let closePlan = DeskPetPlanner.plan(.plant, in: situation(.octopus, memory: close, hour: 14, now: at(14)), random: &random)
        #expect(!shyPlan.contains(.effect(.water)))
        #expect(closePlan.contains(.effect(.water)))
    }

    private func situation(_ kind: DeskPetKind, memory: DeskPetMemory, hour: Int, now: Date, room: Int? = 40,
                           context: DeskPetContext = .init()) -> DeskPetSituation {
        DeskPetSituation(kind: kind, nature: .of(kind), memory: memory, context: context, now: now, hour: hour,
                         room: room, width: DeskPetLook.of(kind).width, x: 10, last: nil, sinceTouch: 0,
                         justWorked: false)
    }

    // MARK: Memory

    @Test func memoryIsKeptPerPetAndForgottenOnReset() throws {
        let suite = "DeskPetMemoryTests.\(UUID().uuidString)"
        let store = try #require(UserDefaults(suiteName: suite))
        defer { store.removePersistentDomain(forName: suite) }

        // Trust and the plant from before memories carry over.
        store.set(0.8, forKey: "anchor.desk.pet.trust.hermit")
        store.set(2, forKey: "anchor.desk.plant.growth")
        let migrated = try #require(DeskPetMemoryStore.load(.hermit, from: store))
        #expect(migrated.trust == 0.8)
        #expect(migrated.growth == 2)

        var crab = DeskPetMemory()
        crab.collection = 3
        DeskPetMemoryStore.save(crab, for: .crab, in: store)
        #expect(DeskPetMemoryStore.load(.crab, from: store)?.collection == 3)

        DeskPetMemoryStore.forgetAll(in: store)
        #expect(DeskPetMemoryStore.load(.crab, from: store) == nil)
        #expect(DeskPetMemoryStore.load(.hermit, from: store) == nil)
    }
}
#endif
