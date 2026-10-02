import Foundation
import Testing
@testable import AnchorCore

@Suite("CLI command signals")
struct CLIProcessSignalTests {
    @Test("CLI signals retain only executable and workspace basenames")
    func signalMinimizesCommandData() {
        let signal = CLIProcessSignal(
            commandID: UUID(),
            phase: .started,
            executableName: "/usr/bin/rsync --archive /private/source",
            workspaceName: "/Users/example/Private Project",
            terminalName: "  iTerm2  "
        )

        #expect(signal.executableName == "rsync")
        #expect(signal.workspaceName == "Private Project")
        #expect(signal.terminalName == "iTerm2")
    }

    @Test("Decoded CLI signals cannot bypass privacy minimization")
    func decodedSignalIsSanitized() throws {
        let signal = CLIProcessSignal(
            commandID: UUID(),
            phase: .started,
            executableName: "safe"
        )
        let occurredAt = ISO8601DateFormatter().string(from: signal.occurredAt)
        let raw = """
        {
          "id":"\(signal.id.uuidString)",
          "schema":"\(CLIProcessSignal.schemaIdentifier)",
          "commandID":"\(signal.commandID.uuidString)",
          "phase":"started",
          "occurredAt":"\(occurredAt)",
          "executableName":"/usr/bin/rsync --archive /private/source",
          "workspaceName":"/Users/example/Private Project",
          "terminalName":"  iTerm2  "
        }
        """

        let decoded = try JSONDecoder.anchorExternal.decode(
            CLIProcessSignal.self,
            from: Data(raw.utf8)
        )

        #expect(decoded.executableName == "rsync")
        #expect(decoded.workspaceName == "Private Project")
        #expect(decoded.terminalName == "iTerm2")
    }

    @Test("A start signal maps to an indeterminate running process")
    func startSignalMapsToRunningProcess() throws {
        let sessionID = UUID()
        let sourceID = UUID()
        let commandID = UUID()
        let signal = CLIProcessSignal(
            commandID: commandID,
            phase: .started,
            executableName: "xcodebuild",
            workspaceName: "Anchor",
            terminalName: "Terminal"
        )

        let event = try signal.externalEvent(sessionID: sessionID, sourceID: sourceID)

        #expect(event.sessionID == sessionID)
        #expect(event.sourceID == sourceID)
        #expect(event.process.externalID == commandID.uuidString)
        #expect(event.process.status == .running)
        #expect(event.process.progress == nil)
        #expect(event.event?.kind == .created)
    }

    @Test("A zero exit code completes the same stable process")
    func successfulFinishCompletesStableProcess() throws {
        let sessionID = UUID()
        let sourceID = UUID()
        let commandID = UUID()
        let started = CLIProcessSignal(
            commandID: commandID,
            phase: .started,
            executableName: "make"
        )
        let finished = CLIProcessSignal(
            commandID: commandID,
            phase: .finished,
            executableName: "make",
            exitCode: 0
        )

        let startEvent = try started.externalEvent(sessionID: sessionID, sourceID: sourceID)
        let finishEvent = try finished.externalEvent(sessionID: sessionID, sourceID: sourceID)

        #expect(startEvent.process.id == finishEvent.process.id)
        #expect(finishEvent.process.status == .completed)
        #expect(finishEvent.process.progress == 1)
        #expect(finishEvent.event?.kind == .completed)
    }

    @Test("A nonzero exit code maps to a failed process")
    func failedFinishPreservesExitCode() throws {
        let signal = CLIProcessSignal(
            commandID: UUID(),
            phase: .finished,
            executableName: "swift",
            exitCode: 1
        )

        let event = try signal.externalEvent(sessionID: UUID(), sourceID: UUID())

        #expect(event.process.status == .failed)
        #expect(event.process.metric == "1")
        #expect(event.event?.kind == .failed)
    }

