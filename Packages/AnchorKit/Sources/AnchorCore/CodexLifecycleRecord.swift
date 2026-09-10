import Foundation

/// Decodes only lifecycle metadata from Codex JSONL; message bodies are ignored.
public struct CodexLifecycleRecord: Codable, Hashable, Sendable {
    public let timestamp: Date
    public let type: String
    public let turnID: String
    public let lifecycle: CodexLifecycle

    public enum CodexLifecycle: String, Codable, Hashable, Sendable { case started = "task_started", completed = "task_complete", aborted = "turn_aborted" }

    public init?(json data: Data) {
        struct Envelope: Decodable { let timestamp: String; let type: String; let payload: Payload }
        struct Payload: Decodable { let type: CodexLifecycle; let turnID: String?; let turn_id: String? }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let value = try? JSONDecoder().decode(Envelope.self, from: data),
              value.type == "event_msg",
              let date = fractional.date(from: value.timestamp) ?? ISO8601DateFormatter().date(from: value.timestamp),
              date.timeIntervalSince1970 >= 0,
              date.timeIntervalSince1970 < Double(UInt64.max) / 1_000,
              let id = value.payload.turnID ?? value.payload.turn_id,
              !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        timestamp = date; type = value.payload.type.rawValue; turnID = id; lifecycle = value.payload.type
    }

    public func externalEvent(sessionID: UUID, sourceID: UUID) -> ExternalProcessEvent {
        let status: ProcessStatus = lifecycle == .started ? .running : (lifecycle == .completed ? .completed : .failed)
        let kind: ProcessEventKind = lifecycle == .started ? .created : (lifecycle == .completed ? .completed : .failed)
        let processID = StableProcessIdentity.id(namespace: "codex.turn", sessionID: sessionID, externalID: turnID)
        // A run is stable across phases; each phase needs its own event identity.
        let key = sourceID.uuidString + ":" + turnID + ":" + lifecycle.rawValue
        let eventID = StableProcessIdentity.id(namespace: "codex.event", sessionID: sessionID, externalID: key)
        let event = ProcessEvent(id: eventID, sessionID: sessionID, processID: processID, sourceID: sourceID,
                                 externalID: turnID, occurredAt: timestamp, kind: kind,
                                 title: "Codex " + lifecycle.rawValue, progress: nil)
        return ExternalProcessEvent(id: eventID, sessionID: sessionID,
                                    sourceID: sourceID, sequence: UInt64(max(0, timestamp.timeIntervalSince1970 * 1000)),
                                    occurredAt: timestamp,
                                    process: AnchorProcess(id: processID, sessionID: sessionID, sourceID: sourceID,
                                                           externalID: turnID, sourceName: "Codex", sourceSymbol: "C",
                                                           sourceTone: "cyan", title: "Codex turn", status: status,
                                                           progress: nil, updatedAt: timestamp),
                                    event: event, deduplicationKey: key,
                                    observedOutcome: lifecycle == .aborted ? .interrupted : nil)
    }
}
