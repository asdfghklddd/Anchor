#if os(iOS)
import AnchorCore
import SwiftUI
import UIKit

/// iOS visual tokens derived from the approved Figma homepage (204:573).
public enum AnchorIOSStyle {
    public static let canvasTop = adaptive(light: 0xF7FDFF, dark: 0x101F29)
    public static let canvasBottom = adaptive(light: 0xD2F7FC, dark: 0x123641)
    public static let surface = adaptive(light: 0xFFFFFF, dark: 0x20343E)
    public static let heading = adaptive(light: 0x315E8B, dark: 0xB5E2F6)
    public static let cyan = adaptive(light: 0x36D1ED, dark: 0x289CB8)
    public static let yellow = adaptive(light: 0xF4C62F, dark: 0xDABB48)
    public static let text = adaptive(light: 0x183F52, dark: 0xDFEFF5)
    public static let secondaryText = adaptive(light: 0x526979, dark: 0xB6CAD5)
    public static let action = adaptive(light: 0x176E87, dark: 0x87DCEC)
    public static let onAction = adaptive(light: 0xFFFFFF, dark: 0x123F52)
    public static let onAccent = adaptive(light: 0x123F52, dark: 0x082C38)
    public static let success = adaptive(light: 0x26764D, dark: 0x8DDDAD)
    public static let border = adaptive(light: 0xDCECF0, dark: 0x3C5662)
    public static let cardRadius: CGFloat = 16
    public static let heroRadius: CGFloat = 20
    public static let pageInset: CGFloat = 20
    public static let pink = adaptive(light: 0xE967D3, dark: 0xD986CB)

    public static var background: LinearGradient {
        LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .top, endPoint: .bottom)
    }

    public static func tint(for process: AnchorProcess) -> Color {
        switch process.sourceTone {
        case "sand": yellow
        case "coral", "periwinkle", "blue": pink
        default: cyan
        }
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1
            )
        })
    }
}
#endif
