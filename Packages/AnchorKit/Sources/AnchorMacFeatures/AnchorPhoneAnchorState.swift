#if os(macOS)
import AnchorCore
import Foundation
import Observation

/// Applied phone hosting or selection confirms that the phone holds an anchor.
/// The edge shows whether any confirmed anchor is down, never which task is in focus.
@MainActor
@Observable
public final class AnchorPhoneAnchorState {
    public private(set) var confirmedSessionIDs: Set<UUID> = []

    public init() {}

    public func receive(_ envelope: EventEnvelope, projection: SessionProjection, localSourceID: UUID) {
        guard envelope.sourceID != localSourceID,
              envelope.type == EventEnvelope.operationType,
              let operation = try? JSONDecoder.anchor.decode(SessionOperation.self, from: envelope.payload),
              operation.sessionID == envelope.sessionID,
              projection.hostedSessions.contains(where: {
                  $0.id == envelope.sessionID && $0.status == .active
              }) else { return }
        switch operation {
        case .createSession, .hostSession, .selectSession: break
        default: return
        }
        // Reconnect replay confirms current state, but a known ID never replays an animation.
        confirmedSessionIDs.insert(envelope.sessionID)
    }

    /// Active hosted tasks the phone has anchored, independent of the foreground task.
    public func anchoredSessionIDs(in projection: SessionProjection) -> Set<UUID> {
        Set(projection.hostedSessions
            .filter { $0.status == .active && confirmedSessionIDs.contains($0.id) }
            .map(\.id))
    }
}
#endif
