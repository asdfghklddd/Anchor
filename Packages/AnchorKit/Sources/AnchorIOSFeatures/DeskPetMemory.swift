#if os(iOS)
import AnchorCore
import Foundation

/// What a pet keeps between launches: how it feels, what it has learned about
/// the person, and the state of its nook. One per pet, so a pet picked again
/// later still remembers. Nothing here is ever shown as a number.
struct DeskPetMemory: Codable, Equatable, Sendable {
    // How it feels
    var trust = 0.3
    var energy = 1.0
    var boredom = 0.0
    /// Its spot in the nook, so it is where it was when the desk comes back.
    var x = 0

    // Time together
    var firstMet: Date?
    /// The last moment it was on screen; time away is lived from here.
    var lastSeen: Date?
    var nextThing: Date?
    /// Distinct days it has seen the person.
    var days = 0
    var lastDay: Date?

    // What it has learned
    /// How often its small things draw a touch, 0...1.
    var interest = 0.5
    /// Per small thing, how much the person seemed to like it (1 is neutral).
    var liked: [String: Double] = [:]
    /// Petting against poking, 0 (only pokes) to 1 (only petting).
    var gentle = 0.5
    /// The hours the person usually comes back, faded over time.
    var arrivals = [Double](repeating: 0, count: 24)

    // Its nook
    var lampOn: Bool?
    var blindsDown = false
    var screensaver = false
    /// Distinct days the plant was watered; leaves and the flower follow it.
    var waterDays = 0
    var wateredAt: Date?
    /// Little things it found and keeps by its own thing.
    var collection = 0
    var lastFind: Date?

    // Once-a-day and rare things, by the day they last happened
    var coffeeDay: Date?
    var goalDay: Date?
    var starDay: Date?
    var milestone = 0

    static let collectionLimit = 8

    /// Leaves grown from watering, 0 to 3.
    var growth: Int { min(3, waterDays) }

    func wilted(now: Date, cactus: Bool) -> Bool {
        guard let wateredAt else { return false }
        return now.timeIntervalSince(wateredAt) > (cactus ? 10 : 3) * 86_400
    }

    func blooming(now: Date, cactus: Bool) -> Bool {
        waterDays >= 5 && !wilted(now: now, cactus: cactus)
    }

    /// Whether the person tends to come back around this hour.
    func usualArrival(at hour: Int) -> Bool {
        let total = arrivals.reduce(0, +)
        guard total >= 3, let top = arrivals.max(), top > 0 else { return false }
        return (-1...1).contains { arrivals[(hour + $0 + 24) % 24] >= top * 0.5 }
    }

    mutating func noteArrival(at hour: Int) {
        arrivals = arrivals.map { $0 * 0.9 }
        arrivals[hour] += 1
    }

    func likes(_ intent: DeskPetIntent) -> Double { liked[intent.rawValue] ?? 1 }

    /// The person touched (or not) during one of its small things.
    mutating func learn(_ intent: DeskPetIntent, noticed: Bool) {
        interest += 0.12 * ((noticed ? 1 : 0) - interest)
        let old = likes(intent)
        liked[intent.rawValue] = noticed ? min(2, old + 0.15) : 1 + (old - 1) * 0.97
    }
}

/// Where each pet's memory lives, and how to forget it all.
enum DeskPetMemoryStore {
    private static func key(_ kind: DeskPetKind) -> String { "anchor.desk.pet.memory.\(kind.rawValue)" }
    /// Before memories, trust and the plant were kept on their own.
    private static func oldTrustKey(_ kind: DeskPetKind) -> String { "anchor.desk.pet.trust.\(kind.rawValue)" }
    private static let oldGrowthKey = "anchor.desk.plant.growth"

    static func load(_ kind: DeskPetKind, from store: UserDefaults) -> DeskPetMemory? {
        if let data = store.data(forKey: key(kind)),
           let memory = try? JSONDecoder().decode(DeskPetMemory.self, from: data) { return memory }
        let trust = store.object(forKey: oldTrustKey(kind)) as? Double
        let growth = store.integer(forKey: oldGrowthKey)
        guard trust != nil || growth > 0 else { return nil }
        var memory = DeskPetMemory()
        memory.trust = trust ?? memory.trust
        memory.waterDays = growth
        return memory
    }

    static func save(_ memory: DeskPetMemory, for kind: DeskPetKind, in store: UserDefaults) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        store.set(data, forKey: key(kind))
    }

    /// Every pet forgets: trust, habits, finds, the plant and the nook.
    static func forgetAll(in store: UserDefaults) {
        for kind in DeskPetKind.allCases {
            store.removeObject(forKey: key(kind))
            store.removeObject(forKey: oldTrustKey(kind))
        }
        store.removeObject(forKey: oldGrowthKey)
    }
}

/// What the pet can tell about the person's work, without being part of it.
struct DeskPetContext: Equatable, Sendable {
    /// An agent is running.
    var running = false
    /// A task waits on the person: a question, a failure, a stuck agent.
    var waiting = false
    /// Hosted tasks, 0 to 3.
    var tasks = 0
    /// The Bluetooth link to the Mac is up: the person is anchored at the desk.
    var linked = false
    /// Today's anchoring has reached its goal.
    var goalReached = false

    /// Nothing runs and nothing waits: the pet has the desk to itself.
    var free: Bool { !running && !waiting }

    static func of(_ sessions: [AnchorSession]) -> DeskPetContext {
        let processes = sessions.flatMap(\.taskProcesses)
        return DeskPetContext(
            running: processes.contains { $0.status == .running || $0.status == .queued },
            waiting: processes.contains(where: \.needsRescue),
            tasks: sessions.count)
    }
}

/// Where the pet is drawn: its nook on the landscape desk, where it walks and
/// uses its things, or small and in place beside the home greeting.
enum DeskPetStage: Equatable, Sendable {
    case nook(room: Int)
    case compact

    var room: Int? {
        if case let .nook(room) = self { room } else { nil }
    }
}
#endif
