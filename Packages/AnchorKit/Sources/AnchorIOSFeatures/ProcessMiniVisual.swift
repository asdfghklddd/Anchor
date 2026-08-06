#if os(iOS)
import SwiftUI

struct ProcessMiniVisual: View {
    let tone: String
    let tint: Color
    let progress: Double

    @ViewBuilder
    var body: some View {
        switch tone {
        case "coral":
            HStack(alignment: .center, spacing: 3) {
                ForEach([12, 21, 16, 27, 19, 24, 14], id: \.self) { height in
                    Capsule()
                        .fill(tint.opacity(0.78))
                        .frame(width: 4, height: CGFloat(height))
                }
            }
            .frame(height: 32)

        case "cyan":
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.16), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(0.05, progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 35, height: 35)

        case "periwinkle", "blue":
            ZStack(alignment: .leading) {
                ForEach(0 ..< 3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.white.opacity(0.75))
                        .frame(width: 35, height: 27)
                        .offset(x: CGFloat(index) * 8)
                        .shadow(color: tint.opacity(0.15), radius: 4, y: 3)
                }
            }
            .frame(width: 54, height: 31)

        default:
            HStack(spacing: 3) {
                ForEach(0 ..< 5, id: \.self) { index in
                    Capsule()
                        .fill(index < 2 ? tint : tint.opacity(0.20))
                        .frame(width: index == 0 ? 17 : 12, height: 15)
                }
            }
            .frame(height: 28)
        }
    }
}
#endif
