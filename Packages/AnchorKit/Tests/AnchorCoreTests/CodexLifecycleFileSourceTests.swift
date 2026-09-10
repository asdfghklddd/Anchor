import Foundation
import Testing
@testable import AnchorCore

@Test("Built-in process sources have distinct identities")
func builtInSourceIdentifiersAreUnique() {
    let ids = [
        FileProcessSource.defaultSourceID,
        WebProcessSource.defaultSourceID,
        MacWorkspaceProcessSource.defaultSourceID,
        CodexLifecycleFileSource.defaultSourceID,
    ]
    #expect(Set(ids).count == ids.count)
}

@Test("Codex file source emits lifecycle events from appended JSONL")
func codexFileSourceEmitsEvent() async throws {
    let url = URL.temporaryDirectory.appending(path: "codex-(UUID().uuidString).jsonl")
    defer { try? FileManager.default.removeItem(at: url) }
    let session = ProcessSourceSessionContext(sessionID: UUID(), startedAt: Date(timeIntervalSince1970: 0))
    let line = #"{"timestamp":"2026-09-05T01:02:03.123Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"t-file"}}"# + "\n"
    try Data(line.utf8).write(to: url)
    let source = CodexLifecycleFileSource(fileURL: url, pollInterval: 0.05, sessionContextProvider: { session })
    let stream = source.events()
    var iterator = stream.makeAsyncIterator()
    let event = try #require(await iterator.next())
    #expect(event.process.externalID == "t-file")
    #expect(event.process.status == .completed)
}

@Test("Codex file source preserves lifecycle rows split across bounded reads")
func codexFileSourceUsesBoundedReads() async throws {
    let url = URL.temporaryDirectory.appending(
        path: "codex-bounded-" + UUID().uuidString + ".jsonl"
    )
    defer { try? FileManager.default.removeItem(at: url) }
    let session = ProcessSourceSessionContext(
        sessionID: UUID(),
        startedAt: Date(timeIntervalSince1970: 0)
    )
    let line = #"{"timestamp":"2026-09-05T01:02:03.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"split-across-several-reads"}}"# + "\n"
    try Data(line.utf8).write(to: url)
    let source = CodexLifecycleFileSource(
        fileURL: url,
        pollInterval: 0.01,
        maximumReadBytes: 32,
        sessionContextProvider: { session }
    )
    #expect(source.maximumReadBytes == 32)
    var iterator = source.events().makeAsyncIterator()
    let event = try #require(await iterator.next())
    #expect(event.process.externalID == "split-across-several-reads")
    #expect(event.process.status == .running)
}

@Test("Codex file source ignores lifecycle rows older than the Anchor task")
func codexFileSourceHonorsTaskStart() async throws {
    let url = URL.temporaryDirectory.appending(path: "codex-boundary-" + UUID().uuidString + ".jsonl")
    defer { try? FileManager.default.removeItem(at: url) }
    let old = #"{"timestamp":"2026-09-05T01:02:03.123Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"old"}}"#
    let current = #"{"timestamp":"2026-09-07T01:02:03.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"current"}}"#
    try Data((old + "\n" + current + "\n").utf8).write(to: url)
    let start = try #require(ISO8601DateFormatter().date(from: "2026-09-06T00:00:00Z"))
    let context = ProcessSourceSessionContext(sessionID: UUID(), startedAt: start)
    let source = CodexLifecycleFileSource(fileURL: url, pollInterval: 0.05, sessionContextProvider: { context })
    var iterator = source.events().makeAsyncIterator()
    #expect(try await iterator.next()?.process.externalID == "current")
}

