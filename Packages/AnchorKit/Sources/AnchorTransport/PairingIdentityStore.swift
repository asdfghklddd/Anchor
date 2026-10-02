import Foundation
import Security
import Synchronization

public struct PairingIdentityStore: Sendable {
    public enum Keychain: Sendable, Hashable {
        /// App-owned credentials are authorized by stable signing entitlements.
        case dataProtection
        /// Compatibility for ad-hoc development and disposable integration tests.
        case legacy
    }

    private let storage: Storage

    public init(
        service: String = "com.andywang.anchor.local-link",
        keychain: Keychain = .dataProtection
    ) {
        storage = Storage(persistence: KeychainPairingIdentityPersistence(service: service, keychain: keychain))
    }

    /// UI tests and local validation have no durable pairing credentials.
    public static func inMemory() -> PairingIdentityStore {
        PairingIdentityStore(persistence: nil)
    }

    init(persistence: (any PairingIdentityPersistence)?) {
        storage = Storage(persistence: persistence)
    }

    public func localDeviceID() -> UUID {
        storage.state.withLock { state in
            if let id = state.deviceID { return id }
            if let id = storage.persistence?.deviceID() {
                state.deviceID = id
                return id
            }
            // Migrate a readable legacy ID. An inaccessible item is never
            // treated as missing or overwritten with a newly generated ID.
            let id: UUID
            if case .value(let data) = storage.load(account: "local-device-id", state: &state),
               let value = String(data: data, encoding: .utf8),
               let existingID = UUID(uuidString: value) {
                id = existingID
            } else {
                id = UUID()
            }
            // This identifier is public in discovery frames, not a secret.
            // Persist it outside Keychain so startup never needs an ACL dialog.
            storage.persistence?.saveDeviceID(id)
            state.deviceID = id
            return id
        }
    }

    public func saveSharedKey(_ key: Data, peerID: UUID) throws {
        try storage.state.withLock { state in
            let account = "peer-\(peerID.uuidString)"
            let status = storage.persistence?.save(key, account: account) ?? errSecSuccess
            guard status == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            }
            state.lookups[account] = .value(key)
        }
    }

    public func sharedKey(peerID: UUID) -> Data? {
        storage.state.withLock { state in
            if case .value(let data) = storage.load(account: "peer-\(peerID.uuidString)", state: &state) {
                return data
            }
            return nil
        }
    }

    private final class Storage: Sendable {
        struct State: Sendable {
            var deviceID: UUID?
            var lookups: [String: PairingIdentityLookup] = [:]
        }

        let persistence: (any PairingIdentityPersistence)?
        let state = Mutex(State())

        init(persistence: (any PairingIdentityPersistence)?) {
            self.persistence = persistence
        }

        func load(account: String, state: inout State) -> PairingIdentityLookup {
            if let cached = state.lookups[account] { return cached }
            let lookup = persistence?.load(account: account) ?? .missing
            // Cache unavailable results as well: heartbeats and reconnects
            // must not repeatedly request an item the process cannot access.
            state.lookups[account] = lookup
            return lookup
        }
    }
}

enum PairingIdentityLookup: Sendable {
    case value(Data)
    case missing
    case unavailable(OSStatus)
}

protocol PairingIdentityPersistence: Sendable {
    func load(account: String) -> PairingIdentityLookup
    func save(_ data: Data, account: String) -> OSStatus
    func deviceID() -> UUID?
    func saveDeviceID(_ id: UUID)
}

struct KeychainPairingIdentityPersistence: PairingIdentityPersistence {
    let service: String
    let keychain: PairingIdentityStore.Keychain
    let client: any PairingKeychainClient

    init(
        service: String,
        keychain: PairingIdentityStore.Keychain,
        client: any PairingKeychainClient = SystemPairingKeychainClient()
    ) {
        self.service = service
        self.keychain = keychain
        self.client = client
    }

    func deviceID() -> UUID? {
        UserDefaults.standard.string(forKey: "\(service).local-device-id").flatMap(UUID.init(uuidString:))
    }

    func saveDeviceID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: "\(service).local-device-id")
    }

    func load(account: String) -> PairingIdentityLookup {
        let lookup = client.load(service: service, account: account, keychain: keychain)
#if os(macOS)
        // Migrate only after a successful search confirms the modern item is
        // missing. Signing/entitlement failures must not fall back to legacy
        // storage or silently change the credential's security boundary.
        if case .missing = lookup, keychain == .dataProtection {
            let legacy = client.load(service: service, account: account, keychain: .legacy)
            if case .value(let data) = legacy {
                // The public ID moves to defaults; peer secrets move to the
                // modern keychain. Leave every legacy item intact.
                if account == "local-device-id" { return legacy }
                let status = save(data, account: account)
                return status == errSecSuccess ? legacy : .unavailable(status)
            }
            return legacy
        }
#endif
        return lookup
    }

    func save(_ data: Data, account: String) -> OSStatus {
        client.save(data, service: service, account: account, keychain: keychain)
    }
}

protocol PairingKeychainClient: Sendable {
    func load(service: String, account: String, keychain: PairingIdentityStore.Keychain) -> PairingIdentityLookup
    func save(_ data: Data, service: String, account: String, keychain: PairingIdentityStore.Keychain) -> OSStatus
}

private struct SystemPairingKeychainClient: PairingKeychainClient {
    func load(service: String, account: String, keychain: PairingIdentityStore.Keychain) -> PairingIdentityLookup {
        var query = itemQuery(service: service, account: account, keychain: keychain)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = NoninteractiveKeychain.copyMatching(query, result: &result)
        if status == errSecItemNotFound { return .missing }
        guard status == errSecSuccess else { return .unavailable(status) }
        guard let data = result as? Data else { return .unavailable(errSecDecode) }
        return .value(data)
    }

    func save(_ data: Data, service: String, account: String, keychain: PairingIdentityStore.Keychain) -> OSStatus {
        let query = itemQuery(service: service, account: account, keychain: keychain)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = NoninteractiveKeychain.update(query, attributes: attributes)
        guard status == errSecItemNotFound else { return status }
        return NoninteractiveKeychain.add(query.merging(attributes) { _, replacement in replacement })
    }

    private func itemQuery(service: String, account: String, keychain: PairingIdentityStore.Keychain) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if keychain == .dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }
}
