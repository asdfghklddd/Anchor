#if os(iOS)
import SwiftUI

public struct AnchorLaunchGate<Content: View>: View {
    @AnchorReducedMotion private var reduceMotion

    @State private var isPresentingSplash = true
    @State private var startedAt = Date.now
    @State private var skippedAt: Double?

    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // The workspace mounts underneath at once; it only waits for input and focus.
            content
                .allowsHitTesting(!isPresentingSplash)
                .accessibilityHidden(isPresentingSplash)

            if isPresentingSplash {
                HarborLaunchSplash(startedAt: startedAt, timing: timing, onSkip: skip)
                    .zIndex(100)
                    .accessibilityIdentifier("launch.splash")
            }
        }
        // Start the clock when the scene is first shown, not when app setup began,
        // so a slow cold start never skips the opening beats.
        .onAppear { startedAt = .now }
        .task(id: timing) { await dismissWhenFinished() }
    }

    private var timing: HarborLaunchChoreography.Timing {
        HarborLaunchChoreography.Timing(reduceMotion: reduceMotion, skippedAt: skippedAt)
    }

    private func skip() {
        guard skippedAt == nil else { return }
        skippedAt = Date.now.timeIntervalSince(startedAt)
    }

    @MainActor
    private func dismissWhenFinished() async {
        guard isPresentingSplash else { return }
        // Keep the overlay for the whole tide and fade; never truncate its last frames.
        let remaining = timing.total - Date.now.timeIntervalSince(startedAt)
        if remaining > 0 {
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        isPresentingSplash = false
    }
}
#endif
