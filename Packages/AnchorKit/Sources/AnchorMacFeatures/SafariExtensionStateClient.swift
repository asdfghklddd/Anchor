#if os(macOS)
import Foundation
import SafariServices

/// Wraps Safari's public extension state and preference-opening callbacks.
struct SafariExtensionStateClient: Sendable {
    static let extensionIdentifier = "com.andywang.anchor.safari-extension"

    func isEnabled() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            SFSafariExtensionManager.getStateOfSafariExtension(
                withIdentifier: Self.extensionIdentifier
            ) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state?.isEnabled == true)
                }
            }
        }
    }

    func showPreferences() async throws {
        let _: Void = try await withCheckedThrowingContinuation { continuation in
            SFSafariApplication.showPreferencesForExtension(
                withIdentifier: Self.extensionIdentifier
            ) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
#endif
