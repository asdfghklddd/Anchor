import AnchorCore
import AnchorDesign
import Foundation
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

    @Test("Sync freshness says synced, still sending, or how old the copy is")
    func freshnessWords() {
        let now = Date(timeIntervalSince1970: 1_792_137_600)
        #expect(SyncText.line(for: .live, now: now) == "已同步")
        #expect(SyncText.line(for: .sending(2), now: now) == "正在发送 2 条变更")
        #expect(SyncText.line(for: .behind(lastContact: now.addingTimeInterval(-20), unsent: 0), now: now) == "上次同步 刚刚")
        #expect(SyncText.line(for: .behind(lastContact: now.addingTimeInterval(-7_200), unsent: 3), now: now)
                == "上次同步 2小时前 · 3 条变更待发送")
        #expect(SyncText.line(for: .behind(lastContact: nil, unsent: 0), now: now) == L10n.glanceSavedRecords)
    }
}
