import Foundation
import Testing
@testable import AnchorCore

@Suite("Web activity signals")
struct WebProcessSignalTests {
    @Test("Web signals reduce full URLs to a lowercase hostname")
    func signalMinimizesURLData() throws {
        let signal = try WebProcessSignal(
            activityID: UUID(),
            sequence: 1,
            state: .active,
            siteHost: "https://Docs.Example.com/private/document?token=secret"
        )

        #expect(signal.siteHost == "docs.example.com")
    }

    @Test("Decoded web signals cannot retain URL paths")
    func decodedSignalIsSanitized() throws {
        let id = UUID()
        let activityID = UUID()
        let occurredAt = ISO8601DateFormatter().string(from: .now)
        let raw = """
        {
          "id":"\(id.uuidString)",
          "schema":"\(WebProcessSignal.schemaIdentifier)",
          "activityID":"\(activityID.uuidString)",
          "sequence":2,
          "state":"active",
          "occurredAt":"\(occurredAt)",
          "siteHost":"https://app.example.com/private/path?prompt=secret",
          "browserName":"  Browser  "
        }
        """

        let decoded = try JSONDecoder.anchorExternal.decode(
            WebProcessSignal.self,
            from: Data(raw.utf8)
        )

        #expect(decoded.siteHost == "app.example.com")
        #expect(decoded.browserName == "Browser")
    }

    @Test("Generic active-tab changes update a process without timeline noise")
    func activeTabDoesNotCreateTimelineEvent() throws {
        let signal = try WebProcessSignal(
            activityID: UUID(),
            sequence: 3,
            state: .active,
            siteHost: "figma.com",
            browserName: "Browser"
        )

        let event = try signal.externalEvent(sessionID: UUID(), sourceID: UUID())

        #expect(event.process.title == "figma.com")
        #expect(event.process.status == .running)
        #expect(event.process.progress == nil)
        #expect(event.event == nil)
    }

    @Test("Structured web progress and completion keep one stable process")
    func progressAndCompletionShareIdentity() throws {
        let sessionID = UUID()
        let sourceID = UUID()
        let activityID = UUID()
        let running = try WebProcessSignal(
            activityID: activityID,
            sequence: 4,
            state: .running,
            siteHost: "render.example.com",
            siteName: "Render",
            progress: 0.42
        )
        let completed = try WebProcessSignal(
            activityID: activityID,
            sequence: 5,
            state: .completed,
            siteHost: "render.example.com",
            siteName: "Render"
        )

        let progressEvent = try running.externalEvent(
            sessionID: sessionID,
            sourceID: sourceID
        )
        let completedEvent = try completed.externalEvent(
            sessionID: sessionID,
            sourceID: sourceID
        )

        #expect(progressEvent.process.id == completedEvent.process.id)
        #expect(progressEvent.event?.kind == .progress)
        #expect(completedEvent.process.status == .completed)
        #expect(completedEvent.process.progress == 1)
    }

    @Test("Out-of-range web progress is rejected")
    func invalidProgressIsRejected() throws {
        let signal = try WebProcessSignal(
            activityID: UUID(),
            sequence: 6,
            state: .running,
            siteHost: "example.com",
            progress: 1.5
        )

        #expect(throws: WebProcessSignalError.invalidProgress) {
            try signal.validate()
        }
    }

    @Test("The web file source binds a signal to the active Anchor session")
    func webSourceBindsCurrentSession() async throws {
        let inbox = URL.temporaryDirectory.appending(
            path: "anchor-web-signal-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: inbox) }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        let sessionID = UUID()
        let signal = try WebProcessSignal(
            activityID: UUID(),
            sequence: 7,
            state: .active,
            siteHost: "docs.example.com"
        )
        try JSONEncoder.anchorExternal.encode(signal).write(
            to: inbox.appending(path: "signal.json"),
            options: .atomic
        )
        let source = WebProcessSource(
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
        #expect(received.sourceID == WebProcessSource.defaultSourceID)
        #expect(received.process.title == "docs.example.com")
        #expect(FileManager.default.fileExists(
            atPath: inbox.appending(path: ".processed/signal.json").path
        ))
    }

    private func firstEvent(
        from stream: AsyncThrowingStream<ExternalProcessEvent, Error>
    ) async throws -> ExternalProcessEvent {
        try await withThrowingTaskGroup(of: ExternalProcessEvent.self) { group in
            group.addTask {
                for try await event in stream {
                    return event
                }
                throw WebTestTimeout.expired
            }
            group.addTask {
                try await Task.sleep(for: .seconds(2))
                throw WebTestTimeout.expired
            }
            guard let event = try await group.next() else {
                throw WebTestTimeout.expired
            }
            group.cancelAll()
            return event
        }
    }
}

private enum WebTestTimeout: Error {
    case expired
}
