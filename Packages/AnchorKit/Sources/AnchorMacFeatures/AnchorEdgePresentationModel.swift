#if os(macOS)
import AnchorDesign
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
public final class AnchorEdgePresentationModel {
    public private(set) var phase = AnchorEdgePhase.harbored
    public private(set) var anchorTravel: CGFloat = 0
    public private(set) var throwProgress: CGFloat = 0
    public private(set) var waterVisibility: CGFloat = 0
    public private(set) var splashTrigger = 0
    public private(set) var showsSplashParticles = false
    public private(set) var isTucked = false
    public private(set) var anchorSway: CGFloat = 0
    public private(set) var ropeBend: CGFloat = 0
    private(set) var waterImpactTravel: CGFloat
    @ObservationIgnored private var effectsMetrics = AnchorEdgeEffectsMetrics(height: 700)
    private(set) var waterImpactIntensity: CGFloat = 0
    private(set) var waterImpactXOffset: CGFloat = 0
    private(set) var splashStartedAt: Date?
    private var swayVelocity: Double = 0
    private var ropeVelocity: Double = 0
    private var swayTask: Task<Void, Never>?

    private let tuckDelay: Duration
    private let playSound: @MainActor (AnchorEdgeSoundCue) -> Void
    private var activeSessionID: UUID?
    private var hasSynchronizedInitialProjection = false
    private var reduceMotion = false
    private var isPointerInside = false
    private var isKeyboardFocused = false
    private var transitionTask: Task<Void, Never>?
    private var tuckTask: Task<Void, Never>?

    private static let deployedSessionKey = "anchor.mac.edge.deployed-session-id"

    var throwOffset: CGSize {
        guard phase == .deploying else { return .zero }
        return CGSize(
            width: -18 * sin(.pi * throwProgress / 2) * pow(1 - anchorTravel, 2),
            height: -12 * sin(.pi * throwProgress)
        )
    }

    public init(
        defaults: UserDefaults = .standard,
        tuckDelay: Duration = .seconds(5),
        playSound: @escaping @MainActor (AnchorEdgeSoundCue) -> Void = { _ in }
    ) {
        // Retire the old UI cache; persisted work is not proof of a phone anchor.
        defaults.removeObject(forKey: Self.deployedSessionKey)
        self.tuckDelay = tuckDelay
        self.playSound = playSound
        waterImpactTravel = AnchorEdgeEffectsMetrics(height: 700).waterImpactTravel
    }

    public func synchronize(
        activeSessionID incomingSessionID: UUID?,
        isLoading: Bool,
        reduceMotion: Bool
    ) {
        self.reduceMotion = reduceMotion
        guard !isLoading else { return }

        if !hasSynchronizedInitialProjection {
            synchronizeInitialState(
                activeSessionID: incomingSessionID,
                reduceMotion: reduceMotion
            )
            return
        }

        guard incomingSessionID != activeSessionID else { return }

        if let incomingSessionID {
            activeSessionID = incomingSessionID
            beginDeployment(reduceMotion: reduceMotion)
        } else if activeSessionID != nil {
            activeSessionID = nil
            beginRetrieval(reduceMotion: reduceMotion)
        }
    }

    public func pointerPresenceChanged(_ isInside: Bool) {
        isPointerInside = isInside
        if isInside {
            revealControl()
        } else {
            scheduleTuck()
        }
    }

    public func keyboardFocusChanged(_ isFocused: Bool) {
        isKeyboardFocused = isFocused
        if isFocused {
            revealControl()
        } else {
            scheduleTuck()
        }
    }

    public func controlActivated() {
        revealControl()
        scheduleTuck()
    }

