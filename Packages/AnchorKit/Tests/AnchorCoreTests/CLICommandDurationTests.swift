import Foundation
import Testing
@testable import AnchorCore

@Suite("CLI command duration and interruption")
struct CLICommandDurationTests {
    @Test("Commands shorter than ten seconds never become processes")
    func shortCommandsAreSetAside() async throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        let commandID = UUID(), started = Date.now.addingTimeInterval(-30)
        try write(CLIProcessSignal(commandID: commandID, phase: .started, occurredAt: started,
                                   executableName: "ls"), to: inbox, name: "a.json")
        try write(CLIProcessSignal(commandID: commandID, phase: .finished, occurredAt: started.addingTimeInterval(0.4),
                                   executableName: "ls", exitCode: 0), to: inbox, name: "b.json")

        let events = try await collect(from: source(inbox), for: .milliseconds(300))

        #expect(events.isEmpty)
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".ignored/a.json").path))
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".ignored/b.json").path))
    }

    @Test("A long command reports its start before its finish")
    func longCommandIsReportedInOrder() async throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        let commandID = UUID(), started = Date.now.addingTimeInterval(-60)
        // The finish sorts first by file name; delivery must still follow time.
        try write(CLIProcessSignal(commandID: commandID, phase: .finished, occurredAt: started.addingTimeInterval(42),
                                   executableName: "swift", exitCode: 0), to: inbox, name: "a.json")
        try write(CLIProcessSignal(commandID: commandID, phase: .started, occurredAt: started,
                                   executableName: "swift"), to: inbox, name: "b.json")

        let events = try await collect(from: source(inbox), for: .milliseconds(300))

        #expect(events.map(\.process.status) == [.running, .completed])
    }

    @Test("A fresh start waits until it has run for ten seconds")
    func freshStartWaits() async throws {
        let inbox = try makeInbox()
        defer { try? FileManager.default.removeItem(at: inbox) }
        try write(CLIProcessSignal(commandID: UUID(), phase: .started, executableName: "npm"),
                  to: inbox, name: "a.json")

        let events = try await collect(from: source(inbox), for: .milliseconds(300))

        #expect(events.isEmpty)
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: "a.json").path))
    }

    @Test("Ctrl-C and a closed terminal read as interrupted, other exits as failed")
    func interruptionIsNotFailure() throws {
        for (code, interrupted) in [(130, true), (129, true), (131, true), (1, false), (143, false)] {
            let signal = CLIProcessSignal(commandID: UUID(), phase: .finished, executableName: "make", exitCode: code)
            let external = try signal.externalEvent(sessionID: UUID(), sourceID: BuiltInProcessSourceID.file)
            var process = external.process
            process.events = [try #require(external.event)]
            #expect(process.status == .failed)
            #expect(process.isInterrupted == interrupted)
            #expect((external.observedOutcome == .interrupted) == interrupted)
        }
    }

    private func source(_ inbox: URL) -> FileProcessSource {
        FileProcessSource(directoryURL: inbox, pollInterval: 0.02, sessionContextProvider: {
            ProcessSourceSessionContext(sessionID: UUID(), startedAt: .distantPast)
        })
    }

    private func makeInbox() throws -> URL {
        let inbox = URL.temporaryDirectory.appending(path: "anchor-cli-duration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        return inbox
    }

    private func write(_ signal: CLIProcessSignal, to inbox: URL, name: String) throws {
        try JSONEncoder.anchorExternal.encode(signal).write(to: inbox.appending(path: name), options: .atomic)
    }

    private func collect(
        from source: FileProcessSource,
        for duration: Duration
    ) async throws -> [ExternalProcessEvent] {
        let stream = source.events()
        let collector = Task {
            var events: [ExternalProcessEvent] = []
            for try await event in stream { events.append(event) }
            return events
        }
        try await Task.sleep(for: duration)
        collector.cancel()
        return try await collector.value
    }
}
