import Foundation

public enum AnchorStrings {
    public static func value(_ key: StaticString, default defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: .module)
    }
}
