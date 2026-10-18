#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Every recent Codex conversation, with no anchor or confirmation needed:
/// what it is called, whether it is still working, and how its latest turn ended.
struct MacCodexConversationsCard: View {
    let conversations: [CodexConversationSummary]

    var body: some View {
        // Relative times and the quiet threshold follow the clock, not only new scans.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let items = MacCodexConversationOrder.ordered(conversations).map {
                Item(conversation: $0, status: MacCodexConversationStatus($0, now: context.date))
            }
            let running = items.filter { $0.status.tone == .running }.count
            MacCard(MacCodexCopy.title, symbol: "bubble.left.and.text.bubble.right") {
                if running > 0 {
                    Text("\(running) \(L10n.sourceSetupTaskRunning)")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AnchorStateTone.running.ink)
                }
            } content: {
                if items.isEmpty {
                    Text(MacCodexCopy.empty)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    let visible = items.prefix(MacCodexConversationOrder.visibleLimit)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { Divider() }
                            MacCodexConversationRow(conversation: item.conversation, status: item.status)
                        }
                        if items.count > visible.count {
                            Text(MacCodexCopy.more(items.count - visible.count))
                                .font(.caption)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .padding(.top, 6)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("mac.codex.conversations")
    }

    private struct Item: Identifiable {
        let conversation: CodexConversationSummary
        let status: MacCodexConversationStatus
        var id: String { conversation.id }
    }
}

struct MacCodexConversationRow: View {
    let conversation: CodexConversationSummary
    let status: MacCodexConversationStatus
    /// Extra context for the status line, such as the step this work serves.
    var note: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: status.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(status.tint)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AnchorPalette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let endedAt = status.endedAt {
                        Text(endedAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }

                HStack(spacing: 0) {
                    Text(status.label)
                        .fontWeight(.semibold)
                        .foregroundStyle(status.tint)
                    // Codex is the default; Claude Code says its name so the two read apart.
                    Text([status.fact, note,
                          conversation.candidate.originator == CodexSessionMetadata.claudeCodeOriginator
                              ? CodexSessionMetadata.claudeCodeOriginator : nil,
                          conversation.candidate.workspaceName]
                        .compactMap { $0 }
                        .map { " · " + $0 }
                        .joined())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                }
                .font(.callout)
                .lineLimit(1)

                if let detail = status.detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 10)
        .help(title)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.codex.conversation.\(conversation.id)")
    }

    private var title: String {
        conversation.title ?? conversation.candidate.workspaceName ?? MacCodexCopy.title
    }
}

/// Running work comes first, then everything else by when it ended. Turn
/// boundaries, not log writes, set the order, so rows stay put while Codex works.
enum MacCodexConversationOrder {
    static let visibleLimit = 6

    static func ordered(_ conversations: [CodexConversationSummary]) -> [CodexConversationSummary] {
        conversations.sorted { first, second in
            let a = key(first), b = key(second)
            if a.running != b.running { return a.running }
            if a.date != b.date { return a.date > b.date }
            return first.id < second.id
        }
    }

    private static func key(_ conversation: CodexConversationSummary) -> (running: Bool, date: Date) {
        switch conversation.state {
        case .running(let since): (true, since)
        case .completed(let at, _), .failed(let at, _), .interrupted(let at): (false, at)
        case .unknown: (false, conversation.candidate.createdAt ?? conversation.candidate.modifiedAt)
        }
    }
}

/// The words and colors one conversation reads as at a given moment.
struct MacCodexConversationStatus: Equatable {
    enum Tone: Equatable {
        case running
        /// Still running by its log, but nothing has been written for a while.
        case quiet
        case done
        case failed
        case stopped
        /// The agent asked the person something and waits for the answer.
        case waiting
        case unknown
    }

    /// After this long without a log write, a running turn says so rather than looking busy.
    static let quietAfter: TimeInterval = 10 * 60

    let tone: Tone
    let label: String
    let fact: String?
    let detail: String?
    let endedAt: Date?

