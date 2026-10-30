#if os(iOS)
import AVFAudio
import Foundation
import UIKit

/// The tour's sounds, all made here rather than recorded: the pet's voice,
/// a chirping babble that follows the shape of the words it says (Chinese
/// tones, English syllables, a question's rise), and a few effects for the
/// moments that matter. They follow the Ring/Silent switch and mix with
/// whatever else is playing; a tap on the pet's line silences them.
@MainActor
final class TourSound {
    static let shared = TourSound()
    static let mutedKey = "anchor.tour.muted"

    enum Effect: CaseIterable, Sendable {
        /// The anchor hits the water, and a little fanfare follows.
        case anchored
        /// A line read aloud was heard.
        case ding
        /// A question waits on the desk.
        case question
        /// The Bluetooth link breaks.
        case snap
        /// Five minutes away.
        case away
        /// The link joins again.
        case rejoin
        /// One minute on the dial.
        case tick
    }

    private let output = TourAudioOutput()
    /// Which line is the latest; a slower render of an older one is dropped.
    private var line = 0

    /// Set from the speaker on the pet's line.
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

    func play(_ effect: Effect) {
        guard !isMuted else { return }
        output.play(effect)
    }

    /// The tour is over: the engine stops and other audio gets its volume back.
    func stop() {
        line += 1
        output.stop()
    }
}

