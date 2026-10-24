import Foundation

/// The person's request to start over. It travels to the paired device like
/// any change, so neither side brings back what the other cleared.
public struct AnchorDataReset: Codable, Hashable, Sendable {
    public enum Scope: Codable, Hashable, Sendable {
        /// These tasks are gone, as if never hosted, on both devices.
        case tasks(Set<UUID>)
        /// Agent conversations in active tasks; the Mac reads its folders again.
        case conversations
    }

    public static let envelopeType = "anchor.reset.v1"

    public let id: UUID
    public let scope: Scope
    public let at: Date

    public init(id: UUID = UUID(), scope: Scope, at: Date = .now) {
        self.id = id
        self.scope = scope
        self.at = at
    }
}

/// A repository whose local data the person can clear.
public protocol DataResetting: Sendable {
    /// Removes these tasks and everything about them, here and on the peer.
    func forgetTasks(_ ids: Set<UUID>) async throws
    /// Removes agent conversations from active tasks, here and on the peer.
    func clearConversations() async throws
}

extension SessionOperation {
    /// What a conversation reset removes: rows the Mac read from agent logs.
    var isConversationRecord: Bool {
        switch self {
        case let .scoped(_, operation): operation.isConversationRecord
        case .addProcess, .updateProcess, .removeProcess, .reorderProcesses, .updateTileSize,
             .recordEvent, .observeProcess, .resolveDecision:
            true
        default:
            false
        }
    }
}

extension AnchorSession {
    /// Keeps the person's goal, plan, notes and snapshots; drops what agents reported.
    mutating func clearConversations() {
        processes = []
        decisions = []
        timeline = []
        processJoinOrder = nil
        returnSummary = nil
        processedEventIDs = []
    }
}

extension SessionProjection {
    /// Removes tasks by identity wherever they are kept, keeping one selected.
    mutating func forget(_ ids: Set<UUID>) {
        if let id = session?.id, ids.contains(id) { session = nil }
        additionalSessions.removeAll { ids.contains($0.id) }
        archivedSessions.removeAll { ids.contains($0.id) }
        if session == nil, !additionalSessions.isEmpty {
            session = additionalSessions.removeFirst()
        }
    }

    /// Clears agent conversations from these tasks.
    mutating func clearConversations(in ids: Set<UUID>) {
        if let id = session?.id, ids.contains(id) { session?.clearConversations() }
        for index in additionalSessions.indices where ids.contains(additionalSessions[index].id) {
            additionalSessions[index].clearConversations()
        }
    }
}

extension EventEnvelope {
    public var isDataReset: Bool { type == AnchorDataReset.envelopeType }
}
