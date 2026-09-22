import SwiftUI

/// Shared motion values keep feedback crisp and spatial transitions consistent.
public enum AnchorMotion {
    public static let press = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.14)
    public static let micro = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.20)
    public static let panel = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.26)
    public static let continuity = Animation.spring(response: 0.40, dampingFraction: 0.90)
    public static let exit = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.22)
}
