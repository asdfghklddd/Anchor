import Foundation
import Security

public struct PairingIdentityStore: Sendable {
    private let service: String

    public init(service: String = "com.andywang.anchor.local-link") {
        self.service = service
    }

    public func localDeviceID() -> UUID {
        if let data = load(account: "local-device-id"),
           let value = String(data: data, encoding: .utf8),
           let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        try? save(Data(id.uuidString.utf8), account: "local-device-id")
        return id
    }

    public func saveSharedKey(_ key: Data, peerID: UUID) throws {
        try save(key, account: "peer-\(peerID.uuidString)")
    }

    public func sharedKey(peerID: UUID) -> Data? {
        load(account: "peer-\(peerID.uuidString)")
    }

    private func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var insertion = query
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insertion as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }

    private func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }
}
