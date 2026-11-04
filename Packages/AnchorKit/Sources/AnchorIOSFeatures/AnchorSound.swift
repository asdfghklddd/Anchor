import Foundation
#if os(iOS)
import AVFAudio
import UIKit
#endif

/// Every sound in the app. They are made here rather than recorded, kept quiet
/// and short, and mark only moments when something really changed: a press is
/// felt and seen, not heard.
enum AnchorSoundEffect: CaseIterable, Sendable {
    // The tour.
    /// The tour's first drop: the anchor hits the water, and a little fanfare follows.
    case anchored
    /// A line read aloud was heard; on the desk, a result arrived.
    case ding
    /// A question waits on the desk.
    case question
    /// The Bluetooth link breaks.
    case snap
    /// Five minutes away.
    case away
    /// The link joins again, and the person is back.
    case rejoin

    // Every day.
    /// The launch anchor meets the water, quietly, since this plays at every launch.
    case launchSplash
    /// A task is anchored: a thud in the water, then the anchor catches.
    case drop
    /// A plan step is checked.
    case step
    /// The plan's last step is checked.
    case planDone
    /// A task is finished: the anchor comes up.
    case taskDone
    /// A conversation on the desk failed.
    case failed
    /// A card on the desk lands in front.
    case cardTap
    /// A card on the desk opens.
    case cardOpen
    /// A card flies up to the Mac: a quick rising swoosh.
    case sendUp
}

#if os(iOS)
/// Plays the app's sounds. They follow the Ring/Silent switch and mix with
/// whatever else is playing.
@MainActor
final class AnchorSound {
    typealias Effect = AnchorSoundEffect

    static let shared = AnchorSound()
    static let mutedKey = "anchor.tour.muted"

    private let output = AnchorAudioOutput()
    /// Which line is the latest; a slower render of an older one is dropped.
    private var line = 0

    /// Set from the speaker on the pet's line, when the pet speaks.
    var isMuted: Bool { UserDefaults.standard.bool(forKey: Self.mutedKey) }

    private init() {}

    /// Says a line in the pet's voice and returns how long it takes, which
    /// the pet hops along to even when the sound is off. VoiceOver reads the
    /// line itself, so the babble keeps quiet under it.
    @discardableResult
    func say(_ text: String, as kind: DeskPetKind) -> TimeInterval {
        let syllables = TourBabble.syllables(of: text)
        line += 1
        guard !isMuted, !UIAccessibility.isVoiceOverRunning else { return TourBabble.length(of: syllables) }
        let id = line
        let pitch = TourBabble.pitch(of: kind)
        Task {
            let samples = await Task.detached(priority: .userInitiated) {
                TourBabble.render(syllables, pitch: pitch)
            }.value
            guard id == line, !isMuted else { return }
            output.say(samples)
        }
        return TourBabble.length(of: syllables)
    }

    func hush() {
        line += 1
        output.hush()
    }

    /// Plays an effect, `delay` seconds from now so it can land with the motion on screen.
    func play(_ effect: Effect, after delay: TimeInterval = 0) {
        output.play(effect, after: delay)
    }

    /// The engine stops and other audio gets its volume back.
    func stop() {
        line += 1
        output.stop()
    }
}

/// The engine behind the sounds. Switching the audio session and starting the
/// engine can hold a phone for a moment, and an effect is made the first time
/// it plays, so all of it runs on its own queue and never on the main thread.
/// It stops a few seconds after the last sound: the desk stays up for hours.
private final class AnchorAudioOutput: @unchecked Sendable {
    private static let idleSeconds = 4.0

