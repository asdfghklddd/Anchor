import SwiftUI

public enum AnchorPalette {
#if os(iOS)
    public static let paper = AnchorIOSStyle.canvasTop
    public static let surface = AnchorIOSStyle.surface
    public static let ink = AnchorIOSStyle.text
    public static let secondaryInk = AnchorIOSStyle.secondaryText
    public static let canvas = AnchorIOSStyle.canvasTop
    public static let fluoriteSurface = AnchorIOSStyle.surface
    public static let brandDeep = AnchorIOSStyle.heading
    public static let interaction = AnchorIOSStyle.action
    public static let softBlue = AnchorIOSStyle.canvasBottom
    public static let aiBlue = AnchorIOSStyle.cyan
    public static let attention = AnchorIOSStyle.yellow
    public static let fluoriteBorder = AnchorIOSStyle.border
    public static let secondaryText = AnchorIOSStyle.secondaryText
#else
    public static let paper = Color("Paper", bundle: .module)
    public static let surface = Color("Surface", bundle: .module)
    public static let ink = Color("Ink", bundle: .module)
    public static let secondaryInk = Color("SecondaryInk", bundle: .module)
    public static let canvas = Color("Canvas", bundle: .module)
    public static let fluoriteSurface = Color("FluoriteSurface", bundle: .module)
    public static let brandDeep = Color("BrandDeep", bundle: .module)
    public static let interaction = Color("Interaction", bundle: .module)
    public static let softBlue = Color("SoftBlue", bundle: .module)
    public static let aiBlue = Color("AIBlue", bundle: .module)
    public static let attention = Color("Attention", bundle: .module)
    public static let fluoriteBorder = Color("FluoriteBorder", bundle: .module)
    public static let secondaryText = Color("SecondaryText", bundle: .module)
#endif
    public static let seafoam = Color(red: 0.57, green: 0.87, blue: 0.77)
#if os(iOS)
    public static let coral = AnchorIOSStyle.pink
#else
    public static let coral = Color(red: 1.00, green: 0.48, blue: 0.38)
#endif
#if os(iOS)
    public static let sand = AnchorIOSStyle.yellow
#else
    public static let sand = Color(red: 0.97, green: 0.74, blue: 0.24)
#endif
#if os(iOS)
    public static let cyan = AnchorIOSStyle.cyan
#else
    public static let cyan = Color(red: 0.35, green: 0.80, blue: 0.82)
#endif
#if os(iOS)
    public static let periwinkle = AnchorIOSStyle.pink
#else
    public static let periwinkle = Color(red: 0.55, green: 0.52, blue: 0.97)
#endif
    // Keep artwork and fixed dark surfaces independent of adaptive foreground colors.
    public static let deepSea = Color(red: 0.07, green: 0.23, blue: 0.33)
#if os(macOS)
    public static let deepSeaInk = Color("DeepSeaInk", bundle: .module)
#endif
#if os(iOS)
    public static let link = AnchorIOSStyle.action
#else
    public static let link = Color(red: 0.13, green: 0.38, blue: 0.62)
#endif
#if os(iOS)
    public static let harborWhite = AnchorIOSStyle.surface
#else
    public static let harborWhite = Color(red: 1.00, green: 0.99, blue: 0.97)
#endif
#if os(iOS)
    public static let mintInk = AnchorIOSStyle.success
#else
    public static let mintInk = Color("MintInk", bundle: .module)
#endif
    public static let warmYellow = Color(red: 1.00, green: 0.96, blue: 0.71)
    public static let oceanHighlight = Color(red: 0.66, green: 0.93, blue: 0.89)
    public static let returnCanvas = Color("ReturnCanvas", bundle: .module)

    public static func source(_ tone: String) -> Color {
        switch tone {
        case "coral": coral
        case "cyan": cyan
        case "periwinkle", "blue": periwinkle
        case "sand": sand
        case "seafoam": seafoam
        default: ink
        }
    }

    /// Source text colors adapt to the appearance of information surfaces.
    public static func sourceInk(_ tone: String) -> Color {
#if os(iOS)
        AnchorIOSStyle.heading
#else
        switch tone {
        case "coral": Color("SourceCoralInk", bundle: .module)
        case "cyan": Color("SourceCyanInk", bundle: .module)
        case "periwinkle", "blue": Color("SourcePeriwinkleInk", bundle: .module)
        case "sand": Color("SourceSandInk", bundle: .module)
        case "seafoam": Color("SourceSeafoamInk", bundle: .module)
        default: deepSeaInk
        }
#endif
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
