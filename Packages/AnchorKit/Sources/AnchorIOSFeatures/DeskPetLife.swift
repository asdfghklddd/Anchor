#if os(iOS)
import Foundation
import Observation

/// The one pet behind both screens: the home greeting shows it small and in
/// place, the landscape desk shows it in its nook. Whichever is on screen
/// moves its time forward, by the clock, so the two never double it; time no
/// screen saw is lived on return. Its memory is saved as it goes.
@MainActor
@Observable
final class DeskPetLife {
    static let shared = DeskPetLife()

    private(set) var brain: DeskPetBrain?
    private(set) var kind = DeskPetKind.off

    @ObservationIgnored private var desk = DeskPetContext()
    @ObservationIgnored private var lastStep: Date?
    @ObservationIgnored private var lastSave = Date.distantPast
    @ObservationIgnored private var lastLook = Date.distantPast

    static let tickLength: TimeInterval = 0.125

    /// Whether the person is anchored at the desk and has met today's goal;
    /// set up by whatever keeps that record.
    static var anchoring: ((Date) -> (linked: Bool, goalReached: Bool))?

    private var store: UserDefaults { ProfilePreferences.store }

    /// Switches to the chosen pet; the one before keeps its memory.
    func use(_ next: DeskPetKind, now: Date = .now) {
        guard next != kind || (brain == nil && next != .off) else { return }
        save()
        kind = next
        lastStep = nil
        guard next != .off else {
            brain = nil
            return
        }
        brain = DeskPetBrain(kind: next, memory: DeskPetMemoryStore.load(next, from: store), now: now)
        look(now: now)
    }

    /// What the tasks say: running, waiting, how many.
    func update(desk new: DeskPetContext) {
        desk.running = new.running
        desk.waiting = new.waiting
        desk.tasks = new.tasks
        brain?.update(desk)
    }

    /// Moves the pet's time to `now`, one tick per eighth of a second.
    func advance(now: Date, stage: DeskPetStage) {
        if now.timeIntervalSince(lastLook) > 30 { look(now: now) }
        guard var brain else { return }
        var from = lastStep ?? now.addingTimeInterval(-Self.tickLength)
        // A long gap is not stepped through; the brain lives it on the next step.
        if now.timeIntervalSince(from) > 2 { from = now.addingTimeInterval(-Self.tickLength) }
        let due = min(16, Int(now.timeIntervalSince(from) / Self.tickLength))
        guard due > 0 else { return }
        for i in 1...due { brain.step(at: from.addingTimeInterval(Double(i) * Self.tickLength), stage: stage) }
        lastStep = from.addingTimeInterval(Double(due) * Self.tickLength)
        self.brain = brain
        if now.timeIntervalSince(lastSave) > 30 { save() }
    }

    /// With reduced motion nothing steps, but time away is still lived, so
    /// the still pose is right (asleep at night, for one).
    func settle(now: Date) {
        look(now: now)
        brain?.catchUp(to: now)
        save()
    }

    func tap() {
        brain?.tap()
    }

    func press() {
        brain?.press()
        save()
    }

    func use(_ thing: DeskScene.Thing) {
        brain?.use(thing)
        save()
    }

    func hear(_ event: DeskPetEvent) {
        brain?.hear(event)
    }

    func save() {
        guard let brain else { return }
        DeskPetMemoryStore.save(brain.memory, for: kind, in: store)
        lastSave = .now
    }

    /// Every pet forgets; the one on screen starts over as if just met.
    func forgetAll(now: Date = .now) {
        DeskPetMemoryStore.forgetAll(in: store)
        lastStep = nil
        guard kind != .off else { return }
        brain = DeskPetBrain(kind: kind, now: now)
        look(now: now)
    }

    /// Reads the anchoring link and today's goal, every half minute.
    private func look(now: Date) {
        lastLook = now
        if let anchoring = Self.anchoring?(now) {
            desk.linked = anchoring.linked
            desk.goalReached = anchoring.goalReached
        }
        brain?.update(desk)
    }
}
#endif
