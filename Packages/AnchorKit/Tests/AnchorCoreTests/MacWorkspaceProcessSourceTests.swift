#if os(macOS)
import Foundation
import Testing
@testable import AnchorCore

@Suite("Mac workspace process source")
struct MacWorkspaceProcessSourceTests {
    @Test("The initial snapshot creates processes without timeline noise")
    func initialSnapshotIsQuiet() async throws {
        let sessionID = UUID()
        let source = MacWorkspaceProcessSource(
            sessionIDProvider: { sessionID },
            snapshotProvider: {
                [
                    MacApplicationSnapshot(
                        identifier: "com.example.Editor",
                        localizedName: "Editor",
                        processIdentifier: 101,
                        isActive: true
                    ),
                    MacApplicationSnapshot(
                        identifier: "com.example.Renderer",
                        localizedName: "Renderer",
                        processIdentifier: 202,
                        isActive: false
                    ),
                ]
            },
            signalProvider: { oneSignal() }
        )

        let events = try await collect(source.events())

        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.event == nil })
        #expect(events.compactMap(\.process.externalID).sorted() == [
            "com.example.Editor",
            "com.example.Renderer",
        ])
        #expect(events.first(where: { $0.process.externalID == "com.example.Editor" })?.process.metric == "Foreground")
        #expect(events.first(where: { $0.process.externalID == "com.example.Renderer" })?.process.metric == "Background")
    }

    @Test("Foreground changes emit only changed application states")
    func activationChangeProducesTransitions() async {
        let sourceID = UUID()
        let sessionID = UUID()
        let reducer = MacWorkspaceObservationReducer(sourceID: sourceID)
        let initial = [
            application("com.example.Editor", name: "Editor", pid: 101, active: true),
            application("com.example.Browser", name: "Browser", pid: 202, active: false),
        ]
        _ = await reducer.reconcile(initial, sessionID: sessionID, observedAt: .now)

        let changed = [
            application("com.example.Editor", name: "Editor", pid: 101, active: false),
            application("com.example.Browser", name: "Browser", pid: 202, active: true),
        ]
        let events = await reducer.reconcile(changed, sessionID: sessionID, observedAt: .now)

        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.event?.kind == .note })
        #expect(events.first(where: { $0.process.externalID == "com.example.Editor" })?.process.metric == "Background")
        #expect(events.first(where: { $0.process.externalID == "com.example.Browser" })?.process.metric == "Foreground")
    }

    @Test("Unchanged reconciliation does not emit duplicate heartbeats")
    func unchangedSnapshotIsDeduplicated() async {
        let reducer = MacWorkspaceObservationReducer(sourceID: UUID())
        let sessionID = UUID()
        let snapshot = [application("com.example.Editor", name: "Editor", pid: 101, active: true)]

        _ = await reducer.reconcile(snapshot, sessionID: sessionID, observedAt: .now)
        let duplicate = await reducer.reconcile(snapshot, sessionID: sessionID, observedAt: .now)

        #expect(duplicate.isEmpty)
    }

    @Test("Termination preserves identity and marks the process disconnected")
    func terminationMarksProcessDisconnected() async throws {
        let reducer = MacWorkspaceObservationReducer(sourceID: UUID())
        let sessionID = UUID()
        let snapshot = [application("com.example.Renderer", name: "Renderer", pid: 303, active: false)]
        let initial = await reducer.reconcile(snapshot, sessionID: sessionID, observedAt: .now)
        let initialProcess = try #require(initial.first?.process)

        let stopped = await reducer.reconcile([], sessionID: sessionID, observedAt: .now)
        let stoppedProcess = try #require(stopped.first?.process)

        #expect(stopped.count == 1)
        #expect(stoppedProcess.id == initialProcess.id)
        #expect(stoppedProcess.status == .disconnected)
        #expect(stopped.first?.event?.kind == .note)
    }

    @Test("A new Anchor session receives a fresh application snapshot")
    func sessionChangeResetsObservationState() async {
        let reducer = MacWorkspaceObservationReducer(sourceID: UUID())
        let snapshot = [application("com.example.Editor", name: "Editor", pid: 101, active: true)]
        let firstSessionEvents = await reducer.reconcile(
            snapshot,
            sessionID: UUID(),
            observedAt: .now
        )
        let secondSessionEvents = await reducer.reconcile(
            snapshot,
            sessionID: UUID(),
            observedAt: .now
        )

        #expect(firstSessionEvents.count == 1)
        #expect(secondSessionEvents.count == 1)
        #expect(firstSessionEvents.first?.process.id != secondSessionEvents.first?.process.id)
        #expect(secondSessionEvents.first?.event == nil)
    }

    private func application(
        _ identifier: String,
        name: String,
        pid: Int32,
        active: Bool
    ) -> MacApplicationSnapshot {
        MacApplicationSnapshot(
            identifier: identifier,
            localizedName: name,
            processIdentifier: pid,
            isActive: active
        )
    }

    private func oneSignal() -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.yield(())
            continuation.finish()
        }
    }

    private func collect(
        _ stream: AsyncThrowingStream<ExternalProcessEvent, Error>
    ) async throws -> [ExternalProcessEvent] {
        var events: [ExternalProcessEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }
}
#endif