    private let queue = DispatchQueue(label: "anchor.sound", qos: .userInitiated)
    private let engine = AVAudioEngine()
    private let voice = AVAudioPlayerNode()
    private let effects = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: AnchorSynth.rate, channels: 1)!
    private var rendered: [AnchorSoundEffect: AVAudioPCMBuffer] = [:]
    /// Which sound was asked for last; only the last one's timer stops the engine.
    private var lastSound = 0

    init() {
        queue.async { [self] in
            engine.attach(voice)
            engine.attach(effects)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
            engine.connect(effects, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.8
        }
    }

    func say(_ samples: [Float]) {
        queue.async { [self] in
            if let buffer = buffer(samples) { schedule(buffer, on: voice, after: 0) }
        }
    }

    func hush() {
        queue.async { [self] in voice.stop() }
    }

    func play(_ effect: AnchorSoundEffect, after delay: TimeInterval) {
        queue.async { [self] in
            if rendered[effect] == nil { rendered[effect] = buffer(AnchorSynth.render(effect)) }
            if let buffer = rendered[effect] { schedule(buffer, on: effects, after: delay) }
        }
    }

    func stop() {
        queue.async { [self] in shutDown() }
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode, after delay: TimeInterval) {
        // Started ahead of a delayed sound, so the wait for the engine doesn't make it late.
        guard ready() else { return }
        lastSound += 1
        let sound = lastSound
        let length = Double(buffer.frameLength) / AnchorSynth.rate
        queue.asyncAfter(deadline: .now() + delay + length + Self.idleSeconds) { [self] in
            if sound == lastSound { shutDown() }
        }
        guard delay > 0 else { return start(buffer, on: node) }
        queue.asyncAfter(deadline: .now() + delay) { [self] in
            if ready() { start(buffer, on: node) }
        }
    }

    private func start(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        // A new sound cuts the one before: effects never queue up behind each other.
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        node.play()
    }

    /// Dictation takes the audio session for recording and lets it go when it
    /// stops. While it records no sound plays; after, the engine comes back
    /// under the ambient category.
    private func ready() -> Bool {
        guard !SpeechInputController.holdsAudioSession else { return false }
        let session = AVAudioSession.sharedInstance()
        if session.category != .ambient {
            try? session.setCategory(.ambient, options: [.mixWithOthers])
        }
        try? session.setActive(true)
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        return engine.isRunning
    }

    private func shutDown() {
        voice.stop()
        effects.stop()
        engine.stop()
        guard !SpeechInputController.holdsAudioSession else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }
}
#endif

// MARK: The synth

enum AnchorSynth {
    nonisolated static let rate = 44_100.0

