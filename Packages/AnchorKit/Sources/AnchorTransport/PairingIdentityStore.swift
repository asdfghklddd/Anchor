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
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(updateStatus))
        }

        var insertion = query
        insertion.merge(attributes) { _, replacement in replacement }
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
