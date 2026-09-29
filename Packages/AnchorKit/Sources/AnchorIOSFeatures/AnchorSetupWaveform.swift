#if os(iOS)
import SwiftUI

/// The waveform responds to microphone energy. Reduced Motion keeps a still indicator.
struct AnchorSetupWaveform: View {
    let level: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Canvas { context, size in
            let energy = reduceMotion ? 0.4 : level
            let count = 30
            for index in 0..<count {
                let envelope = abs(sin(Double(index) * 1.71)) * (0.3 + abs(sin(Double(index) * 0.38)) * 0.7)
                let height = max(2, (0.2 + energy * 0.8) * envelope * size.height)
                let rect = CGRect(x: Double(index) * size.width / Double(count), y: (size.height - height) / 2, width: 1.2, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.6), with: .color(AnchorSetupStyle.accent))
            }
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }
}
#endif
