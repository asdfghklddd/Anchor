import Foundation

public extension AnchorProcess {
    /// Codex reports one process per turn; a conversation's turns share its source.
    var isCodexTurn: Bool {
        title == CodexLifecycleRecord.legacyTurnTitle
            || events.contains { CodexLifecycleRecord.eventTitles.contains($0.title) }
    }
}

extension AnchorSession {
    /// People follow conversations, not turns. Each Codex conversation's turn
    /// processes fold into one row: the first turn keeps the row's identity and
    /// position (so commands still reach a stored process), the latest turn
    /// supplies its state, and every turn's events remain in its history.
    func foldingCodexTurnsIntoConversations() -> AnchorSession {
        var turnsBySource: [UUID: [AnchorProcess]] = [:]
        for process in processes where process.isCodexTurn {
            // The retired single-file source mixed conversations under one ID.
            guard let sourceID = process.sourceID, sourceID != BuiltInProcessSourceID.codex else { continue }
            turnsBySource[sourceID, default: []].append(process)
        }
        guard !turnsBySource.isEmpty else { return self }

        let rank = Dictionary(
            (processJoinOrder ?? processes.map(\.id)).enumerated().map { ($1, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var representativeByTurn: [UUID: UUID] = [:]
        var conversations: [UUID: AnchorProcess] = [:]
        for turns in turnsBySource.values {
            guard let first = turns.min(by: { (rank[$0.id] ?? .max, $0.updatedAt) < (rank[$1.id] ?? .max, $1.updatedAt) }),
                  let latest = turns.max(by: { $0.updatedAt < $1.updatedAt }) else { continue }
            for turn in turns { representativeByTurn[turn.id] = first.id }
            var conversation = first
            conversation.sourceName = latest.sourceName
            conversation.sourceSymbol = latest.sourceSymbol
            conversation.sourceTone = latest.sourceTone
            conversation.title = latest.title == CodexLifecycleRecord.legacyTurnTitle
                ? CodexConversationStrings.conversation : latest.title
            conversation.status = latest.status
            conversation.progress = latest.progress
            conversation.metric = latest.metric
            conversation.metricLabel = latest.metricLabel
            conversation.detail = latest.detail
            conversation.estimatedCompletion = latest.estimatedCompletion
            conversation.deepLink = latest.deepLink
            conversation.stepID = latest.stepID ?? first.stepID
            conversation.testOutcome = latest.testOutcome
            conversation.request = turns.filter { $0.request != nil }.max { $0.updatedAt < $1.updatedAt }?.request
            conversation.updatedAt = latest.updatedAt
            var seenEventIDs = Set<UUID>()
            conversation.events = turns.flatMap(\.events)
                .filter { seenEventIDs.insert($0.id).inserted }
                .map { $0.reassigned(to: representativeByTurn) }
                .sorted { ($0.occurredAt, $0.id.uuidString) > ($1.occurredAt, $1.id.uuidString) }
            conversations[first.id] = conversation
        }

        var result = self
        result.processes = processes.compactMap { process in
            guard let representative = representativeByTurn[process.id] else { return process }
            return representative == process.id ? conversations[representative] : nil
        }
        result.processJoinOrder = processJoinOrder?.filter { (representativeByTurn[$0] ?? $0) == $0 }
        result.timeline = timeline.map { $0.reassigned(to: representativeByTurn) }
        if let recommended = returnSummary?.recommendedProcessID,
           let representative = representativeByTurn[recommended] {
            result.returnSummary?.recommendedProcessID = representative
        }
        return result
    }
}

private extension ProcessEvent {
    func reassigned(to representatives: [UUID: UUID]) -> ProcessEvent {
        guard let processID, let representative = representatives[processID], representative != processID else {
            return self
        }
        return ProcessEvent(
            id: id, sessionID: sessionID, processID: representative, sourceID: sourceID,
            externalID: externalID, deduplicationKey: deduplicationKey, occurredAt: occurredAt,
            receivedAt: receivedAt, kind: kind, title: title, detail: detail, progress: progress,
            metric: metric, metricLabel: metricLabel, deepLink: deepLink
        )
    }
}

enum CodexConversationStrings {
    static var conversation: String {
        let localized = String(localized: "codex.conversation", bundle: .module)
        return localized == "codex.conversation" ? "Conversation" : localized
    }
}
