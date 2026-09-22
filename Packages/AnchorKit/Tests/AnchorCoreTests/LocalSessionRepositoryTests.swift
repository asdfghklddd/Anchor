import Foundation
import Testing
@testable import AnchorCore

@Suite("Local session repository")
struct LocalSessionRepositoryTests {
    @Test("A new task replaces a completed foreground session after restart")
    func completedSessionIsReplacedDurably() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-new-task-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storage) }
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "First", completionCriteria: "Done"),
                processes: []
            )
        )
        let firstID = try #require(await repository.currentProjection().session?.id)
        try await repository.send(.completeSession)
        #expect(await repository.currentProjection().session == nil)
        #expect(await repository.currentProjection().archivedSessions.map(\.id) == [firstID])
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Second", completionCriteria: "Done again"),
                processes: []
            )
        )
        let secondID = try #require(await repository.currentProjection().session?.id)
        #expect(secondID != firstID)
        #expect(await repository.currentProjection().archivedSessions.map(\.id) == [firstID])

        let restored = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        #expect(await restored.currentProjection().session?.id == secondID)
        #expect(await restored.currentProjection().session?.goal.title == "Second")
        #expect(await restored.currentProjection().archivedSessions.map(\.id) == [firstID])
    }

    @Test("User-created empty workspace state survives relaunch")
    func persistsUserSession() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-local-\(UUID().uuidString).json")
        let first = LocalSessionRepository(storageURL: storage)
        let goal = AnchorGoal(
            title: "Ship the first workspace",
            completionCriteria: "The main workspace is ready"
        )
        let process = AnchorProcess(
            sourceName: "Manual task",
            sourceSymbol: "M",
            sourceTone: "cyan",
            title: "Build the iPhone experience",
            status: .queued
        )

        try await first.send(.createSession(goal: goal, processes: [process]))

        let second = LocalSessionRepository(storageURL: storage)
        #expect(await second.currentProjection().session?.goal.title == goal.title)
        #expect(await second.currentProjection().session?.processes.count == 1)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("A fresh production repository starts as an empty workspace")
    func startsEmpty() async {
        let storage = URL.temporaryDirectory.appending(path: "anchor-local-\(UUID().uuidString).json")
        let repository = LocalSessionRepository(storageURL: storage)
        let projection = await repository.currentProjection()

        #expect(projection.session == nil)
        #expect(projection.errorMessage == nil)
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("The event outbox survives relaunch and advances a stable source sequence")
    func outboxSurvivesRelaunch() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-events-\(UUID().uuidString).json")
        let sourceID = UUID()
        let first = LocalSessionRepository(storageURL: storage, sourceID: sourceID)
        try await first.send(
            .createSession(
                goal: AnchorGoal(title: "Event goal", completionCriteria: "Done"),
                processes: []
            )
        )

        let firstEvent = try #require(await first.pendingEvents().first)
        #expect(firstEvent.sourceID == sourceID)
        #expect(firstEvent.sequence == 1)
        try await first.markDelivered(firstEvent.id)
        #expect(await first.pendingEvents().isEmpty)

        let second = LocalSessionRepository(storageURL: storage, sourceID: sourceID)
        try await second.send(.addNote("A durable note"))
        let secondEvent = try #require(await second.pendingEvents().first)
        #expect(secondEvent.sequence == 2)
        #expect(await second.currentProjection().session?.notes.first?.text == "A durable note")
        try? FileManager.default.removeItem(at: storage)
    }

    @Test("Acknowledged events remain available for peer reconciliation after relaunch")
    func retainedHistorySurvivesAcknowledgementAndRelaunch() async throws {
        let storage = URL.temporaryDirectory.appending(
            path: "anchor-retained-events-\(UUID().uuidString).json"
        )
        defer { try? FileManager.default.removeItem(at: storage) }
        let sourceID = UUID()
        let first = LocalSessionRepository(storageURL: storage, sourceID: sourceID)
        try await first.send(
            .createSession(
                goal: AnchorGoal(title: "Reconcile", completionCriteria: "Recovered"),
                processes: []
            )
        )
        let event = try #require(await first.pendingEvents().first)

        try await first.markDelivered(event.id)
        #expect(await first.pendingEvents().isEmpty)
        #expect(await first.retainedEvents() == [event])

        let restored = LocalSessionRepository(storageURL: storage, sourceID: sourceID)
        #expect(await restored.pendingEvents().isEmpty)
        #expect(await restored.retainedEvents() == [event])
    }

    @Test("A remote operation is applied once and duplicate delivery is harmless")
    func remoteOperationIsIdempotent() async throws {
        let senderStorage = URL.temporaryDirectory.appending(path: "anchor-sender-\(UUID().uuidString).json")
        let receiverStorage = URL.temporaryDirectory.appending(path: "anchor-receiver-\(UUID().uuidString).json")
        let sender = LocalSessionRepository(storageURL: senderStorage, sourceID: UUID())
        let receiver = LocalSessionRepository(storageURL: receiverStorage, sourceID: UUID())
        try await sender.send(
            .createSession(
                goal: AnchorGoal(title: "Shared goal", completionCriteria: "Done"),
                processes: []
            )
        )
        let event = try #require(await sender.pendingEvents().first)

        try await receiver.applyRemote(event)
        try await receiver.applyRemote(event)

        #expect(await receiver.currentProjection().session?.id == event.sessionID)
        #expect(await receiver.currentProjection().session?.processedEventIDs.isEmpty == true)
        #expect(await receiver.pendingEvents().isEmpty)
        try? FileManager.default.removeItem(at: senderStorage)
        try? FileManager.default.removeItem(at: receiverStorage)
    }

    @Test("A late event is consumed without re-entering an archived task")
    func archivedSessionConsumesLateRemoteEvents() async throws {
        let storage = URL.temporaryDirectory.appending(path: "anchor-archived-boundary-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: storage) }
        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        try await repository.send(
            .createSession(
                goal: AnchorGoal(title: "Finished", completionCriteria: "Preserved"),
                processes: []
            )
        )
        let sessionID = try #require(await repository.currentProjection().session?.id)
        try await repository.send(.completeSession)
        let lateNote = AnchorNote(
            sessionID: sessionID,
            text: "Must not re-enter current work",
            createdAt: .now
        )
        let lateEnvelope = EventEnvelope(
            sessionID: sessionID,
            sourceID: UUID(),
            sequence: 1,
            type: EventEnvelope.operationType,
            payload: try JSONEncoder.anchor.encode(SessionOperation.addNote(lateNote))
        )

        let before = await repository.currentProjection()
        try await repository.applyRemote(lateEnvelope)
        try await repository.applyRemote(lateEnvelope)
        #expect(await repository.currentProjection() == before)
        #expect(await repository.currentProjection().session == nil)
        #expect(await repository.currentProjection().archivedSessions.first?.notes.isEmpty == true)
    }

    @Test("An unfinished archive uses the v2 envelope and converges on both peers")
    func unfinishedArchiveReplicatesDurably() async throws {
        let senderStorage = URL.temporaryDirectory.appending(path: "anchor-archive-sender-\(UUID().uuidString).json")
        let receiverStorage = URL.temporaryDirectory.appending(path: "anchor-archive-receiver-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: senderStorage)
            try? FileManager.default.removeItem(at: receiverStorage)
        }
        let sender = LocalSessionRepository(storageURL: senderStorage, sourceID: UUID())
        let receiver = LocalSessionRepository(storageURL: receiverStorage, sourceID: UUID())

        try await sender.send(
            .createSession(
                goal: AnchorGoal(title: "Unfinished", completionCriteria: "Preserve honestly"),
                processes: []
            )
        )
        let createEvent = try #require(await sender.pendingEvents().first)
        try await receiver.applyRemote(createEvent)
        try await sender.markDelivered(createEvent.id)

        try await sender.send(.archiveSession)
        let archiveEvent = try #require(await sender.pendingEvents().first)
        #expect(archiveEvent.schemaVersion == 2)
        try await receiver.applyRemote(archiveEvent)

        #expect(await sender.currentProjection().session == nil)
        #expect(await receiver.currentProjection().session == nil)
        #expect(await sender.currentProjection().archivedSessions.first?.status == .archived)
        #expect(await receiver.currentProjection().archivedSessions.first?.status == .archived)
        #expect(await receiver.currentProjection().archivedSessions.first?.completedAt == nil)
        #expect(await receiver.currentProjection().archivedSessions.first?.archivedAt != nil)

        let restored = LocalSessionRepository(storageURL: senderStorage, sourceID: UUID())
        #expect(await restored.currentProjection().archivedSessions.first?.status == .archived)
    }

    @Test("A v1 projection is migrated without losing the local session")
    func migratesLegacyProjection() async throws {
        struct LegacyState: Codable {
            let schemaVersion: Int
            let projection: SessionProjection
        }

        let storage = URL.temporaryDirectory.appending(path: "anchor-legacy-\(UUID().uuidString).json")
        let session = AnchorSession(
            goal: AnchorGoal(title: "Legacy goal", completionCriteria: "Done")
        )
        let legacy = LegacyState(
            schemaVersion: 1,
            projection: SessionProjection(session: session)
        )
        try JSONEncoder().encode(legacy).write(to: storage, options: .atomic)

        let repository = LocalSessionRepository(storageURL: storage, sourceID: UUID())
        #expect(await repository.currentProjection().session?.goal.title == "Legacy goal")
        try await repository.send(.addNote("Migrated note"))
        #expect(await repository.pendingEvents().count == 1)
        #expect(await repository.currentProjection().session?.notes.first?.text == "Migrated note")
        try? FileManager.default.removeItem(at: storage)
    }
}
