import Foundation
import Testing
@testable import AnchorCore

@Test("Codex supervisor discovers metadata and the latest lifecycle without message bodies")
func discoversCodexTaskCandidate() async throws {
    let root = URL.temporaryDirectory.appending(path: "codex-supervisor-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "rollout-2026-09-14T00-00-00-01a09de5-4db0-7bb2-bbc1-1c75c61136c6.jsonl")
    let lines = [
        #"{"timestamp":"2026-09-14T00:00:00.000Z","type":"session_meta","payload":{"id":"01a09de5-4db0-7bb2-bbc1-1c75c61136c6","cwd":"/Users/example/Anchor","originator":"Codex Desktop","private_prompt":"must-not-escape"}}"#,
        #"{"timestamp":"2026-09-14T00:00:01.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#,
        #"{"timestamp":"2026-09-14T00:00:02.000Z","type":"response_item","payload":{"type":"message","content":"must-not-escape"}}"#,
    ]
    try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: file)
    let supervisor = CodexTaskSupervisor(rootURL: root, pollInterval: 0.25)

    let candidate = try #require(await supervisor.snapshot().first)

    #expect(candidate.id == "01a09de5-4db0-7bb2-bbc1-1c75c61136c6")
    #expect(candidate.workspaceName == "Anchor")
    #expect(candidate.originator == "Codex Desktop")
    #expect(candidate.activity == .running)
    #expect(String(describing: candidate).contains("must-not-escape") == false)
}

@Test("Codex supervisor refreshes a changed file")
func refreshesCodexTaskCandidate() async throws {
    let root = URL.temporaryDirectory.appending(path: "codex-supervisor-refresh-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "session.jsonl")
    let metadata = #"{"timestamp":"2026-09-14T00:00:00.000Z","type":"session_meta","payload":{"id":"thread-1","cwd":"/tmp/Anchor","originator":"Codex Desktop"}}"#
    let started = #"{"timestamp":"2026-09-14T00:00:01.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#
    try Data("\(metadata)\n\(started)\n".utf8).write(to: file)
    let supervisor = CodexTaskSupervisor(rootURL: root, pollInterval: 0.25)
    #expect(await supervisor.snapshot().first?.activity == .running)

    let completed = #"{"timestamp":"2026-09-14T00:00:02.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\(completed)\n".utf8))
    try handle.close()

    #expect(await supervisor.snapshot().first?.activity == .completed)
}

@Test("Codex supervisor continuously publishes lifecycle changes")
func publishesCodexTaskCandidateChanges() async throws {
    let root = URL.temporaryDirectory.appending(path: "codex-supervisor-stream-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appending(path: "session.jsonl")
    let metadata = #"{"timestamp":"2026-09-14T00:00:00.000Z","type":"session_meta","payload":{"id":"thread-1","cwd":"/tmp/Anchor","originator":"Codex Desktop"}}"#
    let started = #"{"timestamp":"2026-09-14T00:00:01.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}"#
    try Data("\(metadata)\n\(started)\n".utf8).write(to: file)
    let supervisor = CodexTaskSupervisor(rootURL: root, pollInterval: 0.25)
    let stream = await supervisor.snapshots()
    let reader = Task { () -> [CodexTaskActivity] in
        var activities: [CodexTaskActivity] = []
        for await candidates in stream {
            guard let activity = candidates.first?.activity else { continue }
            activities.append(activity)
            if activities.count == 2 { return activities }
        }
        return activities
    }
    defer { reader.cancel() }

    try await Task.sleep(for: .milliseconds(300))
    let completed = #"{"timestamp":"2026-09-14T00:00:02.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1"}}"#
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\(completed)\n".utf8))
    try handle.close()

    let activities = try await withThrowingTaskGroup(
        of: [CodexTaskActivity].self
    ) { group in
        group.addTask { await reader.value }
        group.addTask {
            try await Task.sleep(for: .seconds(2))
            throw CodexSupervisorTestError.timedOut
        }
        let value = try await group.next() ?? []
        group.cancelAll()
        return value
    }

    #expect(activities == [.running, .completed])
}

private enum CodexSupervisorTestError: Error {
    case timedOut
}
