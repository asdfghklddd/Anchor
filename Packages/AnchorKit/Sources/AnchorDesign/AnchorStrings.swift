import Foundation

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

    public static func value(_ key: StaticString, default defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: interfaceBundle)
    }
}
