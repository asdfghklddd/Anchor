import AnchorCore
import AnchorDesign
import Testing

/// The Mac interface is Chinese, so these checks run against the zh-Hans copy.
@Suite("State wording")
struct StateWordingTests {
    @Test("Glance counts and state words name each state the same way")
    func countsMatchStateWords() {
        let pairs: [(count: String, word: TideState)] = [
            (L10n.glanceRunning, .running),
            (L10n.glanceAttention, .attention),
            (L10n.glanceFailed, .failed),
            (L10n.glanceCompleted, .completed),
        ]
        for pair in pairs {
            #expect(pair.count.hasSuffix(L10n.tideState(pair.word)), "\(pair.count) vs \(L10n.tideState(pair.word))")
        }
    }
}
