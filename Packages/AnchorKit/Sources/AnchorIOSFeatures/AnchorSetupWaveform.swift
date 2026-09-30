#if os(iOS)
import AnchorDesign
import SwiftUI

/// Actual microphone energy remains visible even with Reduce Motion enabled.
struct AnchorSetupWaveform: View {
    let level: Double
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    var body: some View {
        let energy = min(1, max(0, level))
        HStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { index in
                // Keep every bar readable; the former envelope made most bars
                // tiny even when the microphone was receiving normal speech.
                let envelope = 0.45 + 0.55 * abs(sin(Double(index) * 1.71))
                Capsule()
                    .fill(AnchorSetupStyle.accent)
                    .frame(width: 2, height: max(2, energy * envelope * 40))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 40)
        // Animate actual bar geometry, rather than a Canvas drawing closure.
        .animation(reduceMotion ? nil : .easeOut(duration: 0.06), value: energy)
        .accessibilityHidden(true)
    }
}
#endif
