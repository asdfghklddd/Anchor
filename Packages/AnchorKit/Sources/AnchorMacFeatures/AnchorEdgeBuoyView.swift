#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// A small marker buoy beside the boat: red for a failure, amber for work
/// waiting on the person, green for work that finished unseen. With more than
/// one task needing the person it shows how many. It bobs slowly while present
/// and holds still when motion is reduced.
struct AnchorEdgeBuoyView: View {
    let buoy: EdgeBuoy
    let reduceMotion: Bool
    @State private var bobbing = false

    private var signal: EdgeBuoySignal { buoy.signal }

    var body: some View {
        Group {
            if buoy.count > 1 {
                Text("\(min(buoy.count, 9))")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            } else {
                Image(systemName: symbol).font(.system(size: 9, weight: .heavy))
            }
        }
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(color.gradient, in: .circle)
            .overlay { Circle().strokeBorder(.white, lineWidth: 2) }
            .shadow(color: .black.opacity(0.22), radius: 3, y: 1.5)
            .offset(y: bobbing && !reduceMotion ? -1.5 : 1.5)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { bobbing = true }
            }
            .accessibilityHidden(true)
    }

    private var symbol: String {
        switch signal {
        case .failed: "xmark"
        case .attention: "exclamationmark"
        case .finished: "checkmark"
        }
    }

    private var color: Color {
        switch signal {
        // The buoy floats on any wallpaper, so it keeps the light-appearance fills.
        case .failed: Color(anchorHex: AnchorColorTokens.failedFill.light)
        case .attention: Color(anchorHex: AnchorColorTokens.attentionFill.light)
        case .finished: Color(anchorHex: AnchorColorTokens.doneFill.light)
        }
    }
}

extension L10n {
    static func edgeBuoy(_ signal: EdgeBuoySignal) -> String {
        switch signal {
        case .failed: AnchorStrings.value("edge.buoy.failed", default: "Something failed since you last looked")
        case .attention: AnchorStrings.value("edge.buoy.attention", default: "Something is waiting for you")
        case .finished: AnchorStrings.value("edge.buoy.finished", default: "Work finished since you last looked")
        }
    }

    static func edgeBuoy(_ buoy: EdgeBuoy) -> String {
        guard buoy.count > 1 else { return edgeBuoy(buoy.signal) }
        let count = String.localizedStringWithFormat(
            AnchorStrings.value("edge.buoy.count", default: "Tasks needing you: %lld"), buoy.count)
        return "\(count) · \(edgeBuoy(buoy.signal))"
    }
}
#endif
