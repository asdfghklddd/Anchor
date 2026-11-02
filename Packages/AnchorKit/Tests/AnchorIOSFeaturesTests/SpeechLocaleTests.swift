#if os(iOS)
import Foundation
import Testing
@testable import AnchorIOSFeatures

@Suite("Dictation language")
struct SpeechLocaleTests {
    private let supported: Set<Locale> = Set(
        ["en-US", "en-GB", "nl-NL", "zh-CN", "zh-TW", "zh-HK", "yue-CN"].map(Locale.init(identifier:))
    )

    @Test func aChineseInterfaceListensInMandarinWherever() {
        let locale = SpeechInputController.speechLocale(language: "zh-Hans", region: .netherlands, supported: supported)
        #expect(locale.identifier == "zh-CN")
    }

    @Test func traditionalChineseListensInTaiwan() {
        let locale = SpeechInputController.speechLocale(language: "zh-Hant", region: .unitedStates, supported: supported)
        #expect(locale.identifier == "zh-TW")
    }

    @Test func englishFollowsThePhonesRegionWhenItCan() {
        #expect(SpeechInputController.speechLocale(language: "en", region: .unitedKingdom, supported: supported).identifier == "en-GB")
        #expect(SpeechInputController.speechLocale(language: "en", region: .netherlands, supported: supported).identifier == "en-US")
    }
}
#endif
