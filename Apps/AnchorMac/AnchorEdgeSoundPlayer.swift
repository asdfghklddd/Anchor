import AnchorMacFeatures
import AppKit
import AVFoundation

/// Plays quiet, synthesized water and wood cues only for rare anchor state changes.
@MainActor
final class AnchorEdgeSoundPlayer {
    private let defaults: UserDefaults
    private let isUITesting: Bool
    private var activeSound: AVAudioPlayer?

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
        // A slight pitch drift keeps repeated cues from sounding mechanical.
        let pitch = Double.random(in: 0.975...1.025)
        guard let sound = try? AVAudioPlayer(
            data: AnchorEdgeSoundSynthesizer.wavData(for: cue, pitch: pitch)
        ) else {
            return
        }

        sound.volume = volume(for: cue)
        // The cue comes from the boat's corner of the screen.
        sound.pan = 0.35
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

    private func volume(for cue: AnchorEdgeSoundCue) -> Float {
        // Calibrated against the former Bottle/Tink cues (about -51 dB RMS at their
        // volumes): landing and retrieval sit about 6 dB above them, receipts below.
        switch cue {
        case .anchorLanded: 0.027
        case .anchorJoined: 0.038
        case .anchorReleased: 0.016
        case .anchorRetrieved: 0.025
        }
    }
}
