import Foundation
import Testing
@testable import AnchorCore

@Suite("Starting over")
struct DataResetTests {
    private struct Pair {
        let phoneURL = URL.temporaryDirectory.appending(path: "reset-phone-\(UUID()).json")
        let macURL = URL.temporaryDirectory.appending(path: "reset-mac-\(UUID()).json")
        let phoneID = UUID()
        let macID = UUID()
        let phone: LocalSessionRepository
        let mac: LocalSessionRepository

        init() {
            phone = LocalSessionRepository(storageURL: phoneURL, sourceID: phoneID)
            mac = LocalSessionRepository(storageURL: macURL, sourceID: macID)
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: phoneURL)
            try? FileManager.default.removeItem(at: macURL)
        }
    }

    /// Delivers the sender's outbox in the order the link sends it.
    private func deliver(from sender: LocalSessionRepository, to receiver: LocalSessionRepository) async throws {
        for event in await sender.pendingEvents() {
            try await receiver.applyRemote(event)
            try await sender.markDelivered(event.id)
        }
    }

    /// What a reconnect replays: every retained event, delivered or not.
    private func replayHistory(from sender: LocalSessionRepository, to receiver: LocalSessionRepository) async throws {
        for event in await sender.retainedEvents() {
            try await receiver.applyRemote(event)
        }
    }

    private func conversation(in sessionID: UUID, title: String = "Main", at date: Date) -> ProcessObservation {
        let process = AnchorProcess(
            id: StableProcessIdentity.id(namespace: "test.conversation", sessionID: sessionID, externalID: title),
            sessionID: sessionID, sourceID: UUID(), sourceName: "Codex", sourceSymbol: "C",
            sourceTone: "cyan", title: title, status: .running, updatedAt: date
        )
        return ProcessObservation(process: process, deduplicationKey: "test.\(sessionID).\(title)")
    }

    @Test func clearingTasksOnThePhoneClearsTheMacAndStaysCleared() async throws {
        let pair = Pair()
        defer { pair.cleanUp() }
        let essay = AnchorSession(goal: AnchorGoal(title: "Essay", completionCriteria: "Done"))
        let done = AnchorSession(goal: AnchorGoal(title: "Old", completionCriteria: "Done"))
        try await pair.phone.send(.hostSession(done))
        try await pair.phone.send(.forSession(done.id, .completeSession))
        try await pair.phone.send(.hostSession(essay))
        try await deliver(from: pair.phone, to: pair.mac)
        try await pair.mac.send(.observeProcess(conversation(in: essay.id, at: .now)))
        try await deliver(from: pair.mac, to: pair.phone)

        try await pair.phone.forgetTasks([essay.id])
        #expect(await pair.phone.currentProjection().hostedSessions.isEmpty)
        #expect(await pair.phone.currentProjection().archivedSessions.map(\.id) == [done.id])

        // The Mac replays its history before it hears of the reset: nothing comes back.
        try await replayHistory(from: pair.mac, to: pair.phone)
        #expect(await pair.phone.currentProjection().hostedSessions.isEmpty)

        try await deliver(from: pair.phone, to: pair.mac)
        #expect(await pair.mac.currentProjection().hostedSessions.isEmpty)
        #expect(await pair.mac.currentProjection().forgottenTaskIDs == [essay.id])
        #expect(await pair.mac.currentProjection().archivedSessions.map(\.id) == [done.id])

        // A new task after the reset still reaches the Mac.
        let next = AnchorSession(goal: AnchorGoal(title: "Next", completionCriteria: "Done"))
        try await pair.phone.send(.hostSession(next))
        try await deliver(from: pair.phone, to: pair.mac)
        #expect(await pair.mac.currentProjection().hostedSessions.map(\.id) == [next.id])

        // Both devices remember after a restart.
        let restarted = LocalSessionRepository(storageURL: pair.phoneURL, sourceID: pair.phoneID)
        #expect(await restarted.currentProjection().hostedSessions.map(\.id) == [next.id])
        try await replayHistory(from: pair.mac, to: restarted)
        #expect(await restarted.currentProjection().hostedSessions.map(\.id) == [next.id])
    }

    @Test func clearingEverythingRemovesHistoryOnBothDevices() async throws {
        let pair = Pair()
        defer { pair.cleanUp() }
        let done = AnchorSession(goal: AnchorGoal(title: "Old", completionCriteria: "Done"))
        try await pair.phone.send(.hostSession(done))
        try await pair.phone.send(.forSession(done.id, .completeSession))
        try await deliver(from: pair.phone, to: pair.mac)
        #expect(await pair.mac.currentProjection().archivedSessions.count == 1)

        try await pair.phone.forgetTasks([done.id])
        try await deliver(from: pair.phone, to: pair.mac)
        #expect(await pair.phone.currentProjection().archivedSessions.isEmpty)
        #expect(await pair.mac.currentProjection().archivedSessions.isEmpty)
        #expect(await pair.phone.retainedEvents().allSatisfy(\.isDataReset))
    }

    @Test func clearingConversationsOnTheMacKeepsTasksAndReadsAgain() async throws {
        let pair = Pair()
        defer { pair.cleanUp() }
        let essay = AnchorSession(goal: AnchorGoal(title: "Essay", completionCriteria: "Done"),
                                  startedAt: .now.addingTimeInterval(-3600))
        try await pair.phone.send(.hostSession(essay))
        try await pair.phone.send(.forSession(essay.id, .addNote("Mine")))
        try await deliver(from: pair.phone, to: pair.mac)
        let readAt = Date.now.addingTimeInterval(-600)
        try await pair.mac.send(.observeProcess(conversation(in: essay.id, title: "Main", at: readAt)))
        try await pair.mac.send(.observeProcess(conversation(in: essay.id, title: "Wrong", at: readAt)))
        try await deliver(from: pair.mac, to: pair.phone)
        #expect(await pair.phone.currentProjection().session?.processes.count == 2)

        try await pair.mac.clearConversations()
        #expect(await pair.mac.currentProjection().session?.processes.isEmpty == true)
        // Reading the folders again yields older timestamps than the reset itself.
        try await pair.mac.send(.observeProcess(conversation(in: essay.id, title: "Main", at: readAt)))
        #expect(await pair.mac.pendingEvents().first?.isDataReset == true)

        // The phone replays its old copy first; the Mac drops it.
        try await replayHistory(from: pair.phone, to: pair.mac)
        #expect(await pair.mac.currentProjection().session?.processes.map(\.title) == ["Main"])

        try await deliver(from: pair.mac, to: pair.phone)
        let phone = await pair.phone.currentProjection()
        #expect(phone.session?.id == essay.id)
        #expect(phone.session?.notes.map(\.text) == ["Mine"])
        #expect(phone.session?.processes.map(\.title) == ["Main"])
    }
}