    func updateEffectsHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }
        effectsMetrics = AnchorEdgeEffectsMetrics(height: height)
        waterImpactTravel = effectsMetrics.waterImpactTravel
    }

    public func scheduleTuck() {
        tuckTask?.cancel()
        guard phase == .harbored, !hasActiveInteraction else { return }
        tuckTask = Task { [weak self, tuckDelay] in
            try? await Task.sleep(for: tuckDelay)
            guard !Task.isCancelled,
                  let self,
                  self.phase == .harbored,
                  !self.hasActiveInteraction else {
                return
            }
            withAnimation(self.reduceMotion ? nil : AnchorMotion.edgeRest) {
                self.isTucked = true
            }
        }
    }

    private func synchronizeInitialState(
        activeSessionID incomingSessionID: UUID?,
        reduceMotion: Bool
    ) {
        hasSynchronizedInitialProjection = true
        activeSessionID = incomingSessionID

        guard incomingSessionID != nil else {
            resetToHarboredState()
            scheduleTuck()
            return
        }

        // The caller has confirmed this session from a phone event, never from disk alone.
        beginDeployment(reduceMotion: reduceMotion)
    }

    private func beginDeployment(reduceMotion: Bool) {
        cancelPendingWork()
        startSway(reduceMotion: reduceMotion, impulse: 70)
        isTucked = false
        showsSplashParticles = false
        splashStartedAt = nil

        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.20)) {
                phase = .deployed
                anchorTravel = 1
                waterVisibility = 1
            }
            playSound(.anchorLanded)
            return
        }

        phase = .deploying
        anchorTravel = 0
        throwProgress = 0
        waterVisibility = 0
        transitionTask = Task { [weak self] in
            let clock = ContinuousClock()
            let startedAt = clock.now
            let duration = Self.seconds(in: AnchorMotion.anchorDropDuration)
            var didImpactWater = false

            while true {
                do { try await Task.sleep(for: .milliseconds(16)) }
                catch { return }
                guard !Task.isCancelled, let self else { return }

                let elapsed = Self.seconds(in: startedAt.duration(to: clock.now))
                let timeProgress = min(1, max(0, elapsed / duration))
                self.throwProgress = min(1, CGFloat(elapsed / 0.36))
                let fallProgress = max(0, (elapsed - 0.36) / (duration - 0.36))
                let travel = self.effectsMetrics.travel(at: CGFloat(fallProgress))
                self.anchorTravel = travel

                if !didImpactWater, travel >= self.waterImpactTravel {
                    didImpactWater = true
                    self.registerWaterImpact(normalizedVelocity: sqrt(self.waterImpactTravel))
                }
                if timeProgress >= 1 { break }
            }

            guard !Task.isCancelled, let self else { return }
            self.anchorTravel = 1
            if !didImpactWater {
                self.registerWaterImpact(normalizedVelocity: 1)
            }
            self.phase = .deployed

            try? await Task.sleep(for: AnchorMotion.waterSplashDuration)
            guard !Task.isCancelled else { return }
            self.showsSplashParticles = false
        }
    }

    private func beginRetrieval(reduceMotion: Bool) {
        cancelPendingWork()
        startSway(reduceMotion: reduceMotion, impulse: -35)
        isTucked = false
        showsSplashParticles = false
        splashStartedAt = nil

        guard !reduceMotion else {
            withAnimation(.easeOut(duration: 0.20)) {
                resetToHarboredState()
            }
            playSound(.anchorRetrieved)
            scheduleTuck()
            return
        }

        phase = .retrieving
        withAnimation(AnchorMotion.micro) {
            waterVisibility = 0
        }
        withAnimation(AnchorMotion.anchorLift) {
            anchorTravel = 0
        }

        transitionTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            withAnimation(AnchorMotion.micro) {
                self.resetToHarboredState()
            }
            self.playSound(.anchorRetrieved)
            self.scheduleTuck()
        }
    }

    private func revealControl() {
        tuckTask?.cancel()
        guard isTucked else { return }
        withAnimation(reduceMotion ? nil : AnchorMotion.edgeRest) {
            isTucked = false
        }
    }

    private var hasActiveInteraction: Bool {
        isPointerInside || isKeyboardFocused
    }

    private func registerWaterImpact(normalizedVelocity: CGFloat) {
        waterImpactIntensity = min(1, max(0, normalizedVelocity))
        waterImpactXOffset = anchorSway + throwOffset.width
        splashTrigger += 1
        splashStartedAt = .now
        showsSplashParticles = true
        playSound(.anchorLanded)
        withAnimation(AnchorMotion.micro) {
            waterVisibility = 1
        }
    }

    private static func seconds(in duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    private func startSway(reduceMotion: Bool, impulse: Double) {
        swayTask?.cancel()
        guard !reduceMotion else {
            anchorSway = 0
            ropeBend = 0
            swayVelocity = 0
            ropeVelocity = 0
            return
        }
        // Damped spring integration: retain momentum when a drop reverses into retrieval.
        swayVelocity += impulse
        swayTask = Task { [weak self] in
            let clock = ContinuousClock()
            var previous = clock.now
            for _ in 0..<150 {
                do { try await Task.sleep(for: .milliseconds(16)) }
                catch { return }
                guard let self else { return }
                let now = clock.now
                let elapsed = previous.duration(to: now).components
                previous = now
                let dt = min(0.05, Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
                // Small substeps keep the solver stable under delayed UI frames.
                let steps = max(1, Int(ceil(dt / 0.004)))
                let step = dt / Double(steps)
                for _ in 0..<steps {
                    self.swayVelocity += (-85 * Double(self.anchorSway) - 5.8 * self.swayVelocity) * step
                    self.anchorSway += self.swayVelocity * step
                    self.ropeVelocity += (110 * (Double(self.anchorSway) * 0.6 - Double(self.ropeBend)) - 8 * self.ropeVelocity) * step
                    self.ropeBend += self.ropeVelocity * step
                }
            }
            guard let self else { return }
            self.anchorSway = 0
            self.ropeBend = 0
            self.swayVelocity = 0
            self.ropeVelocity = 0
        }
    }

    private func cancelPendingWork() {
        transitionTask?.cancel()
        transitionTask = nil
        tuckTask?.cancel()
        tuckTask = nil
    }

    private func resetToHarboredState() {
        phase = .harbored
        anchorTravel = 0
        throwProgress = 0
        waterVisibility = 0
        showsSplashParticles = false
        waterImpactIntensity = 0
        waterImpactXOffset = 0
        splashStartedAt = nil
    }
}
#endif
