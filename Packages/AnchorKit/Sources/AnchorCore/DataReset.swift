// Role: "start over" across both devices: `anchor.reset.v1` (forget tasks or clear conversations)
// and `anchor.history.v1` (phone asks the Mac to resend everything).
// Note: resets are sent before newer events, and each side keeps tombstones so nothing comes back.

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

/// The phone's request, once it has emptied itself, for everything the Mac
/// holds. Like opening a conversation it travels outside the event history.
public struct PeerHistoryRequest: Codable, Hashable, Sendable {
    public static let envelopeType = "anchor.history.v1"

    public let requestedAt: Date

    public init(requestedAt: Date = .now) {
        self.requestedAt = requestedAt
    }

    public func envelope(sourceID: UUID) throws -> EventEnvelope {
        EventEnvelope(sessionID: UUID(), sourceID: sourceID, sequence: 0, timestamp: requestedAt,
                      type: Self.envelopeType, payload: try JSONEncoder.anchor.encode(self))
    }

    public init?(envelope: EventEnvelope) {
        guard envelope.type == Self.envelopeType,
              let request = try? JSONDecoder.anchor.decode(PeerHistoryRequest.self, from: envelope.payload)
        else { return nil }
        self = request
    }
}

/// A repository that can drop its copy and take the paired device's instead,
/// such as a phone going back to where a restored Mac is.
public protocol PeerCopying: Sendable {
    /// Empties this copy now and trades nothing with the peer until it next
    /// connects, so neither side's newer changes reach the other.
    func awaitPeerCopy() async throws
    /// On connecting: empties this copy again and returns the request for the
    /// peer's history, or nil when no copy is awaited.
    func takePeerCopy() async throws -> EventEnvelope?
}
