import AnchorCore
import Foundation

public actor LinkedSessionRepository: SessionRepository {
    private let base: any SessionRepository
    private let client: AnchorBonjourClient
    private let sourceID: UUID
    private var sequence: UInt64 = 0

    public init(
        base: any SessionRepository,
        client: AnchorBonjourClient,
        sourceID: UUID = UUID()
    ) {
        self.base = base
        self.client = client
        self.sourceID = sourceID
    }

    public func currentProjection() async -> SessionProjection {
        await base.currentProjection()
    }

    public func projections() async -> AsyncStream<SessionProjection> {
        await base.projections()
    }

    public func send(_ command: SessionCommand) async throws {
        try await base.send(command)
        switch command {
        case .updateSignals, .updatePresence, .clearError, .mergeRemoteSession:
            return
        default:
            break
        }
        guard let session = await base.currentProjection().session else { return }
        sequence &+= 1
        let payload = try JSONEncoder.anchor.encode(session)
        let envelope = EventEnvelope(
            sessionID: session.id,
            sourceID: sourceID,
            sequence: sequence,
            type: "session.projection.v1",
            payload: payload
        )
        try await client.send(envelope)
    }
}

public enum LinkedSessionDecoder {
    public static func session(from envelope: EventEnvelope) -> AnchorSession? {
        guard envelope.type == "session.projection.v1" else { return nil }
        guard let session = try? JSONDecoder.anchor.decode(AnchorSession.self, from: envelope.payload),
              session.id == envelope.sessionID else { return nil }
        return session
    }
}
