#if os(macOS)
import AnchorCore
import Foundation
import Observation

/// Applied phone hosting or selection confirms which hosted task is in focus.
@MainActor
@Observable
public final class AnchorPhoneAnchorState {
    public private(set) var confirmedSessionID: UUID?

    public init() {}

    public func receive(_ envelope: EventEnvelope, projection: SessionProjection, localSourceID: UUID) {
        guard envelope.sourceID != localSourceID,
              envelope.type == EventEnvelope.operationType,
              let operation = try? JSONDecoder.anchor.decode(SessionOperation.self, from: envelope.payload),
              operation.sessionID == envelope.sessionID,
              projection.session?.id == envelope.sessionID,
              projection.session?.status == .active else { return }
        switch operation {
        case .createSession, .hostSession, .selectSession: break
        default: return
        }
        // Reconnect replay confirms current state, but the same ID never replays an animation.
        confirmedSessionID = envelope.sessionID
    }

    public func activeSessionID(in projection: SessionProjection) -> UUID? {
        guard projection.session?.status == .active,
              projection.session?.id == confirmedSessionID else { return nil }
        return confirmedSessionID
    }
}
#endif
