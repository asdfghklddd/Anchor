#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// A small marker buoy beside the boat: red for a failure, amber for work
/// waiting on the person, green for work that finished unseen. It bobs
/// slowly while present and holds still when motion is reduced.
struct AnchorEdgeBuoyView: View {
    let signal: EdgeBuoySignal
    let reduceMotion: Bool
    @State private var bobbing = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .heavy))
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
        case .failed: Color(red: 0.86, green: 0.20, blue: 0.20)
        case .attention: Color(red: 0.90, green: 0.62, blue: 0.08)
        case .finished: Color(red: 0.16, green: 0.62, blue: 0.38)
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
}
#endif
