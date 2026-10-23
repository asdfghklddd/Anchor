import SwiftUI

/// Names the iPhone and Mac screens already use. Every name now resolves through
/// `AnchorColorTokens`, so both platforms share one palette. Several names are
/// aliases kept for the discipline pass.
public enum AnchorPalette {
    public static let surface = Color(AnchorColorTokens.surface)
    public static let ink = Color(AnchorColorTokens.text)
    public static let secondaryInk = Color(AnchorColorTokens.textSecondary)
    public static let canvas = Color(AnchorColorTokens.canvasTop)
    public static let fluoriteSurface = Color(AnchorColorTokens.surface)
    public static let brandDeep = Color(AnchorColorTokens.heading)
    public static let interaction = Color(AnchorColorTokens.action)
    public static let softBlue = Color(AnchorColorTokens.selection)
    public static let aiBlue = Color(AnchorColorTokens.brand)
    public static let attention = Color(AnchorColorTokens.attentionFill)
    public static let fluoriteBorder = Color(AnchorColorTokens.border)
    public static let secondaryText = Color(AnchorColorTokens.textSecondary)
    public static let cyan = Color(AnchorColorTokens.brand)
    public static let link = Color(AnchorColorTokens.action)
    public static let harborWhite = Color(AnchorColorTokens.surface)
    public static let mintInk = Color(AnchorColorTokens.doneInk)
    public static let deepSeaInk = Color(AnchorColorTokens.text)
    /// Category colors. They used to double as status colors (coral = failed,
    /// sand = waiting); status now comes only from `AnchorStateTone`.
    public static let coral = Color(AnchorColorTokens.identity[2])
    public static let periwinkle = Color(AnchorColorTokens.identity[3])
    public static let sand = Color(AnchorColorTokens.attentionFill)
    // Fixed artwork colors that do not follow appearance.
    public static let seafoam = Color(anchorHex: AnchorColorTokens.seafoam)
    public static let deepSea = Color(anchorHex: AnchorColorTokens.deepSea)
    public static let oceanHighlight = Color(anchorHex: AnchorColorTokens.oceanHighlight)

    /// Only "cyan" is produced by current sources; the other tones are legacy
    /// and map onto identity hues so they can never read as a status.
    public static func source(_ tone: String) -> Color {
        switch tone {
        case "coral": Color(AnchorColorTokens.identity[2])
        case "periwinkle", "blue": Color(AnchorColorTokens.identity[3])
        case "sand": Color(AnchorColorTokens.identity[0])
        case "seafoam": Color(AnchorColorTokens.identity[4])
        case "cyan": Color(AnchorColorTokens.brand)
        default: ink
        }
    }

    /// Source labels read as links in both appearances.
    public static func sourceInk(_ tone: String) -> Color {
        Color(AnchorColorTokens.action)
    }

    /// Opaque pastel surfaces that keep black source initials above WCAG AA in both appearances.
    public static func sourceMark(_ tone: String) -> Color {
        switch tone {
        case "coral": Color(red: 1.00, green: 0.72, blue: 0.66)
        case "cyan": Color(red: 0.67, green: 0.91, blue: 0.92)
        case "periwinkle", "blue": Color(red: 0.74, green: 0.72, blue: 0.99)
        case "sand": Color(red: 0.99, green: 0.87, blue: 0.56)
        case "seafoam": Color(red: 0.75, green: 0.94, blue: 0.87)
        default: Color(red: 0.86, green: 0.88, blue: 0.89)
        }
    }

    public static func sourceSurface(_ tone: String, dark: Bool = false) -> [Color] {
        if dark {
            switch tone {
            case "coral": return [Color(red: 0.31, green: 0.15, blue: 0.13), Color(red: 0.22, green: 0.10, blue: 0.09)]
            case "cyan": return [Color(red: 0.10, green: 0.27, blue: 0.25), Color(red: 0.07, green: 0.20, blue: 0.18)]
            case "periwinkle", "blue": return [Color(red: 0.20, green: 0.18, blue: 0.36), Color(red: 0.14, green: 0.13, blue: 0.28)]
            default: return [Color(red: 0.17, green: 0.23, blue: 0.27), Color(red: 0.11, green: 0.17, blue: 0.21)]
            }
        }

        switch tone {
        case "coral": return [Color(red: 1.00, green: 0.95, blue: 0.92), Color(red: 1.00, green: 0.85, blue: 0.80)]
        case "cyan": return [Color(red: 0.93, green: 0.98, blue: 0.96), Color(red: 0.80, green: 0.94, blue: 0.90)]
        case "periwinkle", "blue": return [Color(red: 0.95, green: 0.95, blue: 1.00), Color(red: 0.86, green: 0.85, blue: 1.00)]
        default: return [Color(red: 0.95, green: 0.97, blue: 0.98), Color(red: 0.86, green: 0.91, blue: 0.94)]
        }
    }
}

public enum AnchorSpacing {
    public static let xSmall: CGFloat = 6
    public static let small: CGFloat = 10
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let xLarge: CGFloat = 32
}
