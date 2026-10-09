import CoreGraphics
import Foundation

/// The launch scene: the logo lifts, falls into the harbor, splashes, sinks and settles,
/// then the wordmark and slogan surface and the tide rises into the workspace.
///
/// Every frame is a pure function of elapsed time, so the sequence is deterministic,
/// display-synced when driven by a `TimelineView`, and can be cut short at any moment.
public struct HarborLaunchChoreography: Sendable {
    // MARK: Beats (seconds)

    public static let appearEnd = 0.20
    /// The harbor rises out of the blank system launch screen while the logo lifts.
    public static let waterIntro = 0.34
    public static let impactTime = 0.58
    public static let wordmarkStart = 0.88
    public static let sloganStart = 1.02
    public static let textReveal = 0.42
    public static let exitStart = 1.78
    public static let exitDuration = 0.42
    public static let skipExitDuration = 0.26
    public static let reducedHold = 0.55
    public static let reducedFade = 0.18

    /// When the tide begins and how long it takes, including an early tap-to-skip.
    public struct Timing: Sendable, Equatable {
        public let reduceMotion: Bool
        public let exitBegins: Double
        public let exitDuration: Double

        public init(reduceMotion: Bool, skippedAt: Double? = nil) {
            self.reduceMotion = reduceMotion
            let scheduled = reduceMotion ? HarborLaunchChoreography.reducedHold : HarborLaunchChoreography.exitStart
            if let skippedAt, skippedAt < scheduled {
                exitBegins = max(0, skippedAt)
                exitDuration = reduceMotion ? HarborLaunchChoreography.reducedFade : HarborLaunchChoreography.skipExitDuration
            } else {
                exitBegins = scheduled
                exitDuration = reduceMotion ? HarborLaunchChoreography.reducedFade : HarborLaunchChoreography.exitDuration
            }
        }

        public var total: Double { exitBegins + exitDuration }
    }

    public struct LogoPose: Sendable, Equatable {
        public var center: CGPoint
        public var scaleX: CGFloat
        public var scaleY: CGFloat
        public var rotationDegrees: Double
        public var opacity: Double
    }

    public struct Particle: Sendable, Equatable {
        public var center: CGPoint
        public var radius: CGFloat
        public var opacity: Double
    }

    public struct Ripple: Sendable, Equatable {
        public var center: CGPoint
        public var radius: CGFloat
        public var opacity: Double
    }

    public struct Reveal: Sendable, Equatable {
        public var opacity: Double
        public var blur: CGFloat
        public var offset: CGFloat
    }

    public let size: CGSize
    public let timing: Timing

    public init(size: CGSize, timing: Timing) {
        self.size = size
        self.timing = timing
    }

    // MARK: Layout

    public var logoSide: CGFloat { min(150, min(size.width, size.height) * 0.34) }
    public var restingWaterline: CGFloat { size.height * 0.56 }
    public var textCenterY: CGFloat { size.height * 0.30 }
    var centerX: CGFloat { size.width / 2 }
    var startY: CGFloat { size.height * 0.27 }
    var liftedY: CGFloat { startY - 12 }
    /// The logo's lowest point touches the surface.
    public var impactY: CGFloat { restingWaterline - logoSide * 0.48 }
    /// Fully submerged, while staying on screen in landscape.
    public var restY: CGFloat {
        restingWaterline + min(logoSide * 0.95, size.height - restingWaterline - logoSide * 0.6)
    }
    var fallVelocity: CGFloat {
        2 * (impactY - liftedY) / CGFloat(Self.impactTime - Self.appearEnd)
    }

    // MARK: Scene

    /// Progress through the closing tide, 0 before it starts.
    public func exitProgress(at t: Double) -> Double {
        clamp((t - timing.exitBegins) / timing.exitDuration)
    }

    public func sceneOpacity(at t: Double) -> Double {
        let p = exitProgress(at: t)
        return timing.reduceMotion ? 1 - p : 1 - smoothstep(0.45, 1, p)
    }

