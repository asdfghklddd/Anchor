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
    public static let link = Color(red: 0.20, green: 0.47, blue: 0.73)

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
}

public enum AnchorSpacing {
    public static let xSmall: CGFloat = 6
    public static let small: CGFloat = 10
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let xLarge: CGFloat = 32
}
