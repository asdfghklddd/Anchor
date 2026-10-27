import CoreText
import SwiftUI

/// Poppins (SIL OFL 1.1, see Resources/Fonts/Poppins-OFL.txt) for the home's
/// greeting and its anchoring clock, as in the owner's mockup.
public enum AnchorFonts {
    private static let registered: Void = {
        for name in ["Poppins-Regular", "Poppins-Medium"] {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf")
                ?? Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()

    /// Poppins at a size that follows Dynamic Type relative to `style`.
    public static func poppins(_ size: CGFloat, medium: Bool = false, relativeTo style: Font.TextStyle) -> Font {
        _ = registered
        return .custom(medium ? "Poppins-Medium" : "Poppins-Regular", size: size, relativeTo: style)
    }
}
