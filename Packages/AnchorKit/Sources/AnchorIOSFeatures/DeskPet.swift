#if os(iOS)
import AnchorDesign
import SwiftUI

/// Which pet keeps the landscape desk company; chosen in Settings.
enum DeskPetKind: String, CaseIterable, Identifiable, Sendable {
    case crab
    case squid
    case octopus
    case hermit
    case jelly
    case off

    static let defaultsKey = "anchor.desk.pet"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .crab: AnchorStrings.value("settings.deskPet.crab", default: "Crab")
        case .squid: AnchorStrings.value("settings.deskPet.squid", default: "Squid kid")
        case .octopus: AnchorStrings.value("settings.deskPet.octopus", default: "Octopus")
        case .hermit: AnchorStrings.value("settings.deskPet.hermit", default: "Hermit crab")
        case .jelly: AnchorStrings.value("settings.deskPet.jelly", default: "Jellyfish")
        case .off: AnchorStrings.value("settings.deskPet.off", default: "Off")
        }
    }

    /// How much this pet trusts the person, kept across launches.
    var trustKey: String { "anchor.desk.pet.trust.\(rawValue)" }
}

/// What the desk is doing, which sets the pet's background behavior.
enum DeskPetMood: Hashable {
    /// An agent runs: the pet types.
    case working
    /// Nothing runs and it is the person's move: the pet lives its day.
    case yourMove
    /// Nothing has happened for a long while: the pet sleeps.
    case quiet
}

/// Counts of desk news since the board came up; each rise is one event.
struct DeskPetSignals: Equatable {
    var results = 0
    var failures = 0
    var questions = 0
}

/// A small pixel pet at the foot of the desk clock. Its life runs in
/// `DeskPetBrain` (desk events first, then touch, then daily life) and is
/// drawn by `DeskPetRenderer` at 8 fps. A tap, a burst of taps and a long
/// press each get an answer that depends on the pet and on how it feels.
/// With reduced motion it holds still and only changes pose with the desk.
struct DeskPet: View {
    let kind: DeskPetKind
    let mood: DeskPetMood
    var signals = DeskPetSignals()
    var hour = 12

    @AnchorReducedMotion private var reduceMotion
    @State private var brain: DeskPetBrain?
    @State private var columns = 0
    @State private var touches = 0

    /// Points per sprite pixel.
    static let pixel: CGFloat = 3
    /// The tallest pet plus room above for a hat, a bulb or z's.
    static let rows = 30
    static let height = CGFloat(rows) * pixel

    var body: some View {
        Canvas { context, _ in
            draw(in: context)
        }
        .frame(height: Self.height)
        .onGeometryChange(for: Int.self) { Int($0.size.width / Self.pixel) } action: { columns = $0 }
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0.5) {
            touches += 1
            brain?.press()
            keepTrust()
        }
        .onTapGesture {
            touches += 1
            brain?.tap()
            keepTrust()
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: touches)
        .onChange(of: kind, initial: true) {
            let saved = ProfilePreferences.store.object(forKey: kind.trustKey) as? Double
            brain = DeskPetBrain(kind: kind, trust: saved ?? 0.3)
        }
        .onChange(of: signals) { old, new in
            // The weightiest news wins when several land together.
            if new.failures > old.failures { brain?.hear(.failure) }
            else if new.questions > old.questions { brain?.hear(.question) }
            else if new.results > old.results { brain?.hear(.result) }
        }
        // Restarts with a new mood or hour, so the loop never runs on stale ones.
        .task(id: Loop(still: reduceMotion, mood: mood, hour: hour, kind: kind)) {
            brain?.set(mood: mood, hour: hour)
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                brain?.step(room: room)
                try? await Task.sleep(for: .milliseconds(125))
            }
        }
        .accessibilityHidden(true)
    }

    private struct Loop: Hashable {
        let still: Bool
        let mood: DeskPetMood
        let hour: Int
        let kind: DeskPetKind
    }

    private var look: DeskPetLook { .of(kind) }

    /// Columns the pet can walk across; the right edge keeps room for z's.
    private var room: Int { max(0, columns - look.width - 6) }

    private func keepTrust() {
        guard let trust = brain?.trust else { return }
        ProfilePreferences.store.set(trust, forKey: kind.trustKey)
    }

    private func draw(in context: GraphicsContext) {
        guard kind != .off, let brain else { return }
        let frame: DeskPetFrame
        if reduceMotion {
            let pose: DeskPetAct = switch mood {
            case .working: .type
            case .yourMove: .idle
            case .quiet: .sleep
            }
            frame = DeskPetFrame(act: pose, still: true)
        } else {
            frame = DeskPetFrame(act: brain.act, progress: brain.progress, length: brain.length,
                                 tick: brain.tick, facing: brain.facing)
        }
        DeskPetRenderer(look: look, kind: kind, context: context, left: min(brain.x, room) + 1,
                        ground: Self.rows - 1, pixel: Self.pixel).draw(frame)
    }
}

/// A still pet for Settings.
struct DeskPetPortrait: View {
    let kind: DeskPetKind
    var pixel: CGFloat = 2

    var body: some View {
        let look = DeskPetLook.of(kind)
        Canvas { context, size in
            let columns = Int(size.width / pixel)
            let rows = Int(size.height / pixel)
            DeskPetRenderer(look: look, kind: kind, context: context, left: max(0, (columns - look.width) / 2),
                            ground: rows - 1 - (kind == .jelly ? 0 : 1), pixel: pixel)
                .draw(DeskPetFrame(still: true))
        }
        .accessibilityHidden(true)
    }
}
#endif