    /// A small, fixed noise source, so every play sounds the same.
    struct Noise {
        var state: UInt64
        init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }
        mutating func next() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 20_000) / 10_000 - 1
        }
    }

    nonisolated static func render(_ effect: AnchorSoundEffect) -> [Float] {
        faded(samples(effect))
    }

    private static func samples(_ effect: AnchorSoundEffect) -> [Float] {
        switch effect {
        case .anchored: normalized(mix(splash(), fanfare(), at: 0.22), peak: 0.75)
        case .ding: normalized(bell([1_568, 2_352], length: 0.7, decay: 0.22), peak: 0.45)
        case .question: normalized(mix(bell([1_319], length: 0.5, decay: 0.18), bell([1_047], length: 0.8, decay: 0.3), at: 0.14), peak: 0.5)
        case .snap: normalized(mix(click(length: 0.03, loudness: 1), sweep(from: 900, to: 260, length: 0.16)), peak: 0.55)
        case .away: normalized(mix(bell([784], length: 0.6, decay: 0.25), bell([988], length: 0.8, decay: 0.3), at: 0.12), peak: 0.4)
        case .rejoin: normalized(mix(mix(bell([880], length: 0.3, decay: 0.12), bell([1_175], length: 0.35, decay: 0.12), at: 0.09),
                                     bell([1_760], length: 0.7, decay: 0.25), at: 0.18), peak: 0.5)
        case .launchSplash: normalized(plop(), peak: 0.3)
        // The catch comes where the drop's haptics put it, 0.48 s after the water.
        case .drop: normalized(mix(splash(), knock(), at: 0.48), peak: 0.55)
        case .step: normalized(bell([1_047, 2_094], length: 0.22, decay: 0.05), peak: 0.28)
        case .planDone: normalized(mix(mix(bell([784], length: 0.2, decay: 0.07), bell([1_047], length: 0.2, decay: 0.07), at: 0.08),
                                       bell([1_319, 2_637], length: 0.55, decay: 0.2), at: 0.16), peak: 0.4)
        case .taskDone: normalized(mix(mix(sweep(from: 300, to: 620, length: 0.14, loudness: 0.5),
                                           bell([880], length: 0.22, decay: 0.08), at: 0.1),
                                       bell([1_319], length: 0.5, decay: 0.18), at: 0.2), peak: 0.4)
        case .failed: normalized(mix(tone(392, length: 0.26, decay: 0.09), tone(311, length: 0.4, decay: 0.14), at: 0.13), peak: 0.34)
        case .cardTap: normalized(mix(thud(240, length: 0.06, decay: 0.022), rustle(length: 0.03, decay: 0.01, smoothing: 0.25, seed: 5)), peak: 0.18)
        case .cardOpen: normalized(mix(air(length: 0.14, from: 0.08, to: 0.3), sweep(from: 420, to: 760, length: 0.1, loudness: 0.35)), peak: 0.2)
        case .sendUp: normalized(swoosh(length: 0.3), peak: 0.46)
        }
    }

    /// A low thump that sinks in pitch, a spray of water, and bubbles rising after.
    private static func splash() -> [Float] {
        var out = sweep(from: 120, to: 38, length: 0.42, shape: 2.2)
        var noise = Noise(seed: 3)
        var smooth = 0.0
        let spray = Int(0.55 * rate)
        if out.count < spray { out += repeatElement(0, count: spray - out.count) }
        for i in 0..<spray {
            let t = Double(i) / rate
            smooth += (noise.next() - smooth) * 0.35
            out[i] += Float(smooth * exp(-t / 0.12) * min(1, t / 0.01) * 0.9)
        }
        for (start, pitch) in [(0.16, 520.0), (0.27, 700.0), (0.36, 610.0), (0.47, 820.0)] {
            out = mix(out, sweep(from: pitch, to: pitch * 1.9, length: 0.05, loudness: 0.35), at: start)
        }
        return out
    }

    /// A small plop: a short drop in pitch, a little water, two bubbles.
    private static func plop() -> [Float] {
        var out = mix(sweep(from: 190, to: 70, length: 0.16, shape: 1.6),
                      rustle(length: 0.28, decay: 0.07, smoothing: 0.3, seed: 9, loudness: 0.6))
        for (start, pitch) in [(0.12, 520.0), (0.2, 700.0)] {
            out = mix(out, sweep(from: pitch, to: pitch * 1.8, length: 0.05, loudness: 0.25), at: start)
        }
        return out
    }

    /// Wood on wood: the anchor catches and holds.
    private static func knock() -> [Float] {
        mix(thud(170, length: 0.1, decay: 0.03, loudness: 0.5), click(length: 0.008, loudness: 0.12))
    }

    /// Four rising notes, the last one held: the anchor is down.
    private static func fanfare() -> [Float] {
        var out: [Float] = []
        for (index, note) in [523.25, 659.25, 783.99, 1_046.5].enumerated() {
            let last = index == 3
            out = mix(out, tone(note, length: last ? 0.6 : 0.16, decay: last ? 0.32 : 0.08), at: Double(index) * 0.095)
        }
        return out
    }

    /// A warm note with a few odd harmonics, plucked.
    private static func tone(_ frequency: Double, length: Double, decay: Double) -> [Float] {
        (0..<Int(length * rate)).map { i in
            let t = Double(i) / rate
            let wave = sin(2 * .pi * frequency * t) + 0.3 * sin(6 * .pi * frequency * t) + 0.12 * sin(10 * .pi * frequency * t)
            return Float(wave * exp(-t / decay) * min(1, t / 0.005) * 0.5)
        }
    }

    private static func bell(_ partials: [Double], length: Double, decay: Double) -> [Float] {
        (0..<Int(length * rate)).map { i in
            let t = Double(i) / rate
            var wave = 0.0
            for (index, frequency) in partials.enumerated() { wave += sin(2 * .pi * frequency * t) / Double(index + 1) }
            return Float(wave * exp(-t / decay) * min(1, t / 0.003) * 0.6)
        }
    }

    /// A pure low note that dies at once.
    private static func thud(_ frequency: Double, length: Double, decay: Double, loudness: Double = 1) -> [Float] {
        (0..<Int(length * rate)).map { i in
            let t = Double(i) / rate
            return Float(sin(2 * .pi * frequency * t) * exp(-t / decay) * min(1, t / 0.002) * loudness)
        }
    }

    private static func sweep(from start: Double, to end: Double, length: Double, shape: Double = 1, loudness: Double = 1) -> [Float] {
        var phase = 0.0
        let count = Int(length * rate)
        return (0..<count).map { i in
            let x = Double(i) / Double(count)
            phase += 2 * .pi * (start + (end - start) * pow(x, 1 / shape)) / rate
            return Float(sin(phase) * (1 - x) * min(1, Double(i) / rate / 0.004) * loudness)
        }
    }

    private static func click(length: Double, loudness: Double) -> [Float] {
        var noise = Noise(seed: 11)
        let count = Int(length * rate)
        return (0..<count).map { i in Float(noise.next() * loudness * (1 - Double(i) / Double(count))) }
    }

    /// Soft noise that fades away: water, or paper.
    private static func rustle(length: Double, decay: Double, smoothing: Double, seed: UInt64, loudness: Double = 1) -> [Float] {
        var noise = Noise(seed: seed)
        var smooth = 0.0
        return (0..<Int(length * rate)).map { i in
            let t = Double(i) / rate
            smooth += (noise.next() - smooth) * smoothing
            return Float(smooth * exp(-t / decay) * min(1, t / 0.002) * loudness)
        }
    }

    /// Air moving past: noise that swells and fades, its pitch rising with `from` and `to`.
    private static func air(length: Double, from: Double, to: Double) -> [Float] {
        var noise = Noise(seed: 21)
        var smooth = 0.0
        let count = Int(length * rate)
        return (0..<count).map { i in
            let x = Double(i) / Double(count)
            smooth += (noise.next() - smooth) * (from + (to - from) * x)
            return Float(smooth * sin(.pi * x) * 1.6)
        }
    }

    /// Something leaving fast: a tone gliding up inside rising air, swelling late and cut short.
    private static func swoosh(length: Double) -> [Float] {
        var noise = Noise(seed: 33)
        var smooth = 0.0
        var phase = 0.0
        let count = Int(length * rate)
        return (0..<count).map { i in
            let x = Double(i) / Double(count)
            phase += 2 * .pi * (300 * pow(5.5, x * x)) / rate
            smooth += (noise.next() - smooth) * (0.05 + 0.65 * x)
            let swell = pow(sin(.pi * pow(x, 1.5)), 1.4)
            return Float((0.6 * sin(phase) + 0.9 * smooth) * swell)
        }
    }

    /// `b` laid over `a`, starting `seconds` in.
    nonisolated static func mix(_ a: [Float], _ b: [Float], at seconds: Double = 0) -> [Float] {
        let offset = Int(seconds * rate)
        var out = a
        if out.count < offset + b.count { out += repeatElement(0, count: offset + b.count - out.count) }
        for (index, sample) in b.enumerated() { out[offset + index] += sample }
        return out
    }

    nonisolated static func normalized(_ samples: [Float], peak: Float) -> [Float] {
        let loudest = samples.reduce(0) { max($0, abs($1)) }
        guard loudest > 0 else { return samples }
        return samples.map { $0 / loudest * peak }
    }

    /// The last few milliseconds fade to nothing, so a sound never ends on a click.
    private static func faded(_ samples: [Float]) -> [Float] {
        let count = min(samples.count, Int(0.008 * rate))
        var out = samples
        for i in 0..<count { out[samples.count - 1 - i] *= Float(i) / Float(count) }
        return out
    }
}
