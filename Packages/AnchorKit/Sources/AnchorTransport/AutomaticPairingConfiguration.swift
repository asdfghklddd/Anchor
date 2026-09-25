import Foundation
import Synchronization

private final class AutomaticPairingSecretCache: Sendable {
    private struct State: Sendable {
        var value: Data?
        var isLoading = false
    }

    private let store: AutomaticPairingSecretStore
    private let createIfMissing: Bool
    private let state = Mutex(State())

    init(store: AutomaticPairingSecretStore, createIfMissing: Bool) {
        self.store = store
        self.createIfMissing = createIfMissing
        refreshIfNeeded()
    }

    func current() -> Data? {
        let value = state.withLock { $0.value }
        if value == nil {
            refreshIfNeeded()
        }
        return value
    }

    private func refreshIfNeeded() {
        let shouldLoad = state.withLock { state in
            guard state.value == nil, !state.isLoading else { return false }
            state.isLoading = true
            return true
        }
        guard shouldLoad else { return }

        Task { [weak self] in
            guard let self else { return }
            let secret: Data?
            if createIfMissing {
                secret = await store.loadOrCreateAsync()
            } else {
                secret = await store.loadAsync()
            }
            #if DEBUG
            let role = createIfMissing ? "server" : "client"
            print("[AnchorPairing] \(role) iCloud credential \(secret == nil ? "unavailable" : "ready")")
            #endif
            state.withLock { state in
                state.value = secret
                state.isLoading = false
            }
        }
    }
}

public struct AutomaticPairingConfiguration: Sendable {
    let iCloudSecretProvider: @Sendable () -> Data?

    public init(iCloudSecretProvider: @escaping @Sendable () -> Data?) {
        self.iCloudSecretProvider = iCloudSecretProvider
    }

    public static func macProduction(
        store: AutomaticPairingSecretStore = AutomaticPairingSecretStore()
    ) -> AutomaticPairingConfiguration {
        let cache = AutomaticPairingSecretCache(store: store, createIfMissing: true)
        return AutomaticPairingConfiguration { cache.current() }
    }

    public static func iOSProduction(
        store: AutomaticPairingSecretStore = AutomaticPairingSecretStore()
    ) -> AutomaticPairingConfiguration {
        let cache = AutomaticPairingSecretCache(store: store, createIfMissing: false)
        return AutomaticPairingConfiguration { cache.current() }
    }

    public static let manualOnly = AutomaticPairingConfiguration { nil }
}
