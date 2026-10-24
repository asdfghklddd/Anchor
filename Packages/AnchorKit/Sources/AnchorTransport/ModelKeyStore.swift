import Foundation
import Security

/// The API key of the model that writes return recaps, kept in this Mac's
/// Keychain only: never in code, defaults or sync.
public struct ModelKeyStore: Sendable {
    private let service: String
    private let account: String

    public init(service: String = "com.andywang.anchor.model-key", account: String = "deepseek") {
        self.service = service
        self.account = account
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
        ]
    }

    public func load() -> String? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard NoninteractiveKeychain.copyMatching(lookup, result: &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        let key = String(decoding: data, as: UTF8.self)
        return key.isEmpty ? nil : key
    }

    /// Saves the key, or removes it when empty.
    @discardableResult
    public func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SecItemDelete(query as CFDictionary) != errSecInteractionNotAllowed }
        let data = Data(trimmed.utf8)
        let status = NoninteractiveKeychain.update(query, attributes: [kSecValueData as String: data])
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var insertion = query
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return NoninteractiveKeychain.add(insertion) == errSecSuccess
    }
}
