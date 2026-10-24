#if os(iOS)
import Testing
@testable import AnchorIOSFeatures

@Suite("Desk pet brain")
struct DeskPetBrainTests {
    private func brain(_ kind: DeskPetKind, trust: Double = 0.3) -> DeskPetBrain {
        var brain = DeskPetBrain(kind: kind, trust: trust, seed: 7)
        brain.set(mood: .yourMove, hour: 14)
        brain.step(room: 20)
        return brain
    }

    private func run(_ brain: inout DeskPetBrain, ticks: Int) {
        for _ in 0..<ticks { brain.step(room: 20) }
    }

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

    @Test func deskEventsWinAndWorkResumes() {
        var squid = brain(.squid)
        squid.set(mood: .working, hour: 14)
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

    @Test func quietDeskSleepsAndATapWakesIt() {
        var crab = brain(.crab)
        crab.set(mood: .quiet, hour: 14)
        run(&crab, ticks: 400)
        #expect(crab.sleeping)
        crab.tap()
        #expect(!crab.sleeping)
    }

    @Test func bigActsKeepTheirDistance() {
        for kind in [DeskPetKind.crab, .squid, .octopus, .hermit, .jelly] {
            var pet = brain(kind)
            let signature = DeskPetNature.of(kind).signature
            var starts: [Int] = []
            var last = pet.act
            for _ in 0..<6_000 {
                pet.step(room: 20)
                if pet.act != last, signature.contains(pet.act) { starts.append(pet.tick) }
                last = pet.act
            }
            for (a, b) in zip(starts, starts.dropFirst()) { #expect(b - a >= DeskPetBrain.bigGap) }
        }
    }

    @Test func petStaysInsideItsRoom() {
        var squid = brain(.squid)
        for _ in 0..<3_000 {
            squid.step(room: 12)
            #expect((0...12).contains(squid.x))
        }
    }
}
#endif
