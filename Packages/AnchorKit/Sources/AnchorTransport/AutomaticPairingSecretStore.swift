import Foundation
import Security

/// A high-entropy bootstrap secret synchronized only through the user's iCloud Keychain.
public struct AutomaticPairingSecretStore: Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "com.andywang.anchor.automatic-pairing",
        account: String = "icloud-bootstrap-v1"
    ) {
        self.service = service
        self.account = account
    }

    public func load() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            #if DEBUG
            print("[AnchorPairing] iCloud keychain load status \(status)")
            #endif
            return nil
        }
        guard let data = result as? Data, data.count == 32 else { return nil }
        return data
    }

    public func loadOrCreate() -> Data? {
        if let existing = load() { return existing }
        guard let secret = Self.randomSecret() else { return nil }

        let insertion: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanTrue as Any,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue as Any,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecValueData as String: secret,
        ]
        let status = SecItemAdd(insertion as CFDictionary, nil)
        #if DEBUG
        print("[AnchorPairing] iCloud keychain add status \(status)")
        #endif
        if status == errSecSuccess { return secret }
        if status == errSecDuplicateItem { return load() }
        return nil
    }

    @concurrent
    public func loadAsync() async -> Data? {
        load()
    }

    @concurrent
    public func loadOrCreateAsync() async -> Data? {
        loadOrCreate()
    }

    private static func randomSecret() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, address)
        }
        guard status == errSecSuccess else {
            return nil
        }
        return Data(bytes)
    }
}
