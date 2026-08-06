#if os(iOS)
import AnchorDesign
import SwiftUI

struct StoryboardPreview: View {
    let tint: Color
    var compact = false
    var direction: String?

    var body: some View {
        GeometryReader { proxy in
            if let direction {
                directionalPreview(direction, size: proxy.size)
            } else {
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
            }

            Capsule()
                .fill(.white.opacity(0.7))
                .frame(width: proxy.size.width * 0.55, height: 2)
                .padding(.top, 3)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func directionalPreview(_ direction: String, size: CGSize) -> some View {
        let radius: CGFloat = compact ? 8 : 12
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(direction == "B" ? AnchorPalette.deepSea : direction == "C" ? Color(red: 0.97, green: 0.85, blue: 0.44) : Color(red: 0.86, green: 0.92, blue: 0.91))

            switch direction {
            case "A":
                RoundedRectangle(cornerRadius: radius * 0.75, style: .continuous)
                    .fill(.white.opacity(0.78))
                    .frame(width: size.width * 0.52, height: size.height * 0.66)
                    .offset(x: -size.width * 0.18)
                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: size.height * 0.30)
                    .offset(x: size.width * 0.22, y: -size.height * 0.19)
                Capsule()
                    .fill(AnchorPalette.source("ink").opacity(0.72))
                    .frame(width: size.width * 0.32, height: compact ? 3 : 4)
                    .offset(x: size.width * 0.20, y: size.height * 0.24)
            case "C":
                RoundedRectangle(cornerRadius: radius * 0.55, style: .continuous)
                    .fill(AnchorPalette.coral)
                    .frame(width: size.width * 0.44, height: size.height * 0.72)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -size.width * 0.17, y: size.height * 0.08)
                RoundedRectangle(cornerRadius: radius * 0.55, style: .continuous)
                    .fill(AnchorPalette.deepSea)
                    .frame(width: size.width * 0.35, height: size.height * 0.34)
                    .rotationEffect(.degrees(7))
                    .offset(x: size.width * 0.23, y: -size.height * 0.18)
                RoundedRectangle(cornerRadius: radius * 0.4, style: .continuous)
                    .fill(.white)
                    .frame(width: size.width * 0.30, height: compact ? 4 : 6)
                    .offset(x: size.width * 0.20, y: size.height * 0.22)
            default:
                Circle()
                    .fill(AnchorPalette.seafoam)
                    .frame(width: size.height * 0.42)
                    .offset(y: -size.height * 0.12)
                Capsule()
                    .fill(AnchorPalette.coral)
                    .frame(width: size.width * 0.34, height: compact ? 3 : 5)
                    .offset(x: -size.width * 0.20, y: size.height * 0.25)
                Capsule()
                    .fill(AnchorPalette.periwinkle)
                    .frame(width: size.width * 0.27, height: compact ? 3 : 5)
                    .offset(x: size.width * 0.22, y: size.height * 0.25)
            }
        }
        .clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}
#endif