/// The engine behind the tour's sounds. Switching the audio session and
/// starting the engine can hold a phone for a moment, and an effect is made
/// the first time it plays, so all of it runs on its own queue, in the order
/// the tour asks, and never on the main thread.
private final class TourAudioOutput: @unchecked Sendable {
    private let queue = DispatchQueue(label: "anchor.tour.sound", qos: .userInitiated)
    private let engine = AVAudioEngine()
    private let voice = AVAudioPlayerNode()
    private let effects = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: TourSynth.rate, channels: 1)!
    private var rendered: [TourSound.Effect: AVAudioPCMBuffer] = [:]

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
            if let buffer = buffer(samples) { schedule(buffer, on: voice) }
        }
    }

    func hush() {
        queue.async { [self] in voice.stop() }
    }

    func play(_ effect: TourSound.Effect) {
        queue.async { [self] in
            if rendered[effect] == nil { rendered[effect] = buffer(TourSynth.render(effect)) }
            if let buffer = rendered[effect] { schedule(buffer, on: effects) }
        }
    }

    func stop() {
        queue.async { [self] in
            voice.stop()
            effects.stop()
            engine.stop()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func schedule(_ buffer: AVAudioPCMBuffer, on node: AVAudioPlayerNode) {
        guard ready() else { return }
        // A new sound cuts the one before: ticks never queue up behind a fast dial.
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !node.isPlaying { node.play() }
    }

    /// Dictation takes the audio session for recording and lets it go when it
    /// stops; the engine comes back under the ambient category each time.
    private func ready() -> Bool {
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

    private func buffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }
}

// MARK: The voice

/// One chirp of the pet's voice: a vowel, the sound before it, and the way
/// its pitch moves.
struct TourSyllable: Equatable, Sendable {
    enum Onset: Sendable { case none, stop, hiss, soft }
    /// How the pitch moves across the syllable, in semitones.
    enum Contour: Sendable {
        /// Chinese first tone: high and level.
        case high
        /// Second tone: rising.
        case rise
        /// Third tone: low, dipping.
        case dip
        /// Fourth tone: falling.
        case fall
        /// A neutral tone, or an unstressed English syllable.
        case light
        /// A stressed English syllable, or a question's end.
        case lift
        /// The end of a sentence.
        case drop
    }

    var vowel: Character
    var onset: Onset
    var contour: Contour
    /// A small fixed nudge, so the same word always sounds the same.
    var lift: Double
    var length: Double
    var pause: Double
}

enum TourBabble {
    /// Long lines are cut short; the bubble still shows every word.
    static let most = 44

    static func pitch(of kind: DeskPetKind) -> Double {
        switch kind {
        case .crab, .off: 470
        case .squid: 540
        case .octopus: 390
        case .hermit: 430
        case .jelly: 610
        }
    }

    static func length(of syllables: [TourSyllable]) -> TimeInterval {
        syllables.reduce(0) { $0 + $1.length + $1.pause }
    }

    /// Chinese characters chirp one each, in their own tone; English words
    /// one chirp per vowel group, up to three; punctuation gives a breath,
    /// and a sentence falls at its end or rises at a question.
    static func syllables(of text: String) -> [TourSyllable] {
        var syllables: [TourSyllable] = []
        var word = ""

        func endWord() {
            guard !word.isEmpty else { return }
            syllables += english(word)
            word = ""
        }

        func breathe(_ seconds: Double, ending contour: TourSyllable.Contour? = nil) {
            guard !syllables.isEmpty else { return }
            syllables[syllables.count - 1].pause += seconds
            if let contour { syllables[syllables.count - 1].contour = contour }
        }

        for character in text {
            if character.isLetter, character.unicodeScalars.first?.properties.isIdeographic == true {
                endWord()
                if let syllable = chinese(character) { syllables.append(syllable) }
            } else if character.isLetter || character == "'" || character == "’" {
                word.append(character)
            } else if character.isNumber {
                endWord()
                syllables.append(TourSyllable(vowel: "i", onset: .stop, contour: .light,
                                              lift: nudge(character), length: 0.08, pause: 0.02))
            } else {
                endWord()
                switch character {
                case "?", "？": breathe(0.26, ending: .lift)
                case ".", "。", "!", "！": breathe(0.26, ending: .drop)
                case ",", "，", "、", ";", "；", ":", "：", "—": breathe(0.15)
                case " ": breathe(0.03)
                default: break
                }
            }
        }
        endWord()
        if let last = syllables.last, last.contour != .lift, last.contour != .drop {
            syllables[syllables.count - 1].contour = .drop
        }
        return Array(syllables.prefix(most))
    }

    /// Mandarin's tone and vowels, read from the character's pinyin.
    static func chinese(_ character: Character) -> TourSyllable? {
        guard let pinyin = String(character).applyingTransform(.mandarinToLatin, reverse: false)?
            .decomposedStringWithCanonicalMapping else { return nil }
        var tone = 0
        var letters = ""
        var umlaut = false
        for scalar in pinyin.unicodeScalars {
            switch scalar.value {
            case 0x0304: tone = 1
            case 0x0301: tone = 2
            case 0x030C: tone = 3
            case 0x0300: tone = 4
            case 0x0308: umlaut = true
            default: letters.unicodeScalars.append(scalar)
            }
        }
        letters = letters.lowercased()
        guard let first = letters.first else { return nil }
        let vowel: Character = if letters.contains("a") { "a" } else if letters.contains("o") { "o" }
            else if letters.contains("e") { "e" } else if umlaut { "y" }
            else { letters.last { "iu".contains($0) } ?? "e" }
        let contour: TourSyllable.Contour = switch tone {
        case 1: .high
        case 2: .rise
        case 3: .dip
        case 4: .fall
        default: .light
        }
        return TourSyllable(vowel: vowel, onset: onset(first), contour: contour,
                            lift: nudge(character), length: tone == 3 ? 0.1 : (tone == 0 ? 0.06 : 0.085),
                            pause: 0.02)
    }

    static func english(_ word: String) -> [TourSyllable] {
        let letters = Array(word.lowercased())
        var syllables: [TourSyllable] = []
        var index = 0
        while index < letters.count, syllables.count < 3 {
            guard "aeiouy".contains(letters[index]) else {
                index += 1
                continue
            }
            let before = index > 0 ? letters[index - 1] : nil
            let vowel = letters[index] == "y" ? "i" : letters[index]
            syllables.append(TourSyllable(vowel: vowel, onset: before.map(onset) ?? .none,
                                          contour: syllables.isEmpty ? .lift : .light,
                                          lift: nudge(letters[index]) + Double(word.count % 3) * 0.4,
                                          length: syllables.isEmpty ? 0.09 : 0.07, pause: 0.015))
            while index < letters.count, "aeiouy".contains(letters[index]) { index += 1 }
        }
        if syllables.isEmpty {
            syllables.append(TourSyllable(vowel: "e", onset: .soft, contour: .light, lift: 0, length: 0.07, pause: 0.015))
        }
        syllables[syllables.count - 1].pause += 0.035
        return syllables
    }

    private static func onset(_ letter: Character) -> TourSyllable.Onset {
        switch letter {
        case "b", "p", "d", "t", "g", "k": .stop
        case "s", "c", "z", "x", "f", "h", "j", "q": .hiss
        case "m", "n", "l", "r", "w", "y", "v": .soft
        default: .none
        }
    }

    /// Between -1.2 and 1.2 semitones, fixed for a character.
    private static func nudge(_ character: Character) -> Double {
        let value = UInt64(character.unicodeScalars.first?.value ?? 0)
        return Double((value &* 2_654_435_761) % 1_000) / 1_000 * 2.4 - 1.2
    }

    /// The babble as samples: each vowel built from harmonics shaped by its
    /// two formants (raised a little, for a small creature), sliding along
    /// its contour, with a puff or tap of noise for the consonant before it.
    nonisolated static func render(_ syllables: [TourSyllable], pitch: Double) -> [Float] {
        let rate = TourSynth.rate
        var out: [Float] = []
        var noise = TourSynth.Noise(seed: 7)
        var vibrato = 0.0
        for syllable in syllables {
            let count = Int(syllable.length * rate)
            let (f1, f2) = formants(syllable.vowel)
            let middle = pitch * pow(2, (semitones(syllable.contour, at: 0.5) + syllable.lift) / 12)
            let harmonics = max(3, min(14, Int(5_200 / middle)))
            var weights = (1...harmonics).map { k -> Double in
                let f = Double(k) * middle
                return 1 / (1 + pow((f - f1) / 260, 2)) + 0.7 / (1 + pow((f - f2) / 340, 2)) + 0.12 / Double(k)
            }
            let total = weights.reduce(0, +)
            weights = weights.map { $0 / total }
            var phase = 0.0
            let start = out.count
            out.reserveCapacity(start + count + Int(syllable.pause * rate))
            for i in 0..<count {
                let x = Double(i) / Double(count)
                vibrato += 2 * .pi * 7 / rate
                let f = pitch * pow(2, (semitones(syllable.contour, at: x) + syllable.lift) / 12) * (1 + 0.008 * sin(vibrato))
                phase += 2 * .pi * f / rate
                var value = 0.0
                for (k, weight) in weights.enumerated() { value += weight * sin(Double(k + 1) * phase) }
                let t = Double(i) / rate
                let attack = min(1, t / 0.008)
                let release = min(1, Double(count - i) / rate / 0.03)
                out.append(Float(value * attack * release * 0.9))
            }
            // The consonant: a short puff of noise over the vowel's start.
            let (puff, loudness): (Double, Double) = switch syllable.onset {
            case .hiss: (0.03, 0.10)
            case .stop: (0.008, 0.22)
            case .soft: (0.012, 0.04)
            case .none: (0, 0)
            }
            for i in 0..<min(count, Int(puff * rate)) {
                let fade = 1 - Double(i) / (puff * rate)
                out[start + i] += Float(noise.next() * loudness * fade)
            }
            out.append(contentsOf: repeatElement(0, count: Int(syllable.pause * rate)))
        }
        return TourSynth.normalized(out, peak: 0.5)
    }

    private nonisolated static func semitones(_ contour: TourSyllable.Contour, at x: Double) -> Double {
        switch contour {
        case .high: 3
        case .rise: -1 + 4.5 * x
        case .dip: -2.5 - 2 * sin(.pi * min(1, x * 1.4))
        case .fall: 4.5 - 6.5 * x
        case .light: 0.5 - x
        case .lift: 1 + 3.5 * x
        case .drop: 1.5 - 5 * x
        }
    }

    private nonisolated static func formants(_ vowel: Character) -> (Double, Double) {
        switch vowel {
        case "a": (1_050, 1_650)
        case "o": (700, 1_150)
        case "u": (480, 1_000)
        case "i": (420, 2_900)
        case "y": (460, 2_300)
        default: (700, 2_250)
        }
    }
}

// MARK: The effects

enum TourSynth {
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

    nonisolated static func render(_ effect: TourSound.Effect) -> [Float] {
        switch effect {
        case .anchored: normalized(mix(splash(), fanfare(), at: 0.22), peak: 0.75)
        case .ding: normalized(bell([1_568, 2_352], length: 0.7, decay: 0.22), peak: 0.45)
        case .question: normalized(mix(bell([1_319], length: 0.5, decay: 0.18), bell([1_047], length: 0.8, decay: 0.3), at: 0.14), peak: 0.5)
        case .snap: normalized(mix(click(length: 0.03, loudness: 1), sweep(from: 900, to: 260, length: 0.16)), peak: 0.55)
        case .away: normalized(mix(bell([784], length: 0.6, decay: 0.25), bell([988], length: 0.8, decay: 0.3), at: 0.12), peak: 0.4)
        case .rejoin: normalized(mix(mix(bell([880], length: 0.3, decay: 0.12), bell([1_175], length: 0.35, decay: 0.12), at: 0.09),
                                     bell([1_760], length: 0.7, decay: 0.25), at: 0.18), peak: 0.5)
        case .tick: normalized(mix(click(length: 0.006, loudness: 1), bell([2_400], length: 0.025, decay: 0.008)), peak: 0.22)
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
}
#endif
