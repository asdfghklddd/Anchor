import AnchorCore
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Stable per-task identity colors shared by iPhone and Mac, so a task's lane,
/// card and tile read as the same thing on both devices. They never encode
/// status or source: every hue stays clear of the red, amber and green state
/// colors (see `AnchorColorTokens.identity`).
public enum AnchorTaskIdentity {
    public static func color(for task: AnchorSession) -> Color {
        color(index: task.taskColorIndex ?? 0)
    }

    public static func color(index: Int) -> Color {
        let named = AnchorColorTokens.identity
        if index >= 0, index < named.count { return Color(named[index]) }
        return generated(hue: generatedHue(index: index))
    }

    /// Beyond the named colors, spread hues by the golden ratio inside the safe band.
    public static func generatedHue(index: Int) -> Double {
        let band = AnchorColorTokens.identityHueBand
        let step = (Double(max(0, index)) * 0.61803398875).truncatingRemainder(dividingBy: 1)
        return (band.lowerBound + step * (band.upperBound - band.lowerBound)) / 360
    }

    /// Readable attention text and symbols; the attention fill stays for shapes.
    public static let attentionInk = Color(AnchorColorTokens.attentionInk)

    private static func generated(hue: Double) -> Color {
#if os(iOS)
        Color(uiColor: UIColor { traits in
            UIColor(hue: hue, saturation: 0.58, brightness: traits.userInterfaceStyle == .dark ? 0.80 : 0.82, alpha: 1)
        })
#else
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hue: hue, saturation: 0.58, brightness: dark ? 0.80 : 0.82, alpha: 1)
        })
#endif
    }
}
