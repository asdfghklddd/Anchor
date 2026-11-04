import Foundation
import Testing
@testable import AnchorIOSFeatures

@Suite("Anchor sounds")
struct AnchorSoundTests {
    @Test func everyEffectIsMadeAndEndsWithoutAClick() {
        for effect in AnchorSoundEffect.allCases {
            let samples = AnchorSynth.render(effect)
            #expect(!samples.isEmpty, "\(effect)")
            #expect(samples.allSatisfy { abs($0) <= 0.76 }, "\(effect)")
            #expect(samples.last == 0, "\(effect)")
        }
    }

    /// Daily sounds stay out of the way: the small ones are the quietest and shortest.
    @Test func dailySoundsAreQuietAndShort() {
        func peak(_ effect: AnchorSoundEffect) -> Float { AnchorSynth.render(effect).reduce(0) { max($0, abs($1)) } }
        func seconds(_ effect: AnchorSoundEffect) -> Double { Double(AnchorSynth.render(effect).count) / AnchorSynth.rate }

        #expect(peak(.cardTap) < peak(.step) && peak(.step) < peak(.ding))
        #expect(peak(.launchSplash) <= 0.3)
        #expect(seconds(.cardTap) < 0.1 && seconds(.step) < 0.3 && seconds(.cardOpen) < 0.2)
        #expect(seconds(.launchSplash) < 0.5 && seconds(.drop) < 1)
    }

    /// Set ANCHOR_SOUND_EXPORT to a folder to get every effect as a WAV to listen to.
    @Test func exportsForListening() throws {
        guard let folder = ProcessInfo.processInfo.environment["ANCHOR_SOUND_EXPORT"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for effect in AnchorSoundEffect.allCases {
            try wav(AnchorSynth.render(effect)).write(to: directory.appending(path: "\(effect).wav"))
        }
    }

    private func wav(_ samples: [Float]) -> Data {
        func le<T: FixedWidthInteger>(_ value: T) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
        let pcm = samples.reduce(into: Data(capacity: samples.count * 2)) { data, sample in
            data += le(Int16(max(-1, min(1, sample)) * 32_767))
        }
        let rate = UInt32(AnchorSynth.rate)
        var out = Data("RIFF".utf8) + le(UInt32(36 + pcm.count)) + Data("WAVEfmt ".utf8)
        out += le(UInt32(16)) + le(UInt16(1)) + le(UInt16(1)) + le(rate) + le(rate * 2) + le(UInt16(2)) + le(UInt16(16))
        return out + Data("data".utf8) + le(UInt32(pcm.count)) + pcm
    }
}
