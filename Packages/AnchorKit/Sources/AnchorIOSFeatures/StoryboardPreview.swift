#if os(iOS)
import AnchorDesign
import SwiftUI

struct StoryboardPreview: View {
    let tint: Color
    var compact = false

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = compact ? 3 : 5
            let frameWidth = max(12, (proxy.size.width - spacing * 2) / 3)

            HStack(spacing: spacing) {
                ForEach(0 ..< 3, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: compact ? 7 : 10, style: .continuous)
                            .fill(.white.opacity(0.82))
                        Circle()
                            .fill(tint.opacity(0.27 + Double(index) * 0.10))
                            .frame(width: frameWidth * 0.42)
                            .offset(
                                x: index == 1 ? frameWidth * 0.12 : -frameWidth * 0.08,
                                y: index == 2 ? -5 : 3
                            )
                        Capsule()
                            .fill(tint.opacity(0.72))
                            .frame(width: frameWidth * 0.56, height: compact ? 3 : 4)
                            .offset(y: frameWidth * 0.25)
                    }
                    .frame(width: frameWidth)
                }
            }
            .padding(compact ? 3 : 5)
            .background(tint.opacity(0.13), in: .rect(cornerRadius: compact ? 10 : 15, style: .continuous))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.7))
                    .frame(width: proxy.size.width * 0.55, height: 2)
                    .padding(.top, 3)
            }
        }
        .accessibilityHidden(true)
    }
}
#endif
