import AnchorCore
import CryptoKit
import Foundation
import Network

public final class AnchorBonjourClient: @unchecked Sendable, PresenceSignalProviding, LocalLinkControlling {
    public var onAcknowledgement: (@Sendable (UUID) -> Void)?

    private let queue = DispatchQueue(label: "com.andywang.anchor.bonjour.client")
    private let identityStore: PairingIdentityStore
    private let deviceID: UUID
    private var browser: NWBrowser?
    private var peer: LineConnection?
    private var peerID: UUID?
    private var pendingCode: String?
    private var pendingPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var heartbeatWorkItem: DispatchWorkItem?
    private var connectionState = ConnectionState.unavailable
    private var proximityState = ProximityState.unknown
    private var continuations: [UUID: AsyncStream<PresenceSignals>.Continuation] = [:]

    public init(identityStore: PairingIdentityStore = PairingIdentityStore()) {
        self.identityStore = identityStore
        deviceID = identityStore.localDeviceID()
    }

    public func startDiscovery() {
        queue.async { [weak self] in self?.startDiscoveryOnQueue() }
    }

    public func stop() {
        queue.async { [weak self] in
            self?.browser?.cancel()
            self?.browser = nil
            self?.peer?.cancel()
            self?.peer = nil
            self?.heartbeatWorkItem?.cancel()
            self?.heartbeatWorkItem = nil
            self?.setConnection(.unavailable)
        }
    }

    public func presenceSignals() -> AsyncStream<PresenceSignals> {
        let id = UUID()
        startDiscovery()
        return AsyncStream { continuation in
            queue.async { [weak self] in
                guard let self else { return }
                self.continuations[id] = continuation
                continuation.yield(self.signals())
            }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.queue.async { [self] in continuations[id] = nil }
            }
        }
    }

    public func currentPairingCode() async -> String? { nil }

    public func pair(using code: String) async throws {
        guard code.count == 6, code.allSatisfy(\.isNumber) else {
            throw AnchorLinkError.invalidPairingCode
        }
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                self?.pendingCode = code
                self?.pendingPrivateKey = Curve25519.KeyAgreement.PrivateKey()
                self?.setConnection(.pairing)
                self?.sendPairRequestIfPossible()
                continuation.resume()
            }
        }
    }

    public func retryConnection() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                self?.peer?.cancel()
                self?.peer = nil
                self?.browser?.cancel()
                self?.browser = nil
                self?.startDiscoveryOnQueue()
                continuation.resume()
            }
        }
    }

    public func updateProximity(_ state: ProximityState) {
        queue.async { [weak self] in
            self?.proximityState = state
            self?.broadcastSignals()
        }
    }

    public func send(_ event: EventEnvelope) throws {
        queue.async { [weak self] in
            guard let self,
                  let peer,
                  let peerID,
                  let key = identityStore.sharedKey(peerID: peerID) else { return }
            let payload = LinkPayload(kind: .event, event: event)
            guard let sealed = try? AnchorLinkCodec.seal(payload, using: key) else { return }
            peer.send(LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed))
        }
    }

    private func startDiscoveryOnQueue() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: AnchorBonjourServer.serviceType, domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.setConnection(.disconnected)
            case .failed: self?.setConnection(.failed)
            case .cancelled: self?.setConnection(.unavailable)
            default: break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let endpoint = results.first?.endpoint else { return }
            self?.connect(to: endpoint)
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func connect(to endpoint: NWEndpoint) {
        guard peer == nil else { return }
        let peer = LineConnection(connection: NWConnection(to: endpoint, using: .tcp), queue: queue)
        self.peer = peer
        peer.start { [weak self] frame in
            self?.handle(frame)
        } onState: { [weak self] state in
            switch state {
            case .waiting: self?.setConnection(.disconnected)
            case .failed, .cancelled:
                self?.peer = nil
                self?.peerID = nil
                self?.heartbeatWorkItem?.cancel()
                self?.heartbeatWorkItem = nil
                self?.setConnection(.disconnected)
            default: break
            }
        }
    }

    private func handle(_ frame: LinkFrame) {
        switch frame.kind {
        case .hello:
            peerID = frame.senderID
            if identityStore.sharedKey(peerID: frame.senderID) != nil {
                setConnection(.connected)
                sendHeartbeat()
            } else {
                sendPairRequestIfPossible()
            }
        case .pairAccepted:
            handlePairAccepted(frame)
        case .encrypted:
            handleEncrypted(frame)
        case .pairRequest:
            break
        }
    }

    private func sendPairRequestIfPossible() {
        guard let peer,
              peerID != nil,
              let pendingCode,
              let pendingPrivateKey else { return }
        peer.send(
            LinkFrame(
                kind: .pairRequest,
                senderID: deviceID,
                publicKey: pendingPrivateKey.publicKey.rawRepresentation,
                pairingCode: pendingCode
            )
        )
    }

    private func handlePairAccepted(_ frame: LinkFrame) {
        guard let publicKey = frame.publicKey,
              let pendingCode,
              let pendingPrivateKey else { return }
        guard let key = try? AnchorLinkCodec.deriveKey(
            privateKey: pendingPrivateKey,
            peerPublicKey: publicKey,
            pairingCode: pendingCode,
            clientID: deviceID,
            serverID: frame.senderID
        ) else { return }
        try? identityStore.saveSharedKey(key, peerID: frame.senderID)
        peerID = frame.senderID
        self.pendingCode = nil
        self.pendingPrivateKey = nil
        setConnection(.connected)
        sendHeartbeat()
    }

    private func handleEncrypted(_ frame: LinkFrame) {
        guard let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID),
              let payload = try? AnchorLinkCodec.open(encrypted, using: key) else { return }
        setConnection(.connected)
        if let eventID = payload.acknowledgedEventID {
            onAcknowledgement?(eventID)
        }
    }

    private func sendHeartbeat() {
        guard let peer, let peerID, let key = identityStore.sharedKey(peerID: peerID) else { return }
        let payload = LinkPayload(kind: .heartbeat)
        guard let sealed = try? AnchorLinkCodec.seal(payload, using: key) else { return }
        peer.send(LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed))
        scheduleHeartbeat()
    }

    private func scheduleHeartbeat() {
        heartbeatWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.sendHeartbeat()
        }
        heartbeatWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 10, execute: workItem)
    }

    private func setConnection(_ state: ConnectionState) {
        connectionState = state
        broadcastSignals()
    }

    private func signals() -> PresenceSignals {
        PresenceSignals(
            posture: .portrait,
            connection: connectionState,
            proximity: proximityState,
            observedAt: .now
        )
    }

    private func broadcastSignals() {
        let value = signals()
        for continuation in continuations.values { continuation.yield(value) }
    }
}
