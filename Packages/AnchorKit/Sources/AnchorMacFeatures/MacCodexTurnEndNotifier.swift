#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import Foundation
import UserNotifications

/// Finds turns that ended since the previous scan. The first scan that sees any
/// conversation only records where each one stands, so launching Anchor never
/// replays endings the person has already seen.
struct CodexTurnEndDetector {
    /// An ending older than this is history, not news (for example after a sleep).
    static let freshness: TimeInterval = 10 * 60

    private var lastEndByID: [String: Date] = [:]
    private var hasBaseline = false

    mutating func endings(in summaries: [CodexConversationSummary], now: Date) -> [CodexConversationSummary] {
        var endings: [CodexConversationSummary] = []
        for summary in summaries {
            guard let end = summary.state.endedAt else { continue }
            let previous = lastEndByID[summary.id]
            lastEndByID[summary.id] = max(end, previous ?? end)
            guard hasBaseline,
                  previous.map({ end > $0 }) ?? true,
                  now.timeIntervalSince(end) < Self.freshness else { continue }
            endings.append(summary)
        }
        // An empty scan may be a passing read failure, not a real starting point.
        if !summaries.isEmpty { hasBaseline = true }
        return endings
    }
}

/// The words of one turn-end notification: the conversation's name, the same
/// status line as its dashboard row, and the opening of the reply or the error.
struct CodexTurnEndNotice: Equatable {
    let identifier: String
    let threadIdentifier: String
    let title: String
    let subtitle: String
    let body: String

    init?(_ summary: CodexConversationSummary) {
        guard let end = summary.state.endedAt else { return nil }
        let status = MacCodexConversationStatus(summary, now: end)
        // A title that fell back to the folder name need not repeat it below.
        let workspace = summary.title == nil ? nil : summary.candidate.workspaceName
        title = summary.title ?? summary.candidate.workspaceName ?? MacCodexCopy.title
        subtitle = [status.label, status.fact, workspace].compactMap { $0 }.joined(separator: " · ")
        body = status.detail ?? ""
        threadIdentifier = MacCodexTurnEndNotifier.identifierPrefix + summary.id
        identifier = threadIdentifier + "." + String(Int64(end.timeIntervalSince1970 * 1_000))
    }
}

/// Posts one macOS notification per newly ended Codex turn, unless pings are
/// off or the person is already looking at the Codex app.
@MainActor
public final class MacCodexTurnEndNotifier {
    public nonisolated static let enabledDefaultsKey = "anchor.mac.codex.turn-end-notifications.enabled"
    public nonisolated static let identifierPrefix = "anchor.codex."
    /// The desktop app branded ChatGPT; it writes the same Codex session logs.
    nonisolated static let codexAppBundleIdentifier = "com.openai.codex"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func notify(_ endings: [CodexConversationSummary]) {
        guard defaults.object(forKey: Self.enabledDefaultsKey) as? Bool ?? true else { return }
        let codexIsFrontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == Self.codexAppBundleIdentifier
        let notices = endings
            .filter { !(codexIsFrontmost && $0.candidate.isFromDesktopApp) }
            .compactMap(CodexTurnEndNotice.init)
        guard !notices.isEmpty else { return }
        Task { await Self.post(notices) }
    }

    private static func post(_ notices: [CodexTurnEndNotice]) async {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            // Asked when the first ping is due, never at launch.
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else { return }
        for notice in notices {
            let content = UNMutableNotificationContent()
            content.title = notice.title
            content.subtitle = notice.subtitle
            content.body = notice.body
            content.threadIdentifier = notice.threadIdentifier
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: notice.identifier, content: content, trigger: nil))
        }
    }
}
#endif