    /// The water rises into place, holds, then the tide rises past the top of the
    /// screen as the scene hands over to the app.
    public func waterline(at t: Double) -> CGFloat {
        guard !timing.reduceMotion else { return restingWaterline }
        if t < Self.waterIntro {
            let e = CGFloat(easeOutCubic(clamp(t / Self.waterIntro)))
            return size.height + (restingWaterline - size.height) * e
        }
        let e = CGFloat(easeInOutCubic(exitProgress(at: t)))
        return restingWaterline + (-size.height * 0.08 - restingWaterline) * e
    }

    /// Vertical offset of the surface at `x`; positive is downward.
    public func surfaceOffset(x: CGFloat, at t: Double) -> CGFloat {
        let time = timing.reduceMotion ? 0 : t
        var y = 3.5 * sin(x / 46 + time * 2.2) + 2 * sin(x / 23 - time * 3.1)
        guard !timing.reduceMotion, t > Self.impactTime else { return y }
        // An outward ring from the impact: an initial dip that travels and decays.
        let tau = t - Self.impactTime
        let d = abs(x - centerX)
        let front = clamp((tau * 260 + 30 - Double(d)) / 30)
        y += 11 * CGFloat(exp(-2.6 * tau) * front) * exp(-d / 140) * cos(d / 18 - tau * 11)
        return y
    }

    public func logo(at t: Double) -> LogoPose {
        guard !timing.reduceMotion else {
            return LogoPose(center: CGPoint(x: centerX, y: restY), scaleX: 1, scaleY: 1, rotationDegrees: 0, opacity: 1)
        }
        if t < Self.appearEnd {
            // Anticipation: fade in and lift slightly with a small crouch and tilt.
            let e = CGFloat(easeOutCubic(clamp(t / Self.appearEnd)))
            return LogoPose(
                center: CGPoint(x: centerX, y: startY - 12 * e),
                scaleX: (0.92 + 0.08 * e) * (1 + 0.03 * e),
                scaleY: (0.92 + 0.08 * e) * (1 - 0.04 * e),
                rotationDegrees: -5 * Double(e),
                opacity: clamp(t / 0.14)
            )
        }
        if t < Self.impactTime {
            // Gravity: accelerate toward the surface and stretch along the fall.
            let u = CGFloat((t - Self.appearEnd) / (Self.impactTime - Self.appearEnd))
            return LogoPose(
                center: CGPoint(x: centerX, y: liftedY + (impactY - liftedY) * u * u),
                scaleX: 1.03 - 0.07 * u,
                scaleY: 0.96 + 0.11 * u,
                rotationDegrees: -5 + 8 * Double(u),
                opacity: 1
            )
        }
        // Water: an underdamped spring carries the remaining momentum to the resting depth.
        let tau = t - Self.impactTime
        let omega = 6.5, zeta = 0.62
        let omegaD = omega * (1 - zeta * zeta).squareRoot()
        let x0 = Double(impactY - restY)
        let v0 = Double(fallVelocity) * 0.3
        let offset = exp(-zeta * omega * tau)
            * (x0 * cos(omegaD * tau) + (v0 + zeta * omega * x0) / omegaD * sin(omegaD * tau))
        let squash = CGFloat(exp(-tau / 0.07))
        return LogoPose(
            center: CGPoint(x: centerX, y: restY + CGFloat(offset)),
            scaleX: 1 + 0.08 * squash,
            scaleY: 1 - 0.08 * squash,
            rotationDegrees: 3 * exp(-3 * tau) * cos(2 * .pi * 1.1 * tau),
            opacity: 1
        )
    }

