#if os(macOS)
import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("Switching or viewing anchored tasks on either device leaves the edge still")
func focusChangesDoNotMoveTheAnchor() throws {
    let mac = UUID(), phone = UUID()
    let first = activeSession("First"), second = activeSession("Second")
    var projection = SessionProjection(session: second, additionalSessions: [first])
    let gate = AnchorPhoneAnchorState()
    gate.receive(try operation(.hostSession(first), from: phone), projection: projection, localSourceID: mac)
    gate.receive(try operation(.hostSession(second), from: phone), projection: projection, localSourceID: mac)
    var cues: [AnchorEdgeSoundCue] = []
    let edge = AnchorEdgePresentationModel(defaults: isolatedDefaults()) { cues.append($0) }
    edge.synchronize(anchoredSessionIDs: gate.anchoredSessionIDs(in: projection), isLoading: false, reduceMotion: true)
    #expect(edge.phase == .deployed)
    cues.removeAll()

    // A task tile clicked on the Mac is a local selection.
    try projection.selectHostedSession(first.id)
    gate.receive(try operation(.selectSession(first.id, at: .now), from: mac), projection: projection, localSourceID: mac)
    edge.synchronize(anchoredSessionIDs: gate.anchoredSessionIDs(in: projection), isLoading: false, reduceMotion: false)
    // Tapping a task card on the phone selects it remotely.
    try projection.selectHostedSession(second.id)
    gate.receive(try operation(.selectSession(second.id, at: .now), from: phone), projection: projection, localSourceID: mac)
    edge.synchronize(anchoredSessionIDs: gate.anchoredSessionIDs(in: projection), isLoading: false, reduceMotion: false)

    #expect(edge.phase == .deployed)
    #expect(edge.anchorTravel == 1)
    #expect(edge.splashTrigger == 0)
    #expect(cues.isEmpty)
}

@MainActor
@Test("Another anchored task tugs the settled rope instead of throwing again")
func addedAnchorTugsRope() async throws {
    var cues: [AnchorEdgeSoundCue] = []
    let edge = AnchorEdgePresentationModel(defaults: isolatedDefaults()) { cues.append($0) }
    let first = UUID(), second = UUID()
    edge.synchronize(anchoredSessionIDs: [first], isLoading: false, reduceMotion: true)
    cues.removeAll()
    let splashes = edge.splashTrigger

    edge.synchronize(anchoredSessionIDs: [first, second], isLoading: false, reduceMotion: false)
    #expect(edge.phase == .deployed)
    #expect(edge.anchorTravel == 1)
    #expect(edge.splashTrigger == splashes + 1)
    #expect(edge.showsSplashParticles)
    #expect(cues == [.anchorJoined])
    try await Task.sleep(for: .milliseconds(60))
    #expect(edge.anchorSway != 0)

    try await Task.sleep(for: .milliseconds(700))
    #expect(edge.showsSplashParticles == false)
}

@MainActor
@Test("Finishing one of several tasks keeps the anchor down; the last one lifts it")
func finishingAnchoredTasks() throws {
    let mac = UUID(), phone = UUID()
    let first = activeSession("First"), second = activeSession("Second")
    var projection = SessionProjection(session: second, additionalSessions: [first])
    let gate = AnchorPhoneAnchorState()
    gate.receive(try operation(.hostSession(first), from: phone), projection: projection, localSourceID: mac)
    gate.receive(try operation(.hostSession(second), from: phone), projection: projection, localSourceID: mac)
    var cues: [AnchorEdgeSoundCue] = []
    let edge = AnchorEdgePresentationModel(defaults: isolatedDefaults()) { cues.append($0) }
    edge.synchronize(anchoredSessionIDs: gate.anchoredSessionIDs(in: projection), isLoading: false, reduceMotion: true)
    cues.removeAll()

    // Completing the foreground task leaves no foreground session, but other work stays anchored.
    projection = try SessionReducer.reduce(projection, command: .completeSession, now: .now)
    #expect(projection.session == nil)
    edge.synchronize(anchoredSessionIDs: gate.anchoredSessionIDs(in: projection), isLoading: false, reduceMotion: true)
    #expect(edge.phase == .deployed)
    #expect(cues == [.anchorReleased])

    try projection.selectHostedSession(first.id)
    projection = try SessionReducer.reduce(projection, command: .completeSession, now: .now)
    edge.synchronize(anchoredSessionIDs: gate.anchoredSessionIDs(in: projection), isLoading: false, reduceMotion: true)
    #expect(edge.phase == .harbored)
    #expect(cues == [.anchorReleased, .anchorRetrieved])
}

private func activeSession(_ title: String) -> AnchorSession {
    AnchorSession(goal: AnchorGoal(title: title, completionCriteria: "Done"), status: .active)
}

private func operation(_ operation: SessionOperation, from sourceID: UUID) throws -> EventEnvelope {
    EventEnvelope(sessionID: try #require(operation.sessionID), sourceID: sourceID, sequence: 1,
                  type: EventEnvelope.operationType,
                  payload: try JSONEncoder.anchor.encode(operation))
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "AnchorEdgeMultipleAnchorTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
#endif
