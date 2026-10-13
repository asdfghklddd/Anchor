#if os(macOS)
import Foundation
import Testing
@testable import AnchorMacFeatures

@Test("Every edge cue is short, bounded and click-free", arguments: AnchorEdgeSoundCue.allCases)
func edgeCuesAreBounded(cue: AnchorEdgeSoundCue) {
    let samples = AnchorEdgeSoundSynthesizer.samples(for: cue)
    let peak = samples.map { abs($0) }.max() ?? 0

    #expect(Double(samples.count) / AnchorEdgeSoundSynthesizer.sampleRate <= 0.65)
    #expect(peak > 0.05)
    #expect(peak <= 1)
    // Faded edges keep playback from clicking when a cue starts or is cut off.
    #expect(abs(samples.first ?? 1) < 0.001)
    #expect(abs(samples.last ?? 1) < 0.001)
}

@Test("Edge cues encode as playable 16-bit mono WAV")
func edgeCueWAVHeader() {
    let data = AnchorEdgeSoundSynthesizer.wavData(for: .anchorLanded)
    #expect(data.prefix(4) == Data("RIFF".utf8))
    #expect(data.dropFirst(8).prefix(4) == Data("WAVE".utf8))
    let sampleCount = AnchorEdgeSoundSynthesizer.samples(for: .anchorLanded).count
    #expect(data.count == 44 + sampleCount * 2)
}

@Test("A pitch variation changes the tuning, not the length")
func edgeCuePitchVariation() {
    let reference = AnchorEdgeSoundSynthesizer.samples(for: .anchorReleased)
    let varied = AnchorEdgeSoundSynthesizer.samples(for: .anchorReleased, pitch: 1.02)
    #expect(reference.count == varied.count)
    #expect(reference != varied)
}
#endif