    /// Spray thrown up by the impact; each drop falls back into the water.
    public func droplets(at t: Double) -> [Particle] {
        guard !timing.reduceMotion, t >= Self.impactTime else { return [] }
        let tau = t - Self.impactTime
        guard tau < 0.8 else { return [] }
        let surface = waterline(at: t)
        return (0..<14).compactMap { i in
            let spread = Double(i) / 13
            let angle = (-62 + 124 * spread + (noise(i) - 0.5) * 14) * .pi / 180
            let speed = 230 + 160 * noise(i + 17)
            let vx = sin(angle) * speed * 0.75
            let vy = -cos(angle) * speed
            let point = CGPoint(
                x: centerX + CGFloat(vx * tau),
                y: restingWaterline + CGFloat(vy * tau + 550 * tau * tau)
            )
            guard tau < 0.05 || point.y <= surface + 4 else { return nil }
            return Particle(center: point, radius: CGFloat(2 + 2.8 * noise(i + 31)), opacity: 0.9 * (1 - tau / 0.8))
        }
    }

    /// Flattened rings spreading over the surface from the impact point.
    public func ripples(at t: Double) -> [Ripple] {
        guard !timing.reduceMotion else { return [] }
        return (0..<3).compactMap { i in
            let p = (t - Self.impactTime - 0.1 * Double(i)) / 0.95
            guard p >= 0, p < 1 else { return nil }
            return Ripple(
                center: CGPoint(x: centerX, y: waterline(at: t)),
                radius: logoSide * (0.2 + 1.2 * CGFloat(easeOutCubic(p))),
                opacity: 0.55 * (1 - p)
            )
        }
    }

    /// Air escaping the sinking logo, wobbling up and vanishing at the surface.
    public func bubbles(at t: Double) -> [Particle] {
        guard !timing.reduceMotion else { return [] }
        let surface = waterline(at: t)
        return (0..<9).compactMap { i in
            let spawn = Self.impactTime + 0.08 + 0.07 * Double(i)
            let tau = t - spawn
            guard tau >= 0, tau < 1.4 else { return nil }
            let origin = logo(at: spawn).center
            let y = origin.y - CGFloat((70 + 50 * noise(i + 53)) * tau)
            guard y > surface + 6 else { return nil }
            let x = origin.x + (CGFloat(noise(i + 71)) - 0.5) * logoSide * 0.5 + 4 * CGFloat(sin(tau * 7 + Double(i)))
            let fade = min(1, Double(y - surface) / 30)
            return Particle(
                center: CGPoint(x: x, y: y),
                radius: CGFloat(1.6 + 2.4 * noise(i + 89)),
                opacity: 0.7 * clamp(tau / 0.1) * fade
            )
        }
    }

    public func wordmark(at t: Double) -> Reveal { reveal(startingAt: Self.wordmarkStart, at: t) }
    public func slogan(at t: Double) -> Reveal { reveal(startingAt: Self.sloganStart, at: t) }

    private func reveal(startingAt start: Double, at t: Double) -> Reveal {
        guard !timing.reduceMotion else { return Reveal(opacity: 1, blur: 0, offset: 0) }
        // Sharpen out of a blur while settling upward, then lift away with the tide.
        let e = easeOutCubic(clamp((t - start) / Self.textReveal))
        let exit = exitProgress(at: t)
        return Reveal(
            opacity: e * (1 - clamp(exit * 2.5)),
            blur: CGFloat(8 * (1 - e)),
            offset: CGFloat(8 * (1 - e) - 10 * exit)
        )
    }
}

// MARK: Easing

private func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
private func easeOutCubic(_ p: Double) -> Double { 1 - pow(1 - p, 3) }
private func easeInOutCubic(_ p: Double) -> Double {
    p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2
}
private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
    let p = clamp((x - edge0) / (edge1 - edge0))
    return p * p * (3 - 2 * p)
}
/// Stable per-index jitter so every launch draws the same splash.
private func noise(_ seed: Int) -> Double {
    let value = sin(Double(seed) * 12.9898) * 43_758.5453
    return value - value.rounded(.down)
}
