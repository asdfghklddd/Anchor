#if os(iOS)
import SwiftUI

public struct AnchorLaunchGate<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isPresentingSplash = true
    @State private var logoIsVisible = false
    @State private var wordmarkIsVisible = false
    @State private var isExiting = false

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            content

            if isPresentingSplash {
                HarborLaunchSplash(
                    logoIsVisible: logoIsVisible,
                    wordmarkIsVisible: wordmarkIsVisible
                )
                .opacity(isExiting ? 0 : 1)
                .scaleEffect(reduceMotion || !isExiting ? 1 : 1.02)
                .zIndex(100)
                .allowsHitTesting(false)
                .accessibilityIdentifier("launch.splash")
            }
        }
        .task { await playLaunchSequence() }
    }

    @MainActor
    private func playLaunchSequence() async {
        guard isPresentingSplash else { return }

        if reduceMotion {
            logoIsVisible = true
            wordmarkIsVisible = true
            guard await wait(for: .milliseconds(880)) else { return }
            withAnimation(.easeOut(duration: 0.27)) { isExiting = true }
            guard await wait(for: .milliseconds(270)) else { return }
            isPresentingSplash = false
            return
        }

        withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.7)) {
            logoIsVisible = true
        }
        guard await wait(for: .milliseconds(350)) else { return }
        withAnimation(.easeOut(duration: 0.4)) { wordmarkIsVisible = true }
        guard await wait(for: .milliseconds(530)) else { return }
        withAnimation(.easeOut(duration: 0.34)) { isExiting = true }
        guard await wait(for: .milliseconds(270)) else { return }
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