    init(_ conversation: CodexConversationSummary, now: Date) {
        // The test verdict follows whatever the turn's state says.
        let tests = conversation.tests.map(PlanText.tests)
        switch conversation.state {
        case .running(let since):
            let silence = now.timeIntervalSince(conversation.candidate.modifiedAt)
            if conversation.isWaitingForReply {
                tone = .waiting
                label = PlanText.waitingForReply
                fact = tests
            } else if silence > Self.quietAfter {
                tone = .quiet
                label = L10n.sourceSetupTaskRunning
                fact = MacCodexCopy.quiet(Self.duration(silence))
            } else {
                tone = .running
                label = L10n.sourceSetupTaskRunning
                fact = Self.joined(Self.duration(now.timeIntervalSince(since)), tests)
            }
            detail = nil
            endedAt = nil
        case .completed(let at, let duration):
            tone = conversation.isWaitingForReply ? .waiting : .done
            label = conversation.isWaitingForReply ? PlanText.waitingForReply : L10n.sourceSetupTaskCompleted
            fact = Self.joined(duration.map { MacCodexCopy.took(Self.duration($0)) }, tests)
            detail = conversation.reply
            endedAt = at
        case .failed(let at, let message):
            tone = .failed
            label = MacCodexCopy.failed
            fact = tests
            detail = message
            endedAt = at
        case .interrupted(let at):
            tone = .stopped
            label = L10n.sourceSetupTaskInterrupted
            fact = nil
            detail = nil
            endedAt = at
        case .unknown:
            tone = .unknown
            label = MacCodexCopy.noStatus
            fact = nil
            detail = nil
            endedAt = nil
        }
    }

    var symbol: String {
        switch tone {
        case .running: "play.circle.fill"
        case .quiet: "ellipsis.circle"
        case .done: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .stopped: "pause.circle.fill"
        case .waiting: "questionmark.bubble.fill"
        case .unknown: "circle.dashed"
        }
    }

    private static func joined(_ parts: String?...) -> String? {
        let present = parts.compactMap { $0 }
        return present.isEmpty ? nil : present.joined(separator: " · ")
    }

    var tint: Color {
        switch tone {
        case .running: AnchorStateTone.running.ink
        case .done: AnchorStateTone.done.ink
        case .failed: AnchorStateTone.failed.ink
        case .waiting: AnchorStateTone.attention.ink
        // Stopping a turn is the person's own choice, so it stays quiet.
        case .quiet, .stopped, .unknown: AnchorPalette.secondaryInk
        }
    }

    /// Seconds under a minute, whole minutes under an hour, then hours and minutes.
    static func duration(_ seconds: TimeInterval) -> String {
        let units: Set<Duration.UnitsFormatStyle.Unit> = seconds < 60
            ? [.seconds] : seconds < 3_600 ? [.minutes] : [.hours, .minutes]
        return Duration.seconds(max(0, seconds).rounded())
            .formatted(.units(allowed: units, width: .abbreviated).locale(AnchorStrings.interfaceLocale))
    }
}

enum MacCodexCopy {
    static let title = AnchorStrings.value("mac.codex.title", default: "Codex conversations")
    static let failed = AnchorStrings.value("mac.codex.state.failed", default: "Error")
    static let noStatus = AnchorStrings.value("mac.codex.state.unknown", default: "No status yet")
    static let empty = AnchorStrings.value(
        "mac.codex.empty",
        default: "Start a Codex conversation and it appears here by itself."
    )
    static let anchorHint = AnchorStrings.value(
        "mac.codex.anchor-hint",
        default: "Want to track a goal and its steps? Drop an anchor on iPhone."
    )
    static let notifyOnEnd = AnchorStrings.value(
        "mac.codex.notify-on-end",
        default: "Notify me when a Codex conversation ends"
    )
    static let notifyOnEndDetail = AnchorStrings.value(
        "mac.codex.notify-on-end.detail",
        default: "Shows the start of the reply. Stays quiet while you're looking at Codex."
    )

    static func took(_ duration: String) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("mac.codex.took", default: "took %@"), duration)
    }

    static func quiet(_ duration: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.codex.quiet", default: "no new activity for %@"), duration)
    }

    static func more(_ count: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("mac.codex.more", default: "%lld more"), count)
    }
}
#endif
