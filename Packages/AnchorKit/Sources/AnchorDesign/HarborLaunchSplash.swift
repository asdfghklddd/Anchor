#if os(iOS)
import SwiftUI

public struct HarborLaunchSplash: View {
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    let logoIsVisible: Bool
    let wordmarkIsVisible: Bool
    let rippleIsExpanded: Bool

    public init(
        logoIsVisible: Bool,
        wordmarkIsVisible: Bool,
        rippleIsExpanded: Bool = false
    ) {
        self.logoIsVisible = logoIsVisible
        self.wordmarkIsVisible = wordmarkIsVisible
        self.rippleIsExpanded = rippleIsExpanded
    }

    public var body: some View {
        VStack(spacing: 18) {
            ZStack {
                if !reduceMotion {
                    Circle()
                        .stroke(AnchorIOSStyle.cyan, lineWidth: 1.5)
                        .scaleEffect(rippleIsExpanded ? 1.65 : 0.92)
                        .opacity(logoIsVisible && !rippleIsExpanded ? 0.28 : 0)
                }

                HarborBrandMark(size: 112)
                    .opacity(logoIsVisible ? 1 : 0)
                    .keyframeAnimator(initialValue: LaunchPose(), trigger: logoIsVisible) { mark, pose in
                        mark
                            .scaleEffect(x: reduceMotion ? 1 : pose.width,
                                         y: reduceMotion ? 1 : pose.height)
                            .rotationEffect(.degrees(reduceMotion ? 0 : pose.tilt))
                            .offset(y: reduceMotion ? 0 : pose.lift)
                    } keyframes: { _ in
                        KeyframeTrack(\.lift) {
                            CubicKeyframe(-9, duration: 0.12)
                            CubicKeyframe(5, duration: 0.16)
                            SpringKeyframe(-3, duration: 0.18, spring: .snappy)
                            SpringKeyframe(0, duration: 0.24, spring: .smooth)
                        }
                        KeyframeTrack(\.width) {
                            CubicKeyframe(0.96, duration: 0.12)
                            CubicKeyframe(1.08, duration: 0.16)
                            SpringKeyframe(0.98, duration: 0.18, spring: .snappy)
                            SpringKeyframe(1, duration: 0.24, spring: .smooth)
                        }
                        KeyframeTrack(\.height) {
                            CubicKeyframe(1.04, duration: 0.12)
                            CubicKeyframe(0.93, duration: 0.16)
                            SpringKeyframe(1.02, duration: 0.18, spring: .snappy)
                            SpringKeyframe(1, duration: 0.24, spring: .smooth)
                        }
                        KeyframeTrack(\.tilt) {
                            CubicKeyframe(-5, duration: 0.12)
                            CubicKeyframe(2, duration: 0.16)
                            SpringKeyframe(0, duration: 0.42, spring: .smooth)
                        }
                    }
            }
            .frame(width: 112, height: 112)

            Text("ANCHOR")
                .font(.caption.bold())
                .tracking(4)
                .foregroundStyle(AnchorIOSStyle.heading)
                .opacity(wordmarkIsVisible ? 1 : 0)
                .offset(y: reduceMotion || wordmarkIsVisible ? 0 : 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { HarborBackground() }
        .accessibilityHidden(true)
    }
}
// Finite anticipation, impact and settle tracks; no idle animation or timer.
private struct LaunchPose {
    var lift: CGFloat = 0
    var width: CGFloat = 1
    var height: CGFloat = 1
    var tilt: Double = 0
}
#endif
