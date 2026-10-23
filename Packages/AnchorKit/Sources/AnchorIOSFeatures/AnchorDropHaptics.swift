#if os(iOS)
import CoreHaptics

/// The drop, felt (D11): a soft thud as the anchor meets the water, a faint hum
/// that fades while it sinks, and a lighter tap when it catches and holds.
/// One pattern per drop, scheduled on the engine's clock so it lands with the
/// motion on screen; nothing plays on the press itself.
@MainActor
final class AnchorDropHaptics {
    private var engine: CHHapticEngine?

    /// Plays the whole drop, with the thud `delay` seconds from now.
    func playDrop(after delay: TimeInterval) {
        play(Self.drop, after: delay)
    }

    /// With reduced motion there is no fall to feel, only the anchor holding.
    func playCatch() {
        play(try? CHHapticPattern(events: [Self.tap(at: 0, intensity: 0.5, sharpness: 0.5)], parameterCurves: []), after: 0)
    }

    private func play(_ pattern: CHHapticPattern?, after delay: TimeInterval) {
        guard let pattern, CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try self.engine ?? makeEngine()
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: engine.currentTime + delay)
        } catch {
            // A missed haptic never blocks the drop; the next one gets a fresh engine.
            self.engine = nil
        }
    }

    private func makeEngine() throws -> CHHapticEngine {
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak self] in Task { @MainActor in self?.engine = nil } }
        engine.stoppedHandler = { [weak self] _ in Task { @MainActor in self?.engine = nil } }
        self.engine = engine
        return engine
    }

    /// Seconds from the thud to the catch; matches the sink on screen.
    nonisolated static let catchDelay: TimeInterval = 0.48

    private static let drop: CHHapticPattern? = {
        let hum = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08),
            ],
            relativeTime: 0.03, duration: 0.34)
        // The hum fades as the anchor goes deeper, then the control returns to
        // full so the catch plays at its own strength.
        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 1),
                .init(relativeTime: 0.34, value: 0),
                .init(relativeTime: 0.36, value: 1),
            ],
            relativeTime: 0.03)
        return try? CHHapticPattern(
            events: [
                tap(at: 0, intensity: 0.78, sharpness: 0.28),
                hum,
                tap(at: catchDelay, intensity: 0.48, sharpness: 0.55),
            ],
            parameterCurves: [fade])
    }()

    private static func tap(at time: TimeInterval, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: time)
    }
}
#endif
