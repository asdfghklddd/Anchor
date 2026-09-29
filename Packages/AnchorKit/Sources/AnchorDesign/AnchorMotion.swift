import SwiftUI

/// Shared motion values keep feedback crisp and spatial transitions consistent.
public enum AnchorMotion {
    public static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    public static let micro = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.20)
    public static let panel = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.26)
    public static let continuity = Animation.spring(response: 0.40, dampingFraction: 0.90)
    public static let boatDeparture = Animation.timingCurve(0.45, 0, 0.20, 1, duration: 0.72)
    public static let edgeRest = Animation.spring(response: 0.40, dampingFraction: 1.00)
    public static let anchorDropDuration: Duration = .milliseconds(2_100)
    public static let waterSplashDuration: Duration = .milliseconds(680)
    public static let anchorLift = Animation.spring(response: 0.40, dampingFraction: 1.00)
}
