#if os(iOS)
import SwiftUI

extension EnvironmentValues {
    /// The launch splash still covers the app: arrivals meant to be watched wait for it.
    @Entry public var launchSplashShowing = false
}

public struct AnchorLaunchGate<Content: View>: View {
    @AnchorReducedMotion private var reduceMotion

    @State private var isPresentingSplash = true
    @State private var startedAt = Date.now
    @State private var skippedAt: Double?
    @State private var impacts = 0

    private let onImpact: @MainActor () -> Void
    private let content: Content

    /// `onImpact` runs when the anchor hits the water, unless the scene was skipped first.
    public init(onImpact: @escaping @MainActor () -> Void = {}, @ViewBuilder content: () -> Content) {
        self.onImpact = onImpact
        self.content = content()
    }

    public var body: some View {
        ZStack {
            // The workspace mounts underneath at once; it only waits for input and focus.
            content
                .allowsHitTesting(!isPresentingSplash)
                .accessibilityHidden(isPresentingSplash)
                .environment(\.launchSplashShowing, isPresentingSplash)

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
        .task { await markImpact() }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: impacts)
    }

    private var timing: HarborLaunchChoreography.Timing {
        HarborLaunchChoreography.Timing(reduceMotion: reduceMotion, skippedAt: skippedAt)
    }

    private func skip() {
        guard skippedAt == nil else { return }
        skippedAt = Date.now.timeIntervalSince(startedAt)
    }

    /// The anchor's splash is felt and heard. Under reduced motion nothing falls.
    @MainActor
    private func markImpact() async {
        guard !reduceMotion else { return }
        let remaining = HarborLaunchChoreography.impactTime - Date.now.timeIntervalSince(startedAt)
        if remaining > 0 {
            do { try await Task.sleep(for: .seconds(remaining)) } catch { return }
        }
        guard skippedAt == nil else { return }
        impacts += 1
        onImpact()
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
