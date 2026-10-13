import AnchorCore
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Stable per-task identity colors shared by iPhone and Mac, so a task's lane,
/// card and tile read as the same thing on both devices. They never encode
/// status or source.
public enum AnchorTaskIdentity {
    public static func color(for task: AnchorSession) -> Color {
        color(index: task.taskColorIndex ?? 0)
    }

    public static func color(index: Int) -> Color {
        switch index {
        case 0: return adaptive(light: 0xF4C62F, dark: 0xDABB48)
        case 1: return adaptive(light: 0x36D1ED, dark: 0x289CB8)
        case 2: return adaptive(light: 0xE967D3, dark: 0xD986CB)
        case 3: return adaptive(light: 0x8B7CF6, dark: 0xA197F2)
        // Hand-picked hues stay clear of the named colors and of status green/red.
        case 4: return generated(hue: 0.07)
        case 5: return generated(hue: 0.62)
        case 6: return generated(hue: 0.22)
        default: return generated(hue: (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1))
        }
    }

    /// Readable attention text and symbols; the attention fill stays for shapes.
    public static let attentionInk = adaptive(light: 0x8A5A00, dark: 0xF2D16B)

    private static func generated(hue: Double) -> Color {
#if os(iOS)
        Color(uiColor: UIColor { traits in
            UIColor(hue: hue, saturation: 0.64, brightness: traits.userInterfaceStyle == .dark ? 0.78 : 0.88, alpha: 1)
        })
#else
        Color(nsColor: NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hue: hue, saturation: 0.64, brightness: dark ? 0.78 : 0.88, alpha: 1)
        })
#endif
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        func components(_ value: UInt32) -> (CGFloat, CGFloat, CGFloat) {
            (CGFloat((value >> 16) & 255) / 255, CGFloat((value >> 8) & 255) / 255, CGFloat(value & 255) / 255)
        }
#if os(iOS)
        return Color(uiColor: UIColor { traits in
            let (r, g, b) = components(traits.userInterfaceStyle == .dark ? dark : light)
            return UIColor(red: r, green: g, blue: b, alpha: 1)
        })
#else
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let (r, g, b) = components(isDark ? dark : light)
            return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
        })
#endif
    }
}
