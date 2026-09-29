#if os(iOS)
import SwiftUI
import UIKit

/// Measured from the editable 402pt Figma input frame; isolated from other screens.
enum AnchorSetupStyle {
    static let top = adaptive(0xFAFDFF, dark: 0x101F29)
    static let bottom = adaptive(0xADF1FF, dark: 0x123641)
    static let reviewTop = adaptive(0xF2FCFF, dark: 0x101F29)
    static let reviewBottom = adaptive(0xE7F9FE, dark: 0x123641)
    static let heading = adaptive(0x26599D, dark: 0xB5E2F6)
    static let accent = adaptive(0x11D7FF, dark: 0x36D1ED)
    static let ink = adaptive(0x424B50, dark: 0xDFEFF5)
    static let secondary = adaptive(0x808080, dark: 0xB6CAD5)
    static let control = adaptive(0x667E84, dark: 0xB6CAD5)
    static let controlSurface = adaptive(0xEFF8FA, dark: 0x29414B)
    static let card = adaptive(0xFFFFFF, dark: 0x20343E)
    static let wave = adaptive(0x3BD5EF, dark: 0x257D92)
    static let inputHeight: CGFloat = 346
    static let inputRadius: CGFloat = 15
    static var background: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    static var reviewBackground: LinearGradient {
        LinearGradient(colors: [reviewTop, reviewBottom], startPoint: .top, endPoint: .bottom)
    }

    private static func adaptive(_ light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}
#endif
