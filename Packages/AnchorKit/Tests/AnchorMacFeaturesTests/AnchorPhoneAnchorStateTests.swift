#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("Cached or Mac-created work cannot deploy the phone-controlled anchor")
func cachedWorkWaitsForPhoneAnchor() throws {
    let localID = UUID()
    let session = AnchorSession(goal: AnchorGoal(title: "Focus", completionCriteria: "Done"))
    let projection = SessionProjection(session: session)
    let gate = AnchorPhoneAnchorState()
    #expect(gate.activeSessionID(in: projection) == nil)
    let envelope = try phoneCreate(session, sourceID: localID)
    gate.receive(envelope, projection: projection, localSourceID: localID)
    #expect(gate.activeSessionID(in: projection) == nil)
}

@MainActor
@Test("A durably applied phone anchor deploys once and completion retrieves it")
func phoneAnchorControlsEdgePresentation() async throws {
    let localID = UUID()
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = LocalSessionRepository(storageURL: root.appending(path: "state.json"), sourceID: localID)
    let session = AnchorSession(goal: AnchorGoal(title: "Phone anchor", completionCriteria: "Done"))
    let envelope = try phoneCreate(session, sourceID: UUID())
    let gate = AnchorPhoneAnchorState()
    let model = AnchorEdgePresentationModel(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    model.synchronize(activeSessionID: nil, isLoading: false, reduceMotion: true)
    #expect(model.phase == .harbored)

    try await repository.applyRemote(envelope)
    let projection = await repository.currentProjection()
    gate.receive(envelope, projection: projection, localSourceID: localID)
    model.synchronize(activeSessionID: gate.activeSessionID(in: projection), isLoading: false, reduceMotion: false)
    #expect(model.phase == .deploying)

    // An identical retransmission must not reset the in-flight throw.
    try await Task.sleep(for: .milliseconds(80))
    let progress = model.throwProgress
    try await repository.applyRemote(envelope)
    gate.receive(envelope, projection: projection, localSourceID: localID)
    model.synchronize(activeSessionID: gate.activeSessionID(in: projection), isLoading: false, reduceMotion: false)
    #expect(model.throwProgress >= progress)
    #expect(model.throwProgress > 0)

    let restartedGate = AnchorPhoneAnchorState()
    #expect(restartedGate.activeSessionID(in: projection) == nil)
    try await repository.send(.completeSession)
    model.synchronize(activeSessionID: gate.activeSessionID(in: await repository.currentProjection()),
                      isLoading: false, reduceMotion: true)
    #expect(model.phase == .harbored)
    #expect(model.showsSplashParticles == false)
}

@MainActor
@Test("Stale phone creates cannot confirm a different current session")
func stalePhoneAnchorIsIgnored() throws {
    let old = AnchorSession(goal: AnchorGoal(title: "Old", completionCriteria: "Done"))
    let current = AnchorSession(goal: AnchorGoal(title: "Current", completionCriteria: "Done"))
    let gate = AnchorPhoneAnchorState()
    gate.receive(try phoneCreate(old, sourceID: UUID()), projection: SessionProjection(session: current), localSourceID: UUID())
    #expect(gate.activeSessionID(in: SessionProjection(session: current)) == nil)
}

private func phoneCreate(_ session: AnchorSession, sourceID: UUID) throws -> EventEnvelope {
    EventEnvelope(sessionID: session.id, sourceID: sourceID, sequence: 1,
                  type: EventEnvelope.operationType,
                  payload: try JSONEncoder.anchor.encode(SessionOperation.createSession(session)))
}
#endif
