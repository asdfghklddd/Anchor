#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborMissionOrbit: View {
    let processes: [AnchorProcess]

    private let offsets = [
        CGSize(width: 0, height: -45),
        CGSize(width: 45, height: -4),
        CGSize(width: 24, height: 43),
        CGSize(width: -43, height: 14),
    ]

    var body: some View {
        ZStack {
            ForEach([42.0, 72.0, 102.0], id: \.self) { diameter in
                Circle()
                    .stroke(AnchorPalette.oceanHighlight.opacity(0.24), lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
            }

            AnchorMark(size: 44)

            ForEach(Array(processes.prefix(4).enumerated()), id: \.element.id) { index, process in
                Text(process.sourceSymbol)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 23, height: 23)
                    .background(AnchorPalette.source(process.sourceTone), in: .circle)
                    .overlay { Circle().stroke(AnchorPalette.deepSea, lineWidth: 2) }
                    .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
                    .offset(offsets[index])
            }
        }
        .frame(width: 116, height: 116)
        .accessibilityHidden(true)
    }
}
#endif
