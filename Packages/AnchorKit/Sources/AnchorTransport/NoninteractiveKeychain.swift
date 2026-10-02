import Foundation
import LocalAuthentication
import Security

/// Transport credentials are accessed in the background and must never open
/// password dialogs. Legacy macOS ACL prompts need a process-wide policy;
/// LAContext alone only covers the Data Protection keychain.
enum NoninteractiveKeychain {
#if os(macOS)
    private static let legacyInteractionStatus = SecKeychainSetUserInteractionAllowed(false)
#endif

    static func copyMatching(_ query: [String: Any], result: inout CFTypeRef?) -> OSStatus {
        guard preparationStatus == errSecSuccess else { return preparationStatus }
        return SecItemCopyMatching(noninteractive(query) as CFDictionary, &result)
    }

    static func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        guard preparationStatus == errSecSuccess else { return preparationStatus }
        return SecItemUpdate(noninteractive(query) as CFDictionary, attributes as CFDictionary)
    }

    static func add(_ attributes: [String: Any]) -> OSStatus {
        guard preparationStatus == errSecSuccess else { return preparationStatus }
        return SecItemAdd(noninteractive(attributes) as CFDictionary, nil)
    }

    private static var preparationStatus: OSStatus {
#if os(macOS)
        legacyInteractionStatus
#else
        errSecSuccess
#endif
    }

    private static func noninteractive(_ query: [String: Any]) -> [String: Any] {
        let context = LAContext()
        context.interactionNotAllowed = true
        var query = query
        query[kSecUseAuthenticationContext as String] = context
        return query
    }
}
