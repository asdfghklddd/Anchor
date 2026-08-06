#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HarborMissionOrbit: View {
    let processes: [AnchorProcess]

    private let offsets = [
        CGSize(width: 0, height: -42),
        CGSize(width: 42, height: -4),
        CGSize(width: 22, height: 40),
        CGSize(width: -40, height: 13),
    ]

    var body: some View {
        ZStack {
            ForEach([40.0, 68.0, 96.0], id: \.self) { diameter in
                Circle()
                    .stroke(AnchorPalette.oceanHighlight.opacity(0.24), lineWidth: 1.5)
                    .frame(width: diameter, height: diameter)
            }

            AnchorMark(size: 44)

            ForEach(Array(processes.prefix(4).enumerated()), id: \.element.id) { index, process in
                Text(process.sourceSymbol)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.deepSea)
                    .frame(width: 23, height: 23)
                    .background(AnchorPalette.source(process.sourceTone), in: .circle)
                    .overlay { Circle().stroke(AnchorPalette.deepSea, lineWidth: 2) }
                    .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
                    .offset(offsets[index])
            }
        }
        .frame(width: 108, height: 108)
        .accessibilityHidden(true)
    }
}
#endif
