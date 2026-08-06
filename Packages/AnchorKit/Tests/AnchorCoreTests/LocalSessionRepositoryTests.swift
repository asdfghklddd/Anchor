import Foundation
import Testing
@testable import AnchorCore

@Suite("Local session repository")
struct LocalSessionRepositoryTests {
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
