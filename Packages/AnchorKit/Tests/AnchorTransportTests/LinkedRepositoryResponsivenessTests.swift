import Foundation
import Testing
import AnchorCore
@testable import AnchorTransport

@Suite("Local commit responsiveness")
struct LinkedRepositoryResponsivenessTests {
    @Test("Slow delivery never holds local edits; new events drain after the stalled ACK")
    func slowDeliveryDoesNotBlockSave() async throws {
        let url = URL.temporaryDirectory.appending(path: "anchor-slow-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let base = LocalSessionRepository(storageURL: url)
        let transport = SuspendedTransport()
        let linked = LinkedSessionRepository(base: base, transport: transport)
        let completed = CompletionFlag()
        let save = Task {
            try await linked.send(.createSession(goal: AnchorGoal(title: "Real work", completionCriteria: "Saved"), processes: []))
            for _ in 0..<100 {
                if await transport.started { break }
                try await Task.sleep(for: .milliseconds(1))
            }
            try await linked.send(.addNote("Saved while replication is in flight"))
            await completed.finish()
        }
        // Always release the gate before assertions/throws, including on a regression.
        for _ in 0..<100 {
            if await completed.finished { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let returnedBeforeACK = await completed.finished
        let queuedBeforeACK = await base.pendingEvents().count
        await transport.release()
        try await save.value
        #expect(returnedBeforeACK)
        #expect(queuedBeforeACK == 2)
        await linked.flushPendingEvents()
        #expect(await base.pendingEvents().isEmpty)
        #expect(await transport.delivered.count == 2)
        let restarted = LocalSessionRepository(storageURL: url)
        #expect(await restarted.currentProjection().session?.notes.first?.text == "Saved while replication is in flight")
    }
}

private actor CompletionFlag {
    var finished = false
    func finish() { finished = true }
}

private actor SuspendedTransport: AnchorEventTransport {
    private var gate: CheckedContinuation<Void, Never>?
    private var released = false
    var delivered: [UUID] = []
    var started = false
    func send(_ event: EventEnvelope) async throws {
        started = true
        if !released {
            await withCheckedContinuation { gate = $0 }
        }
        delivered.append(event.id)
    }
    func release() {
        released = true
        gate?.resume()
        gate = nil
    }
}
