import Foundation
import Security
import Synchronization
import Testing
@testable import AnchorTransport

@Suite("Background pairing identity")
struct PairingIdentityStoreTests {
    @Test("Denied legacy identity is not overwritten and the fallback survives restart")
    func deniedDeviceIdentity() {
        let persistence = TestPairingPersistence(lookup: .unavailable(errSecInteractionNotAllowed))
        let store = PairingIdentityStore(persistence: persistence)
        let id = store.localDeviceID()
        for _ in 0..<100 { #expect(store.localDeviceID() == id) }
        #expect(PairingIdentityStore(persistence: persistence).localDeviceID() == id)
        #expect(persistence.counts == [1, 0])
    }

    @Test("Readable legacy identity is retained without rewriting its Keychain item")
    func legacyDeviceIdentity() {
        let id = UUID()
        let persistence = TestPairingPersistence(lookup: .value(Data(id.uuidString.utf8)))
        #expect(PairingIdentityStore(persistence: persistence).localDeviceID() == id)
        #expect(PairingIdentityStore(persistence: persistence).localDeviceID() == id)
        #expect(persistence.counts == [1, 0])
    }

    @Test("Concurrent heartbeats share one denied Keychain lookup")
    func deniedPeerKey() async {
        let persistence = TestPairingPersistence(lookup: .unavailable(errSecAuthFailed))
        let store = PairingIdentityStore(persistence: persistence)
        let peerID = UUID()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask { #expect(store.sharedKey(peerID: peerID) == nil) }
            }
        }
        #expect(persistence.counts == [1, 0])
    }

    @Test("Successful pairing replaces a cached missing key and failed writes propagate")
    func pairingUpdatesCache() throws {
        let persistence = TestPairingPersistence(lookup: .missing)
        let store = PairingIdentityStore(persistence: persistence)
        let peerID = UUID()
        let key = Data(repeating: 0x32, count: 32)
        #expect(store.sharedKey(peerID: peerID) == nil)
        try store.saveSharedKey(key, peerID: peerID)
        for _ in 0..<100 { #expect(store.sharedKey(peerID: peerID) == key) }
        #expect(persistence.counts == [1, 1])

        let denied = TestPairingPersistence(lookup: .missing, saveStatus: errSecInteractionNotAllowed)
        let deniedStore = PairingIdentityStore(persistence: denied)
        #expect(throws: NSError.self) { try deniedStore.saveSharedKey(key, peerID: peerID) }
        #expect(deniedStore.sharedKey(peerID: peerID) == nil)
    }

    @Test("Validation credentials stay within the isolated store")
    func inMemoryIdentity() throws {
        let store = PairingIdentityStore.inMemory()
        let copy = store
        let other = PairingIdentityStore.inMemory()
        let peerID = UUID()
        let key = Data(repeating: 0x21, count: 32)
        try store.saveSharedKey(key, peerID: peerID)
        #expect(copy.localDeviceID() == store.localDeviceID())
        #expect(copy.sharedKey(peerID: peerID) == key)
        #expect(other.sharedKey(peerID: peerID) == nil)
        #expect(other.localDeviceID() != store.localDeviceID())
    }

#if os(macOS)
    @Test("Locked legacy Keychain reads and writes fail without opening authorization UI")
    func lockedLegacyKeychain() throws {
        let url = URL.temporaryDirectory.appending(path: "anchor-keychain-test-\(UUID().uuidString).keychain")
        let password = "disposable-test-keychain"
        var keychain: SecKeychain?
        let createStatus = password.withCString { bytes in
            SecKeychainCreate(url.path, UInt32(password.utf8.count), bytes, false, nil, &keychain)
        }
        #expect(createStatus == errSecSuccess)
        let testKeychain = try #require(keychain)
        defer {
            _ = password.withCString { bytes in
                SecKeychainUnlock(testKeychain, UInt32(password.utf8.count), bytes, true)
            }
            SecKeychainDelete(testKeychain)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "anchor-disposable-keychain-test",
            kSecAttrAccount as String: "test-peer",
            kSecUseKeychain as String: testKeychain,
        ]
        #expect(NoninteractiveKeychain.add(query.merging([
            kSecValueData as String: Data("test-secret".utf8),
        ]) { _, replacement in replacement }) == errSecSuccess)
        #expect(SecKeychainLock(testKeychain) == errSecSuccess)
        // Search only the disposable keychain; never the user's login items.
        var search = query
        search.removeValue(forKey: kSecUseKeychain as String)
        search[kSecMatchSearchList as String] = [testKeychain]
        search[kSecReturnData as String] = true
        var result: CFTypeRef?
        var interactionAllowed = DarwinBoolean(true)
        #expect(SecKeychainGetUserInteractionAllowed(&interactionAllowed) == errSecSuccess)
        #expect(!interactionAllowed.boolValue)
        // Legacy macOS versions can report either authentication failure or
        // interaction-not-allowed when a locked keychain cannot display UI.
        let failureStatuses = [errSecInteractionNotAllowed, errSecAuthFailed]
        let readStatus = NoninteractiveKeychain.copyMatching(search, result: &result)
        #expect(failureStatuses.contains(readStatus))
        search.removeValue(forKey: kSecReturnData as String)
        let updateStatus = NoninteractiveKeychain.update(search, attributes: [
            kSecValueData as String: Data("replacement".utf8),
        ])
        #expect(failureStatuses.contains(updateStatus))
    }
#endif
}

private final class TestPairingPersistence: PairingIdentityPersistence {
    private struct State: Sendable {
        var reads = 0
        var writes = 0
        var deviceID: UUID?
    }
    private let state = Mutex(State())
    private let lookup: PairingIdentityLookup
    private let saveStatus: OSStatus

    init(lookup: PairingIdentityLookup, saveStatus: OSStatus = errSecSuccess) {
        self.lookup = lookup
        self.saveStatus = saveStatus
    }

    var counts: [Int] { state.withLock { [$0.reads, $0.writes] } }
    func load(account: String) -> PairingIdentityLookup {
        state.withLock { $0.reads += 1 }
        return lookup
    }
    func save(_ data: Data, account: String) -> OSStatus {
        state.withLock { $0.writes += 1 }
        return saveStatus
    }
    func deviceID() -> UUID? { state.withLock { $0.deviceID } }
    func saveDeviceID(_ id: UUID) { state.withLock { $0.deviceID = id } }
}
