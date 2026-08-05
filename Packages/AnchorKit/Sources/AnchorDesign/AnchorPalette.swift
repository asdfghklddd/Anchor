import SwiftUI

public enum AnchorPalette {
    public static let paper = Color("Paper", bundle: .module)
    public static let surface = Color("Surface", bundle: .module)
    public static let ink = Color("Ink", bundle: .module)
    public static let secondaryInk = Color("SecondaryInk", bundle: .module)
    public static let seafoam = Color(red: 0.57, green: 0.87, blue: 0.77)
    public static let coral = Color(red: 1.00, green: 0.48, blue: 0.38)
    public static let sand = Color(red: 0.97, green: 0.74, blue: 0.24)
    public static let cyan = Color(red: 0.35, green: 0.80, blue: 0.82)
    public static let periwinkle = Color(red: 0.55, green: 0.52, blue: 0.97)
    public static let deepSea = Color(red: 0.07, green: 0.23, blue: 0.33)
    public static let link = Color(red: 0.13, green: 0.38, blue: 0.62)
    public static let harborWhite = Color(red: 1.00, green: 0.99, blue: 0.97)
    public static let mintInk = Color(red: 0.08, green: 0.36, blue: 0.28)
    public static let warmYellow = Color(red: 1.00, green: 0.96, blue: 0.71)
    public static let oceanHighlight = Color(red: 0.66, green: 0.93, blue: 0.89)

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

    /// Dark companion colors for text placed on the light clay surfaces.
    public static func sourceInk(_ tone: String) -> Color {
        switch tone {
        case "coral": Color(red: 0.65, green: 0.20, blue: 0.14)
        case "cyan": Color(red: 0.05, green: 0.40, blue: 0.43)
        case "periwinkle", "blue": Color(red: 0.27, green: 0.24, blue: 0.61)
        case "sand": Color(red: 0.46, green: 0.31, blue: 0.00)
        case "seafoam": Color(red: 0.08, green: 0.38, blue: 0.29)
        default: deepSea
        }
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
