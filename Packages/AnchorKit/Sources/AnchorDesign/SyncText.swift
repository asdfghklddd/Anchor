import AnchorCore
import Foundation

/// How current this device's copy is, in words: synced, still sending, or as of
/// the last contact with the changes that wait for the next one.
public enum SyncText {
    public static func line(for freshness: SyncFreshness, now: Date) -> String {
        switch freshness {
        case .live:
            return AnchorStrings.value("sync.fresh.live", default: "Synced")
        case let .sending(count):
            return String.localizedStringWithFormat(
                AnchorStrings.value("sync.fresh.sending", default: "Sending changes: %lld"), count)
        case let .behind(lastContact, unsent):
            let since = lastContact.map { lastSynced($0, now: now) } ?? L10n.glanceSavedRecords
            guard unsent > 0 else { return since }
            let waiting = String.localizedStringWithFormat(
                AnchorStrings.value("sync.fresh.waiting", default: "Not sent yet: %lld"), unsent)
            return "\(since) · \(waiting)"
        }
    }

    /// A few words for the home's top bar: when the two devices last spoke.
    public static func short(for freshness: SyncFreshness, now: Date) -> String {
        switch freshness {
        case .live:
            return AnchorStrings.value("home.synced.now", default: "Synced just now")
        case .sending:
            return line(for: freshness, now: now)
        case let .behind(lastContact, _):
            return lastContact.map { lastSynced($0, now: now) } ?? L10n.glanceSavedRecords
        }
    }

    public static func symbol(for freshness: SyncFreshness) -> String {
        switch freshness {
        case .live: "checkmark.circle"
        case .sending: "arrow.up.circle"
        case .behind: "clock.arrow.circlepath"
        }
    }

    static func lastSynced(_ date: Date, now: Date) -> String {
        let ago: String
        if now.timeIntervalSince(date) < 60 {
            ago = AnchorStrings.value("sync.fresh.just-now", default: "just now")
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = AnchorStrings.interfaceLocale
            formatter.unitsStyle = .full
            ago = formatter.localizedString(for: date, relativeTo: now)
        }
        return String.localizedStringWithFormat(AnchorStrings.value("sync.fresh.last", default: "Last synced %@"), ago)
    }
}