@Test("Codex file source resumes after restart without replaying committed rows")
func codexFileSourceResumesFromDurableCheckpoint() async throws {
    let directory = URL.temporaryDirectory.appending(path: "codex-resume-" + UUID().uuidString)
    let url = directory.appending(path: "session.jsonl")
    let checkpointURL = directory.appending(path: "checkpoints.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let first = lifecycleLine(type: "task_started", turnID: "first")
    try Data(first.utf8).write(to: url)
    let context = ProcessSourceSessionContext(sessionID: UUID(), startedAt: .distantPast)
    let store = CodexLifecycleCheckpointStore(storageURL: checkpointURL)

    do {
        let source = CodexLifecycleFileSource(
            fileURL: url,
            pollInterval: 0.05,
            sessionContextProvider: { context },
            checkpointStore: store
        )
        var iterator = source.events().makeAsyncIterator()
        let event = try #require(await iterator.next())
        #expect(event.process.externalID == "first")
        try await source.acknowledge(event)
    }
    try await waitForCheckpoint(store)
    let checkpointText = try String(contentsOf: checkpointURL, encoding: .utf8)
    #expect(!checkpointText.contains(url.path))
    try append(lifecycleLine(type: "task_complete", turnID: "second"), to: url)

    let restarted = CodexLifecycleFileSource(
        fileURL: url,
        pollInterval: 0.05,
        sessionContextProvider: { context },
        checkpointStore: CodexLifecycleCheckpointStore(storageURL: checkpointURL)
    )
    var iterator = restarted.events().makeAsyncIterator()
    let event = try #require(await iterator.next())
    #expect(event.process.externalID == "second")
    #expect(event.process.status == .completed)
}

@Test("Codex file source replays an unacknowledged row after restart")
func codexFileSourceDoesNotCheckpointBeforeAcknowledgement() async throws {
    let directory = URL.temporaryDirectory.appending(path: "codex-unacked-" + UUID().uuidString)
    let url = directory.appending(path: "session.jsonl")
    let checkpointURL = directory.appending(path: "checkpoints.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(lifecycleLine(type: "task_started", turnID: "must-replay").utf8).write(to: url)
    let context = ProcessSourceSessionContext(sessionID: UUID(), startedAt: .distantPast)

    do {
        let source = CodexLifecycleFileSource(
            fileURL: url,
            pollInterval: 0.05,
            sessionContextProvider: { context },
            checkpointStore: CodexLifecycleCheckpointStore(storageURL: checkpointURL)
        )
        var iterator = source.events().makeAsyncIterator()
        #expect(try await iterator.next()?.process.externalID == "must-replay")
        try await Task.sleep(for: .milliseconds(50))
        #expect(!FileManager.default.fileExists(atPath: checkpointURL.path))
    }

    let store = CodexLifecycleCheckpointStore(storageURL: checkpointURL)
    let restarted = CodexLifecycleFileSource(
        fileURL: url,
        pollInterval: 0.05,
        sessionContextProvider: { context },
        checkpointStore: store
    )
    var iterator = restarted.events().makeAsyncIterator()
    let replayed = try #require(await iterator.next())
    #expect(replayed.process.externalID == "must-replay")
    try await restarted.acknowledge(replayed)
    try await waitForCheckpoint(store)
}

@Test("Codex file source resets its offset after atomic file replacement")
func codexFileSourceDetectsReplacement() async throws {
    let directory = URL.temporaryDirectory.appending(path: "codex-replace-" + UUID().uuidString)
    let url = directory.appending(path: "session.jsonl")
    let replacement = directory.appending(path: "replacement.jsonl")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(lifecycleLine(type: "task_started", turnID: "aaaaa").utf8).write(to: url)
    let context = ProcessSourceSessionContext(sessionID: UUID(), startedAt: .distantPast)
    let source = CodexLifecycleFileSource(fileURL: url, pollInterval: 0.05, sessionContextProvider: { context })
    var iterator = source.events().makeAsyncIterator()
    #expect(try await iterator.next()?.process.externalID == "aaaaa")

    try Data(lifecycleLine(type: "task_complete", turnID: "bbbbb").utf8).write(to: replacement)
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: replacement, to: url)

    let event = try #require(await iterator.next())
    #expect(event.process.externalID == "bbbbb")
    #expect(event.process.status == .completed)
}

@Test("Codex file source recovers after in-place truncation")
func codexFileSourceDetectsTruncation() async throws {
    let directory = URL.temporaryDirectory.appending(path: "codex-truncate-" + UUID().uuidString)
    let url = directory.appending(path: "session.jsonl")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(lifecycleLine(type: "task_started", turnID: "before-truncation").utf8).write(to: url)
    let context = ProcessSourceSessionContext(sessionID: UUID(), startedAt: .distantPast)
    let source = CodexLifecycleFileSource(fileURL: url, pollInterval: 0.05, sessionContextProvider: { context })
    var iterator = source.events().makeAsyncIterator()
    #expect(try await iterator.next()?.process.externalID == "before-truncation")

    let handle = try FileHandle(forWritingTo: url)
    try handle.truncate(atOffset: 0)
    try handle.close()
    try await Task.sleep(for: .milliseconds(100))
    try append(lifecycleLine(type: "task_complete", turnID: "after-truncation"), to: url)

    let event = try #require(await iterator.next())
    #expect(event.process.externalID == "after-truncation")
    #expect(event.process.status == .completed)
}

private func lifecycleLine(type: String, turnID: String) -> String {
    #"{"timestamp":"2026-09-09T01:02:03.123Z","type":"event_msg","payload":{"type":"\#(type)","turn_id":"\#(turnID)"}}"# + "\n"
}

private func append(_ text: String, to url: URL) throws {
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(text.utf8))
}

private func waitForCheckpoint(
    _ store: CodexLifecycleCheckpointStore
) async throws {
    for _ in 0..<100 {
        if try await store.load(
            for: CodexLifecycleFileSource.checkpointKey(
                for: CodexLifecycleFileSource.defaultSourceID
            )
        ) != nil { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for Codex checkpoint persistence")
}
