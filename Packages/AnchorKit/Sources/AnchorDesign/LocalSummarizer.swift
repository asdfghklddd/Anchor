import AnchorCore
import Foundation

/// The writer that needs no model, so names and recaps exist offline and
/// before any API is set up. A name is the conversation's own name or the gist
/// of its first request; a recap strings the plan step and what the agents
/// were doing into one line in the person's language.
public struct LocalSummarizer: AnchorSummarizer {
    public init() {}

    public func conversationName(_ source: ConversationNameSource) async throws -> String {
        source.gist ?? ""
    }

    public func leaveRecap(_ facts: TaskLeaveFacts) async throws -> String {
        Self.recap(facts)
    }

    /// "Step 2/4: Implement delete; Red-black delete Done, Report Waiting for you".
    static func recap(_ facts: TaskLeaveFacts) -> String {
        var parts: [String] = []
        if let number = facts.nextStepNumber, let text = facts.nextStepText {
            parts.append(String.localizedStringWithFormat(
                AnchorStrings.value("summary.recap.step", default: "Step %1$lld/%2$lld: %3$@"),
                number, facts.stepCount, text))
        } else if facts.stepCount > 0 {
            parts.append(PlanText.allStepsDone)
        }
        let agents = facts.conversations.prefix(2).map { "\($0.name) \(state(of: $0))" }
        if let agents = agents.reduce(String?.none, { joined($0, $1, format: listFormat) }) {
            parts.append(agents)
        }
        // Without a plan or a state to report, what was last asked is the state.
        if parts.isEmpty, let request = facts.conversations.first?.request { parts.append(request) }
        return parts.reduce(String?.none) { joined($0, $1, format: partsFormat) }
            ?? AnchorStrings.value("summary.recap.quiet", default: "No conversations yet")
    }

    private static let listFormat = AnchorStrings.value("summary.recap.and", default: "%1$@, %2$@")
    private static let partsFormat = AnchorStrings.value("summary.recap.join", default: "%1$@; %2$@")

    private static func joined(_ head: String?, _ tail: String, format: String) -> String {
        guard let head else { return tail }
        return String.localizedStringWithFormat(format, head, tail)
    }

    /// The same words the glance uses for a run's state.
    private static func state(of conversation: TaskLeaveFacts.Conversation) -> String {
        if conversation.isInterrupted { return L10n.tideState(.interrupted) }
        return switch conversation.status {
        case .running: L10n.tideState(.running)
        case .completed: L10n.tideState(.completed)
        case .failed: L10n.tideState(.failed)
        case .needsDecision: PlanText.waitingForReply
        case .blocked, .disconnected: L10n.tideState(.attention)
        case .queued: L10n.status(.queued)
        }
    }
}