    @Test("A finish signal without an exit code is rejected")
    func finishRequiresExitCode() {
        let signal = CLIProcessSignal(
            commandID: UUID(),
            phase: .finished,
            executableName: "swift"
        )

        #expect(throws: CLIProcessSignalError.missingExitCode) {
            try signal.externalEvent(sessionID: UUID(), sourceID: UUID())
        }
    }

    @Test("The file source binds a CLI signal to the active Anchor session")
    func fileSourceBindsCurrentSession() async throws {
        let inbox = URL.temporaryDirectory.appending(
            path: "anchor-cli-signal-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: inbox) }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let sessionID = UUID()
        let commandID = UUID()
        let signal = CLIProcessSignal(
            commandID: commandID,
            phase: .started,
            executableName: "ffmpeg",
            workspaceName: "/Users/example/Movies"
        )
        let file = inbox.appending(path: "signal.json")
        try JSONEncoder.anchorExternal.encode(signal).write(to: file, options: .atomic)
        let source = FileProcessSource(
            directoryURL: inbox,
            pollInterval: 0.02,
            sessionContextProvider: {
                ProcessSourceSessionContext(
                    sessionID: sessionID,
                    startedAt: signal.occurredAt.addingTimeInterval(-1)
                )
            }
        )

        let received = try await firstEvent(from: source.events())

        #expect(received.sessionID == sessionID)
        #expect(received.process.externalID == commandID.uuidString)
        #expect(received.process.title == "ffmpeg")
        #expect(FileManager.default.fileExists(
            atPath: inbox.appending(path: ".processed/signal.json").path
        ))
    }

    @Test("CLI signals older than the active session are ignored")
    func staleSignalDoesNotEnterNewSession() async throws {
        let inbox = URL.temporaryDirectory.appending(
            path: "anchor-cli-stale-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: inbox) }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let sessionID = UUID()
        let sessionStartedAt = Date.now
        let stale = CLIProcessSignal(
            commandID: UUID(),
            phase: .started,
            occurredAt: sessionStartedAt.addingTimeInterval(-60),
            executableName: "old-command"
        )
        let current = CLIProcessSignal(
            commandID: UUID(),
            phase: .started,
            occurredAt: sessionStartedAt.addingTimeInterval(1),
            executableName: "current-command"
        )
        try JSONEncoder.anchorExternal.encode(stale).write(
            to: inbox.appending(path: "000-stale.json"),
            options: .atomic
        )
        try JSONEncoder.anchorExternal.encode(current).write(
            to: inbox.appending(path: "001-current.json"),
            options: .atomic
        )
        let source = FileProcessSource(
            directoryURL: inbox,
            pollInterval: 0.02,
            sessionContextProvider: {
                ProcessSourceSessionContext(
                    sessionID: sessionID,
                    startedAt: sessionStartedAt
                )
            }
        )

        let received = try await firstEvent(from: source.events())

        #expect(received.process.title == "current-command")
        #expect(FileManager.default.fileExists(
            atPath: inbox.appending(path: ".ignored/000-stale.json").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: inbox.appending(path: ".processed/001-current.json").path
        ))
    }

    @Test("Retired browser signals are quarantined without blocking CLI work")
    func retiredWebSignalDoesNotBlockCLI() async throws {
        let inbox = URL.temporaryDirectory.appending(path: "anchor-retired-web-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: inbox) }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let legacy = #"{"id":"01A23B45-C678-4901-A234-56789BCDEF01","schema":"anchor.web.activity.v1","activityID":"11A23B45-C678-4901-A234-56789BCDEF02","sequence":42,"state":"active","occurredAt":"2026-08-25T10:00:00Z","siteHost":"docs.example.com","browserName":"Safari"}"#
        try Data(legacy.utf8).write(to: inbox.appending(path: "000-web.json"))
        let sessionID = UUID()
        let signal = CLIProcessSignal(commandID: UUID(), phase: .started, executableName: "swift")
        try JSONEncoder.anchorExternal.encode(signal).write(to: inbox.appending(path: "001-cli.json"))
        let source = FileProcessSource(directoryURL: inbox, pollInterval: 0.02,
            sessionContextProvider: {
                ProcessSourceSessionContext(sessionID: sessionID, startedAt: .distantPast)
            })
        let received = try await firstEvent(from: source.events())
        #expect(received.sessionID == sessionID)
        #expect(received.sourceID == BuiltInProcessSourceID.file)
        #expect(received.process.title == "swift")
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".failed/000-web.json").path))
        #expect(FileManager.default.fileExists(atPath: inbox.appending(path: ".processed/001-cli.json").path))
    }

    private func firstEvent(
        from stream: AsyncThrowingStream<ExternalProcessEvent, Error>
    ) async throws -> ExternalProcessEvent {
        try await withThrowingTaskGroup(of: ExternalProcessEvent.self) { group in
            group.addTask {
                for try await event in stream {
                    return event
                }
                throw CLITestTimeout.expired
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw CLITestTimeout.expired
            }
            guard let event = try await group.next() else {
                throw CLITestTimeout.expired
            }
            group.cancelAll()
            return event
        }
    }
}

private enum CLITestTimeout: Error {
    case expired
}

@Test("Terminal completion stays with its original anchor after task switching")
func terminalCompletionRetainsAnchorOwner() throws {
    let commandID = UUID()
    let signal = CLIProcessSignal(commandID: commandID, phase: .started, executableName: "swift")
    var original = AnchorSession(goal: AnchorGoal(title: "Original", completionCriteria: "Done"))
    original.processes = [try signal.externalEvent(sessionID: original.id, sourceID: BuiltInProcessSourceID.file).process]
    let selected = AnchorSession(goal: AnchorGoal(title: "Selected later", completionCriteria: "Done"))
    let projection = SessionProjection(session: selected, additionalSessions: [original])
    let finish = CLIProcessSignal(commandID: commandID, phase: .finished, executableName: "swift", exitCode: 0)
    #expect(finish.sessionContext(in: projection)?.sessionID == original.id)
    let fresh = CLIProcessSignal(commandID: UUID(), phase: .started, executableName: "swift")
    #expect(fresh.sessionContext(in: projection)?.sessionID == selected.id)
    original.status = .completed
    #expect(finish.sessionContext(in: SessionProjection(session: selected, archivedSessions: [original])) == nil)
}
