#if os(macOS)
import Foundation

/// Renders the edge cues procedurally: small water and wood sounds that share the
/// boat's material, instead of stock alert sounds. Rendering is deterministic for a
/// given pitch, so tests can measure the cues and playback can vary them slightly.
public enum AnchorEdgeSoundSynthesizer {
    public static let sampleRate: Double = 44_100

    /// Mono samples in -1...1. `pitch` scales every frequency; 1 is the reference tuning.
    public static func samples(for cue: AnchorEdgeSoundCue, pitch: Double = 1) -> [Float] {
        var buffer = Buffer(duration: duration(of: cue))
        switch cue {
        case .anchorLanded:
            // A soft hull-deep thud, a brief splash hiss, then the bubbles of the plunge.
            buffer.thump(at: 0, from: 150 * pitch, to: 62 * pitch, decay: 0.075, amplitude: 0.42)
            buffer.splash(at: 0.004, decay: 0.05, amplitude: 0.13)
            buffer.bubble(at: 0.014, from: 520 * pitch, to: 1_150 * pitch, length: 0.075, amplitude: 0.50)
            buffer.bubble(at: 0.115, from: 760 * pitch, to: 1_480 * pitch, length: 0.055, amplitude: 0.26)
            buffer.bubble(at: 0.215, from: 1_020 * pitch, to: 1_900 * pitch, length: 0.04, amplitude: 0.13)
        case .anchorJoined:
            // The same water, smaller: one bubble and a trailing droplet.
            buffer.splash(at: 0, decay: 0.03, amplitude: 0.05)
            buffer.bubble(at: 0.006, from: 660 * pitch, to: 1_380 * pitch, length: 0.06, amplitude: 0.42)
            buffer.bubble(at: 0.095, from: 980 * pitch, to: 1_760 * pitch, length: 0.04, amplitude: 0.16)
        case .anchorReleased:
            // One soft wooden tock: the rope eased on its cleat.
            buffer.knock(at: 0, frequency: 587 * pitch, decay: 0.085, amplitude: 0.46)
        case .anchorRetrieved:
            // A drip off the rising anchor, then two rising knocks as it is stowed aboard.
            buffer.bubble(at: 0, from: 1_250 * pitch, to: 2_000 * pitch, length: 0.035, amplitude: 0.20)
            buffer.knock(at: 0.10, frequency: 523 * pitch, decay: 0.10, amplitude: 0.42)
            buffer.knock(at: 0.225, frequency: 784 * pitch, decay: 0.13, amplitude: 0.36)
        }
        return buffer.finished()
    }

    /// 16-bit mono PCM WAV for `AVAudioPlayer`.
    public static func wavData(for cue: AnchorEdgeSoundCue, pitch: Double = 1) -> Data {
        let pcm = samples(for: cue, pitch: pitch).map { Int16(max(-1, min(1, $0)) * Float(Int16.max)) }
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(pcm.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); append(36 + byteCount)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate * 2)); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(byteCount)
        pcm.forEach { append($0) }
        return data
    }

    static func duration(of cue: AnchorEdgeSoundCue) -> Double {
        switch cue {
        case .anchorLanded: 0.55
        case .anchorJoined: 0.30
        case .anchorReleased: 0.30
        case .anchorRetrieved: 0.62
        }
    }

    private struct Buffer {
        var samples: [Double]
        private var noiseSeed: UInt64 = 0x9E37_79B9_7F4A_7C15

        init(duration: Double) {
            samples = Array(repeating: 0, count: Int(duration * AnchorEdgeSoundSynthesizer.sampleRate))
        }

        /// A water-drop bubble: a sine whose pitch rises quickly as the cavity collapses.
        mutating func bubble(at start: Double, from f0: Double, to f1: Double, length: Double, amplitude: Double) {
            var phase = 0.0
            render(at: start, length: length * 4) { t in
                let sweep = f0 * pow(f1 / f0, min(1, t / length))
                phase += 2 * .pi * sweep / AnchorEdgeSoundSynthesizer.sampleRate
                return sin(phase) * amplitude * Self.envelope(t, attack: 0.003, decay: length / 2.6)
            }
        }

        /// A low body that drops in pitch, felt more than heard at these levels.
        mutating func thump(at start: Double, from f0: Double, to f1: Double, decay: Double, amplitude: Double) {
            var phase = 0.0
            render(at: start, length: decay * 5) { t in
                let frequency = f1 + (f0 - f1) * exp(-t / (decay * 0.6))
                phase += 2 * .pi * frequency / AnchorEdgeSoundSynthesizer.sampleRate
                return sin(phase) * amplitude * Self.envelope(t, attack: 0.004, decay: decay)
            }
        }

        /// Band-limited noise for the moment the surface breaks.
        mutating func splash(at start: Double, decay: Double, amplitude: Double) {
            var low = 0.0, lowest = 0.0
            let rate = AnchorEdgeSoundSynthesizer.sampleRate
            let a = 1 - exp(-2 * .pi * 5_200 / rate)
            let b = 1 - exp(-2 * .pi * 1_400 / rate)
            var seed = noiseSeed
            render(at: start, length: decay * 5) { t in
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let white = Double(Int64(bitPattern: seed >> 1) % 20_000) / 10_000 - 1
                low += a * (white - low)
                lowest += b * (low - lowest)
                return (low - lowest) * amplitude * Self.envelope(t, attack: 0.004, decay: decay)
            }
            noiseSeed = seed
        }

        /// A wooden knock: a damped fundamental with two quickly fading inharmonic partials.
        mutating func knock(at start: Double, frequency: Double, decay: Double, amplitude: Double) {
            let partials: [(ratio: Double, level: Double, decay: Double)] = [(1, 1, 1), (2.76, 0.32, 0.5), (5.40, 0.10, 0.3)]
            render(at: start, length: decay * 5) { t in
                partials.reduce(0) { sum, partial in
                    sum + sin(2 * .pi * frequency * partial.ratio * t) * partial.level
                        * Self.envelope(t, attack: 0.002, decay: decay * partial.decay)
                } * amplitude
            }
        }

        private mutating func render(at start: Double, length: Double, _ sample: (Double) -> Double) {
            let rate = AnchorEdgeSoundSynthesizer.sampleRate
            let first = Int(start * rate)
            let count = min(samples.count - first, Int(length * rate))
            guard first >= 0, count > 0 else { return }
            for index in 0..<count {
                samples[first + index] += sample(Double(index) / rate)
            }
        }

        private static func envelope(_ t: Double, attack: Double, decay: Double) -> Double {
            min(1, t / attack) * exp(-t / decay)
        }

        /// Softens the top end, then fades the edges so playback never clicks.
        func finished() -> [Float] {
            let rate = AnchorEdgeSoundSynthesizer.sampleRate
            let smoothing = 1 - exp(-2 * .pi * 7_000 / rate)
            var state = 0.0
            let fade = Int(0.004 * rate)
            return samples.enumerated().map { index, value in
                state += smoothing * (value - state)
                let edge = min(1, Double(index) / Double(fade), Double(samples.count - 1 - index) / Double(fade))
                return Float(state * max(0, edge))
            }
        }
    }
}
#endif
