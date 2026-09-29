import AnchorMacFeatures
import AppKit

/// Plays very quiet system cues only for rare anchor state changes.
@MainActor
final class AnchorEdgeSoundPlayer {
    private let defaults: UserDefaults
    private let isUITesting: Bool
    private var activeSound: NSSound?

    init(
        defaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.defaults = defaults
        isUITesting = environment["ANCHOR_UI_TESTING"] == "1"
    }

    func play(_ cue: AnchorEdgeSoundCue) {
        guard !isUITesting, isEnabled else { return }

        activeSound?.stop()
        guard let source = NSSound(named: soundName(for: cue)),
              let sound = source.copy() as? NSSound else {
            return
        }

        sound.volume = volume(for: cue)
        sound.loops = false
        activeSound = sound
        sound.play()
    }

    func stop() {
        activeSound?.stop()
        activeSound = nil
    }

    private var isEnabled: Bool {
        defaults.object(forKey: AnchorEdgeSoundCue.enabledDefaultsKey) as? Bool ?? true
    }

    private func soundName(for cue: AnchorEdgeSoundCue) -> NSSound.Name {
        switch cue {
        case .anchorLanded:
            NSSound.Name("Bottle")
        case .anchorRetrieved:
            NSSound.Name("Tink")
        }
    }

    private func volume(for cue: AnchorEdgeSoundCue) -> Float {
        switch cue {
        case .anchorLanded:
            0.035
        case .anchorRetrieved:
            0.025
        }
    }
}
