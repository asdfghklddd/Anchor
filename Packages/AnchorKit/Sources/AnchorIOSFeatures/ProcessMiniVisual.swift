#if os(iOS)
import SwiftUI

struct ProcessMiniVisual: View {
    let tone: String
    let tint: Color
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: 7)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 35, height: 35)
        .accessibilityHidden(true)
    }
}
#endif
