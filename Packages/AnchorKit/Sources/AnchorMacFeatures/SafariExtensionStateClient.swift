#if os(macOS)
import Foundation
import SafariServices

/// Wraps Safari's public extension state and preference-opening callbacks.
struct SafariExtensionStateClient: Sendable {
    static let extensionIdentifier = "com.andywang.anchor.safari-extension"

    nonisolated func isEnabled() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let completion: @Sendable (SFSafariExtensionState?, (any Error)?) -> Void = { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state?.isEnabled == true)
                }
            }
            SFSafariExtensionManager.getStateOfSafariExtension(
                withIdentifier: Self.extensionIdentifier,
                completionHandler: completion
            )
        }
    }

    nonisolated func showPreferences() async throws {
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            let completion: @Sendable ((any Error)?) -> Void = { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
            SFSafariApplication.showPreferencesForExtension(
                withIdentifier: Self.extensionIdentifier,
                completionHandler: completion
            )
        }
    }
}
#endif
