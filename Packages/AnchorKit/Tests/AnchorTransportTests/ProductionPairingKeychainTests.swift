import Foundation
import Security
import Synchronization
import Testing
@testable import AnchorTransport

@Suite("Production pairing Keychain")
struct ProductionPairingKeychainTests {
    @Test("New peer trust is saved only in the Data Protection keychain")
    func newPeerTrust() throws {
        let client = TestPairingKeychainClient()
        let store = makeStore(client: client)
        let peerID = UUID()
        let key = Data(repeating: 0x35, count: 32)
        try store.saveSharedKey(key, peerID: peerID)
        #expect(store.sharedKey(peerID: peerID) == key)
        #expect(client.operations == ["save:dataProtection"])
    }

#if os(macOS)
    @Test("Readable legacy trust migrates once without deleting the original item")
    func readableLegacyTrust() {
        let key = Data(repeating: 0x41, count: 32)
        let client = TestPairingKeychainClient(legacy: .value(key))
        let peerID = UUID()
        #expect(makeStore(client: client).sharedKey(peerID: peerID) == key)
        #expect(makeStore(client: client).sharedKey(peerID: peerID) == key)
        #expect(client.operations == [
            "load:dataProtection", "load:legacy", "save:dataProtection", "load:dataProtection",
        ])
        if case .value(let original) = client.legacy { #expect(original == key) }
        else { Issue.record("Migration changed the original legacy item") }
    }

    @Test("Signing failures never fall back to a legacy credential")
    func signingFailure() {
        let client = TestPairingKeychainClient(
            modern: .unavailable(errSecMissingEntitlement),
            legacy: .value(Data(repeating: 0x41, count: 32))
        )
        #expect(makeStore(client: client).sharedKey(peerID: UUID()) == nil)
        #expect(client.operations == ["load:dataProtection"])
    }

    @Test("Denied legacy trust allows fresh verified pairing in the modern keychain")
    func deniedLegacyTrust() throws {
        let client = TestPairingKeychainClient(legacy: .unavailable(errSecInteractionNotAllowed))
        let store = makeStore(client: client)
        let peerID = UUID()
        #expect(store.sharedKey(peerID: peerID) == nil)
        let key = Data(repeating: 0x42, count: 32)
        try store.saveSharedKey(key, peerID: peerID)
        #expect(store.sharedKey(peerID: peerID) == key)
        #expect(client.operations == ["load:dataProtection", "load:legacy", "save:dataProtection"])
    }

    @Test("Failed migration preserves the old secret and does not report persistence success")
    func failedMigration() {
        let client = TestPairingKeychainClient(
            legacy: .value(Data(repeating: 0x41, count: 32)),
            saveStatus: errSecMissingEntitlement
        )
        #expect(makeStore(client: client).sharedKey(peerID: UUID()) == nil)
        if case .value = client.legacy {} else { Issue.record("Lost the original credential") }
        #expect(client.operations == ["load:dataProtection", "load:legacy", "save:dataProtection"])
    }

    @Test("Public legacy device ID moves to preferences without creating another Keychain item")
    func publicIdentity() {
        let id = UUID()
        let client = TestPairingKeychainClient(legacy: .value(Data(id.uuidString.utf8)))
        let persistence = KeychainPairingIdentityPersistence(
            service: "anchor-tests-production-keychain", keychain: .dataProtection, client: client
        )
        if case .value(let data) = persistence.load(account: "local-device-id") {
            #expect(data == Data(id.uuidString.utf8))
        } else { Issue.record("Lost the legacy device identity") }
        #expect(client.operations == ["load:dataProtection", "load:legacy"])
    }
#endif

    private func makeStore(client: TestPairingKeychainClient) -> PairingIdentityStore {
        PairingIdentityStore(persistence: KeychainPairingIdentityPersistence(
            service: "anchor-tests-production-keychain", keychain: .dataProtection, client: client
        ))
    }
}

private final class TestPairingKeychainClient: PairingKeychainClient {
    private struct State: Sendable {
        var modern: PairingIdentityLookup
        var legacy: PairingIdentityLookup
        var operations: [String] = []
    }
    private let state: Mutex<State>
    private let saveStatus: OSStatus

    init(
        modern: PairingIdentityLookup = .missing,
        legacy: PairingIdentityLookup = .missing,
        saveStatus: OSStatus = errSecSuccess
    ) {
        state = Mutex(State(modern: modern, legacy: legacy))
        self.saveStatus = saveStatus
    }

    var operations: [String] { state.withLock { $0.operations } }
    var legacy: PairingIdentityLookup { state.withLock { $0.legacy } }

    func load(service: String, account: String, keychain: PairingIdentityStore.Keychain) -> PairingIdentityLookup {
        state.withLock { state in
            state.operations.append("load:\(keychain)")
            return keychain == .dataProtection ? state.modern : state.legacy
        }
    }

    func save(_ data: Data, service: String, account: String, keychain: PairingIdentityStore.Keychain) -> OSStatus {
        state.withLock { state in
            state.operations.append("save:\(keychain)")
            if saveStatus == errSecSuccess {
                if keychain == .dataProtection { state.modern = .value(data) }
                else { state.legacy = .value(data) }
            }
            return saveStatus
        }
    }
}
