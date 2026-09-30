#if os(iOS)
import SwiftUI

public struct AnchorLaunchGate<Content: View>: View {
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    @State private var isPresentingSplash = true
    @State private var logoIsVisible = false
    @State private var wordmarkIsVisible = false
    @State private var rippleIsExpanded = false
    @State private var isExiting = false

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content
                .allowsHitTesting(!isPresentingSplash)
                .accessibilityHidden(isPresentingSplash)

            if isPresentingSplash {
                HarborLaunchSplash(
                    logoIsVisible: logoIsVisible,
                    wordmarkIsVisible: wordmarkIsVisible,
                    rippleIsExpanded: rippleIsExpanded
                )
                .opacity(isExiting ? 0 : 1)
                .zIndex(100)
                .accessibilityIdentifier("launch.splash")
            }
        }
        .task(id: reduceMotion) { await playLaunchSequence() }
    }

    @MainActor
    private func playLaunchSequence() async {
        guard isPresentingSplash else { return }

        // A cancelled presentation may be mounted again, or Reduce Motion may change.
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            logoIsVisible = reduceMotion
            wordmarkIsVisible = reduceMotion
            rippleIsExpanded = false
            isExiting = false
        }

        if reduceMotion {
            guard await wait(for: .milliseconds(220)) else { return }
        } else {
            withAnimation(AnchorMotion.continuity) { logoIsVisible = true }
            guard await wait(for: .milliseconds(280)) else { return }
            withAnimation(AnchorMotion.panel) { wordmarkIsVisible = true }
            withAnimation(.easeOut(duration: 0.58)) { rippleIsExpanded = true }
            guard await wait(for: .milliseconds(580)) else { return }
        }

        // Keep the overlay mounted for the entire fade; never truncate its last frames.
        let fadeDuration = reduceMotion ? 0.18 : 0.28
        withAnimation(.easeInOut(duration: fadeDuration)) { isExiting = true }
        guard await wait(for: .seconds(fadeDuration)) else { return }
        isPresentingSplash = false
    }

    private func wait(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
#endif
