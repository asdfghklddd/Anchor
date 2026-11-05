// Role: the one way to fetch a localized string (from this module's Localizable.xcstrings).
// Note: the Mac interface is pinned to Chinese even on an English host; the iPhone follows the system.

import Foundation

/// Use `value(_:default:)` with a stable key; English goes in `default`, Chinese in the catalog.
public enum AnchorStrings {
    private static let interfaceBundle: Bundle = {
#if os(macOS)
        // Keep the Mac interface in Chinese even when the host prefers English.
        if let path = Bundle.module.path(forResource: "zh-Hans", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
#endif
        return .module
    }()

    /// Dates and relative times follow the interface language, not the host's,
    /// so a Chinese Mac interface never mixes in "6 sec" or "3 min. ago".
    public static let interfaceLocale: Locale = {
#if os(macOS)
        Locale(identifier: "zh-Hans")
#else
        .current
#endif
    }()

    /// The language the interface is shown in, such as "zh-Hans" or "en".
    public static var interfaceLanguage: String {
        interfaceBundle.preferredLocalizations.first ?? "en"
    }

    public static func value(_ key: StaticString, default defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: interfaceBundle)
    }
}
