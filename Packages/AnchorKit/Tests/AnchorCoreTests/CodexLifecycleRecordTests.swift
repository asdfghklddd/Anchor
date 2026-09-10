import Foundation
import Testing
@testable import AnchorCore

@Test("Codex lifecycle decoder keeps IDs and ignores message fields")
func decodesCodexLifecycleRecord() throws {
    let data = Data(#"{"timestamp":"2026-09-05T01:02:03Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","last_agent_message":"private body"}}"#.utf8)
    let record = try #require(CodexLifecycleRecord(json: data))
    #expect(record.lifecycle == .completed)
    #expect(record.turnID == "turn-1")
    #expect(record.type == "task_complete")
    let event = record.externalEvent(sessionID: UUID(), sourceID: UUID())
    #expect(event.process.status == .completed)
    #expect(event.process.externalID == "turn-1")
}

@Test("Real millisecond timestamps preserve distinct start and finish event identities")
func codexPhasesHaveDistinctEvents() throws {
    func record(_ phase: String) throws -> CodexLifecycleRecord {
        let json = #"{"timestamp":"2026-09-04T12:09:51.235Z","type":"event_msg","payload":{"type":"PHASE","turn_id":"turn-1"}}"#
        return try #require(CodexLifecycleRecord(json: Data(json.replacingOccurrences(of: "PHASE", with: phase).utf8)))
    }
    let session = UUID()
    let source = UUID()
    let started = try record("task_started").externalEvent(sessionID: session, sourceID: source)
    let completed = try record("task_complete").externalEvent(sessionID: session, sourceID: source)
    #expect(started.process.id == completed.process.id)
    #expect(started.id != completed.id)
    #expect(started.deduplicationKey != completed.deduplicationKey)
    #expect(completed.id == (try record("task_complete")).externalEvent(sessionID: session, sourceID: source).id)
    #expect(completed.process.progress == nil)
    let wrongEnvelope = #"{"timestamp":"2026-09-04T12:09:51.235Z","type":"response_item","payload":{"type":"task_complete","turn_id":"turn-1"}}"#
    #expect(CodexLifecycleRecord(json: Data(wrongEnvelope.utf8)) == nil)
}

@Test(
    "Codex terminal lifecycle keeps its task-level meaning",
    arguments: [
        ("task_complete", ProcessStatus.completed, AnchorRunOutcome.completed, AnchorTaskEventKind.completed),
        ("turn_aborted", ProcessStatus.failed, AnchorRunOutcome.interrupted, AnchorTaskEventKind.interrupted),
    ]
)
func codexTerminalLifecycleMeaning(
    phase: String,
    processStatus: ProcessStatus,
    runOutcome: AnchorRunOutcome,
    eventKind: AnchorTaskEventKind
) throws {
    let json = #"{"timestamp":"2026-09-05T01:02:03.123Z","type":"event_msg","payload":{"type":"PHASE","turn_id":"turn-terminal"}}"#
        .replacingOccurrences(of: "PHASE", with: phase)
    let record = try #require(CodexLifecycleRecord(json: Data(json.utf8)))
    let observation = record.externalEvent(sessionID: UUID(), sourceID: UUID())
    let association = AnchorEventAssociation(
        taskID: UUID(),
        workItemID: UUID(),
        confirmedByUser: true
    )

    #expect(observation.process.status == processStatus)
    #expect(observation.makeRun(association: association).outcome == runOutcome)
    #expect(observation.makeTaskEvent(association: association).kind == eventKind)
}

@Test("External source events written before task outcome metadata remain readable")
func legacyExternalEventWithoutObservedOutcomeDecodes() throws {
    let json = #"{"timestamp":"2026-09-05T01:02:03.123Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"legacy-abort"}}"#
    let record = try #require(CodexLifecycleRecord(json: Data(json.utf8)))
    let current = record.externalEvent(sessionID: UUID(), sourceID: UUID())
    var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: Any]
    )
    object.removeValue(forKey: "observedOutcome")

    let legacy = try JSONDecoder().decode(
        ExternalProcessEvent.self,
        from: JSONSerialization.data(withJSONObject: object)
    )

    #expect(legacy.observedOutcome == nil)
    #expect(legacy.process.status == .failed)
}
