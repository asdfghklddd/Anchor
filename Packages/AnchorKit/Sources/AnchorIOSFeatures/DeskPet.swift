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
}

/// Counts of desk news since the board came up; each rise is one event.
struct DeskPetSignals: Equatable {
    var results = 0
    var failures = 0
    var questions = 0
}

/// A small pixel pet at the foot of the desk clock, in its own millennium-era
/// nook (`DeskScene`). It is the same pet as on the home screen
/// (`DeskPetLife`), with room here to walk and things to use. A tap, a burst
/// of taps and a long press each get an answer that depends on the pet and
/// on how it feels; a tap on something in the nook works that thing, and the
/// pet's own thing draws it over to use it. With reduced motion it holds
/// still and only changes pose with the desk.
struct DeskPet: View {
    let kind: DeskPetKind
    var context = DeskPetContext()
    var signals = DeskPetSignals()

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var life = DeskPetLife.shared
    @State private var columns = 0
    @State private var touches = 0

    /// Points per sprite pixel.
    static let pixel: CGFloat = 3
    static let height = CGFloat(DeskScene.rows) * pixel

    var body: some View {
        Canvas { context, _ in
            draw(in: context)
        }
        .frame(height: Self.height)
        .onGeometryChange(for: Int.self) { Int($0.size.width / Self.pixel) } action: { columns = $0 }
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0.5) {
            touches += 1
            life.press()
        }
        .gesture(SpatialTapGesture().onEnded { touch(at: $0.location) })
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: touches)
        .onChange(of: kind, initial: true) { life.use(kind) }
        .onChange(of: context, initial: true) { life.update(desk: context) }
        .onChange(of: signals) { old, new in
            // The weightiest news wins when several land together.
            if new.failures > old.failures { life.hear(.failure) }
            else if new.questions > old.questions { life.hear(.question) }
            else if new.results > old.results { life.hear(.result) }
        }
        .task(id: Loop(still: reduceMotion, kind: kind)) {
            guard !reduceMotion else {
                life.settle(now: .now)
                return
            }
            while !Task.isCancelled {
                // Until the nook has a width, the pet keeps its place.
                if columns > 0 { life.advance(now: .now, stage: .nook(room: room)) }
                try? await Task.sleep(for: .milliseconds(125))
            }
        }
        .onDisappear { life.save() }
        .onChange(of: scenePhase) { if scenePhase != .active { life.save() } }
        .accessibilityHidden(true)
    }

    private struct Loop: Hashable {
        let still: Bool
        let kind: DeskPetKind
    }

    private var look: DeskPetLook { .of(kind) }

    /// Columns the pet can walk across; the right edge keeps room for z's.
    private var room: Int { max(0, columns - look.width - 6) }

    private func petLeft(_ brain: DeskPetBrain) -> Int { min(brain.x, room) + 1 }

    /// A touch on the pet reaches the pet; one on a thing in the nook works it.
    private func touch(at location: CGPoint) {
        guard let brain = life.brain else { return }
        let cell = CGPoint(x: location.x / Self.pixel, y: location.y / Self.pixel)
        let pet = CGRect(x: petLeft(brain), y: DeskScene.floor - look.height - 3, width: look.width, height: look.height + 3)
        touches += 1
        if pet.contains(cell) {
            life.tap()
        } else if let thing = DeskScene.thing(at: cell, for: kind) {
            life.use(thing)
        }
    }

    private func screen(_ brain: DeskPetBrain) -> DeskScene.Screen {
        if brain.sleeping { return .off }
        if context.running { return .code }
        return brain.memory.screensaver ? .stars : .desktop
    }

    private func draw(in graphics: GraphicsContext) {
        guard kind != .off, let brain = life.brain, brain.kind == kind else { return }
        DeskSceneRenderer(kind: kind, context: graphics, pixel: Self.pixel, tick: brain.tick, hour: brain.hour,
                          state: DeskScene.State(brain), screen: screen(brain),
                          music: !reduceMotion && (brain.act == .dance || brain.act == .sway)).draw()
        DeskPetRenderer(look: look, kind: kind, context: graphics, left: petLeft(brain),
                        ground: DeskScene.floor - 1, pixel: Self.pixel).draw(DeskPetFrame(brain, still: reduceMotion))
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
