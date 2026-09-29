#if os(iOS)
import Foundation

/// UI test profiles are isolated from the user's saved nickname and photo.
enum ProfilePreferences {
    static var store: UserDefaults {
        let environment = ProcessInfo.processInfo.environment
        if environment["ANCHOR_UI_TESTING"] == "1", let id = environment["ANCHOR_UI_TEST_STORAGE_ID"],
           let store = UserDefaults(suiteName: "AnchorProfileTests." + id) { return store }
        return .standard
    }
}
#endif
