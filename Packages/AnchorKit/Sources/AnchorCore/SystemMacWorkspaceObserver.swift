#if os(macOS)
import AppKit
import Foundation

@MainActor
final class SystemMacWorkspaceObserver {
    private let excludedBundleIdentifiers: Set<String>

    init(excludedBundleIdentifiers: Set<String>) {
        self.excludedBundleIdentifiers = excludedBundleIdentifiers
    }

    func snapshot() -> [MacApplicationSnapshot] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { application in
                let identifier = application.bundleIdentifier
                    ?? application.bundleURL?.path
                    ?? application.executableURL?.path
                guard let identifier,
                      !excludedBundleIdentifiers.contains(identifier),
                      let name = application.localizedName else {
                    return nil
                }
                return MacApplicationSnapshot(
                    identifier: identifier,
                    localizedName: name,
                    processIdentifier: application.processIdentifier,
                    isActive: application.isActive,
                    launchDate: application.launchDate
                )
            }
    }

    func changes(reconciliationInterval: TimeInterval) -> AsyncStream<Void> {
        let subscription = MacWorkspaceSignalSubscription(
            reconciliationInterval: reconciliationInterval
        )
        return AsyncStream { continuation in
            subscription.start(continuation: continuation)
            continuation.onTermination = { _ in
                Task { @MainActor in subscription.stop() }
            }
        }
    }
}

@MainActor
private final class MacWorkspaceSignalSubscription {
    private static let notificationNames: [Notification.Name] = [
        NSWorkspace.didLaunchApplicationNotification,
        NSWorkspace.didTerminateApplicationNotification,
        NSWorkspace.didActivateApplicationNotification,
        NSWorkspace.didDeactivateApplicationNotification,
        NSWorkspace.didHideApplicationNotification,
        NSWorkspace.didUnhideApplicationNotification,
    ]

    private let reconciliationInterval: TimeInterval
    private let notificationCenter = NSWorkspace.shared.notificationCenter
    private var observerTokens: [NSObjectProtocol] = []
    private var reconciliationTask: Task<Void, Never>?

    init(reconciliationInterval: TimeInterval) {
        self.reconciliationInterval = reconciliationInterval
    }

    func start(continuation: AsyncStream<Void>.Continuation) {
        continuation.yield(())
        observerTokens = Self.notificationNames.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { _ in
                continuation.yield(())
            }
        }
        reconciliationTask = Task { @MainActor [reconciliationInterval] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(reconciliationInterval))
                } catch {
                    break
                }
                continuation.yield(())
            }
        }
    }

    func stop() {
        reconciliationTask?.cancel()
        reconciliationTask = nil
        for token in observerTokens {
            notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
    }
}
#endif
