// Role: leftover syllable generator from the removed pet voice. It is kept but not part of the tour's sound now.

#if os(iOS)
import Foundation

/// The pet's voice, made here rather than recorded: a chirping babble that
/// follows the shape of the words it says (Chinese tones, English syllables, a
/// question's rise). It waits in `AnchorSound` until the tour has a character to give it.

/// One chirp of the pet's voice: a vowel, the sound before it, and the way
/// its pitch moves.
struct TourSyllable: Equatable, Sendable {
    /// The sound before the vowel.
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

/// Turns text into syllables.
enum TourBabble {
    /// Long lines are cut short; the bubble still shows every word.
    static let most = 44

    static func pitch(of kind: DeskPetKind) -> Double {
        switch kind {
        case .crab, .off: 470
        case .whale: 330
        case .octopus: 390
        case .hermit: 430
        case .jelly: 610
        case .starfish: 660
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
        let rate = AnchorSynth.rate
        var out: [Float] = []
        var noise = AnchorSynth.Noise(seed: 7)
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
        return AnchorSynth.normalized(out, peak: 0.5)
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
#endif
