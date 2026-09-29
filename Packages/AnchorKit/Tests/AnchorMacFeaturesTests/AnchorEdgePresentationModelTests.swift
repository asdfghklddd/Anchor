#if os(macOS)
import Foundation
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test("A new active task deploys the edge anchor")
func newActiveTaskDeploysAnchor() {
    let defaults = isolatedDefaults()
    let model = AnchorEdgePresentationModel(defaults: defaults)
    let sessionID = UUID()

    model.synchronize(
        activeSessionID: sessionID,
        isLoading: false,
        reduceMotion: true
    )

    #expect(model.phase == .deployed)
    #expect(model.anchorTravel == 1)
    #expect(model.showsSplashParticles == false)
}

@MainActor
@Test("A completed task returns the anchor to the screen edge")
func completedTaskRetrievesAnchor() {
    let defaults = isolatedDefaults()
    let model = AnchorEdgePresentationModel(defaults: defaults)
    let sessionID = UUID()

    model.synchronize(
        activeSessionID: sessionID,
        isLoading: false,
        reduceMotion: true
    )
    model.synchronize(
        activeSessionID: nil,
        isLoading: false,
        reduceMotion: true
    )

    #expect(model.phase == .harbored)
    #expect(model.anchorTravel == 0)
    #expect(defaults.string(forKey: "anchor.mac.edge.deployed-session-id") == nil)
}

@MainActor
@Test("A confirmed phone anchor animates even if an old presentation marker exists")
func confirmedPhoneAnchorIgnoresOldPresentationMarker() {
    let defaults = isolatedDefaults()
    let sessionID = UUID()
    var cues: [AnchorEdgeSoundCue] = []
    defaults.set(sessionID.uuidString, forKey: "anchor.mac.edge.deployed-session-id")
    let model = AnchorEdgePresentationModel(defaults: defaults) { cues.append($0) }

    model.synchronize(
        activeSessionID: sessionID,
        isLoading: false,
        reduceMotion: false
    )

    #expect(model.phase == .deploying)
    #expect(model.anchorTravel == 0)
    #expect(model.showsSplashParticles == false)
    #expect(cues.isEmpty)
}

@MainActor
@Test("The animated drop lands before its short splash retires")
func animatedDropCompletesSplashSequence() async throws {
    let defaults = isolatedDefaults()
    var cues: [AnchorEdgeSoundCue] = []
    let model = AnchorEdgePresentationModel(defaults: defaults) { cues.append($0) }

    model.synchronize(
        activeSessionID: UUID(),
        isLoading: false,
        reduceMotion: false
    )
    #expect(model.phase == .deploying)

    try await Task.sleep(for: .milliseconds(440))
    #expect(model.phase == .deploying)
    #expect(model.showsSplashParticles == false)
    #expect(cues.isEmpty)

    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(3))
    while model.phase == .deploying, clock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(model.phase == .deployed)
    #expect(model.showsSplashParticles)
    #expect(model.splashTrigger == 1)
    #expect(model.splashStartedAt != nil)
    #expect(model.waterImpactIntensity > 0.9)
    #expect(cues == [.anchorLanded])

    try await Task.sleep(for: .milliseconds(700))
    #expect(model.showsSplashParticles == false)
}

@MainActor
@Test("The animated retrieval lifts the anchor back into the waiting boat")
func animatedRetrievalReturnsToHarbor() async throws {
    let defaults = isolatedDefaults()
    var cues: [AnchorEdgeSoundCue] = []
    let model = AnchorEdgePresentationModel(defaults: defaults) { cues.append($0) }

    model.synchronize(
        activeSessionID: UUID(),
        isLoading: false,
        reduceMotion: true
    )
    cues.removeAll()
    model.synchronize(
        activeSessionID: nil,
        isLoading: false,
        reduceMotion: false
    )
    #expect(model.phase == .retrieving)

    try await Task.sleep(for: .milliseconds(440))
    #expect(model.phase == .harbored)
    #expect(model.anchorTravel == 0)
    #expect(cues == [.anchorRetrieved])
}

@MainActor
@Test("The idle boat rests at the edge and immediately returns for interaction")
func idleBoatRestingBehavior() async throws {
    let model = AnchorEdgePresentationModel(
        defaults: isolatedDefaults(),
        tuckDelay: .milliseconds(20)
    )

    model.synchronize(
        activeSessionID: nil,
        isLoading: false,
        reduceMotion: false
    )
    try await Task.sleep(for: .milliseconds(40))
    #expect(model.isTucked)

    model.pointerPresenceChanged(true)
    #expect(model.isTucked == false)

    model.pointerPresenceChanged(false)
    try await Task.sleep(for: .milliseconds(40))
    #expect(model.isTucked)
}

@MainActor
@Test("Water impact is emitted during descent at the screen edge")
func waterImpactOccursDuringDescent() async throws {
    var impactTravel: CGFloat?
    var impactPhase: AnchorEdgePhase?
    var impactCount = 0
    weak var observedModel: AnchorEdgePresentationModel?
    let model = AnchorEdgePresentationModel(defaults: isolatedDefaults()) { cue in
        guard cue == .anchorLanded else { return }
        impactCount += 1
        impactTravel = observedModel?.anchorTravel
        impactPhase = observedModel?.phase
    }
    observedModel = model
    model.updateEffectsHeight(480)
    model.synchronize(activeSessionID: UUID(), isLoading: false, reduceMotion: false)

    // Inspect the state captured by the impact event, not a guessed animation frame.
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(3))
    while model.phase == .deploying, clock.now < deadline {
        try await Task.sleep(for: .milliseconds(10))
    }
    let travel = try #require(impactTravel)
    #expect(impactPhase == .deploying)
    #expect(travel >= model.waterImpactTravel)
    #expect(impactCount == 1)
    #expect(model.phase == .deployed)
}

@MainActor
@Test("Retrieving before water contact cancels the pending splash")
func interruptedDropDoesNotSplash() async throws {
    var cues: [AnchorEdgeSoundCue] = []
    let model = AnchorEdgePresentationModel(defaults: isolatedDefaults()) { cues.append($0) }
    model.synchronize(activeSessionID: UUID(), isLoading: false, reduceMotion: false)
    model.synchronize(activeSessionID: nil, isLoading: false, reduceMotion: false)

    // Wait beyond the original drop so a stale deployment task would be detected.
    try await Task.sleep(for: .milliseconds(2_350))
    #expect(model.phase == .harbored)
    #expect(model.splashTrigger == 0)
    #expect(model.showsSplashParticles == false)
    #expect(cues == [.anchorRetrieved])
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "AnchorEdgePresentationModelTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
#endif
