import AnchorCore
import CryptoKit
import Foundation
import Network

public final class AnchorBonjourClient: @unchecked Sendable, PresenceSignalProviding, LocalLinkControlling, AnchorEventTransport {
    private typealias OperationContinuation = CheckedContinuation<Void, any Error>

    private struct PendingDelivery {
        let continuation: OperationContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    private static let heartbeatInterval: TimeInterval = 10
    private static let heartbeatResponseTimeout: TimeInterval = 5
    private static let operationTimeout: TimeInterval = 10
    private static let reconnectDelay: TimeInterval = 1

    private let queue = DispatchQueue(label: "com.andywang.anchor.bonjour.client")
    private let identityStore: PairingIdentityStore
    private let deviceID: UUID
    private var browser: NWBrowser?
    private var discoveredEndpoint: NWEndpoint?
    private var peer: LineConnection?
    private var peerID: UUID?
    private var pendingCode: String?
    private var pendingPrivateKey: Curve25519.KeyAgreement.PrivateKey?
    private var pairingContinuation: OperationContinuation?
    private var pairingTimeoutWorkItem: DispatchWorkItem?
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var eventApplicationTask: Task<Void, Never>?
    private var heartbeatSendWorkItem: DispatchWorkItem?
    private var heartbeatTimeoutWorkItem: DispatchWorkItem?
    private var heartbeatGeneration: UInt64 = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var replayWindow = LinkReplayWindow()
    private var connectionState = ConnectionState.unavailable
    private var proximityState = ProximityState.unknown
    private var continuations: [UUID: AsyncStream<PresenceSignals>.Continuation] = [:]

    /// These callbacks are invoked on the client's serial queue. The queue is
    /// the isolation boundary for all mutable Network.framework state.
    public var onEvent: (@Sendable (EventEnvelope) async throws -> Void)?
    public var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    public init(identityStore: PairingIdentityStore = PairingIdentityStore()) {
        self.identityStore = identityStore
        deviceID = identityStore.localDeviceID()
    }

    public func startDiscovery() {
        queue.async { [weak self] in self?.startDiscoveryOnQueue() }
    }

    public func stop() {
        queue.sync { [weak self] in
            guard let self else { return }
            self.browser?.cancel()
            self.browser = nil
            self.discoveredEndpoint = nil
            self.peer?.cancel()
            self.peer = nil
            self.peerID = nil
            self.reconnectWorkItem?.cancel()
            self.reconnectWorkItem = nil
            self.cancelHeartbeatTimers()
            self.eventApplicationTask?.cancel()
            self.eventApplicationTask = nil
            self.finishPairing(with: .failure(CancellationError()))
            self.failAllDeliveries(with: CancellationError())
            self.setConnection(.unavailable)
        }
    }

    public func presenceSignals() -> AsyncStream<PresenceSignals> {
        let id = UUID()
        startDiscovery()
        return AsyncStream { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
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
        guard code.utf8.count == 6,
              code.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw AnchorLinkError.invalidPairingCode
        }
        try await withCheckedThrowingContinuation { (continuation: OperationContinuation) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard self.pairingContinuation == nil else {
                    continuation.resume(throwing: AnchorLinkError.operationInProgress)
                    return
                }
                if self.connectionState == .connected {
                    continuation.resume(returning: ())
                    return
                }

                self.pairingContinuation = continuation
                self.pendingCode = code
                self.pendingPrivateKey = Curve25519.KeyAgreement.PrivateKey()
                self.setConnection(.pairing)
                self.schedulePairingTimeout()
                self.sendPairRequestIfPossible()
            }
        }
    }

    public func retryConnection() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                self.finishPairing(with: .failure(AnchorLinkError.connectionLost))
                self.failAllDeliveries(with: AnchorLinkError.connectionLost)
                self.cancelHeartbeatTimers()
                self.reconnectWorkItem?.cancel()
                self.reconnectWorkItem = nil
                self.peer?.cancel()
                self.peer = nil
                self.peerID = nil
                self.browser?.cancel()
                self.browser = nil
                self.discoveredEndpoint = nil
                self.startDiscoveryOnQueue()
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

    public func setEventHandler(
        _ handler: (@Sendable (EventEnvelope) async throws -> Void)?
    ) {
        queue.async { [weak self] in self?.onEvent = handler }
    }

    public func setConnectionStateHandler(
        _ handler: (@Sendable (ConnectionState) -> Void)?
    ) {
        queue.async { [weak self] in self?.onConnectionState = handler }
    }

    public func send(_ event: EventEnvelope) async throws {
        try await withCheckedThrowingContinuation { (continuation: OperationContinuation) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard self.connectionState == .connected,
                      let peer = self.peer,
                      let peerID = self.peerID,
                      let key = self.identityStore.sharedKey(peerID: peerID) else {
                    continuation.resume(throwing: AnchorLinkError.notPaired)
                    return
                }
                guard self.pendingDeliveries[event.id] == nil else {
                    continuation.resume(throwing: AnchorLinkError.operationInProgress)
                    return
                }

                do {
                    let payload = LinkPayload(kind: .event, event: event)
                    let sealed = try AnchorLinkCodec.seal(payload, using: key)
                    let timeout = DispatchWorkItem { [weak self] in
                        self?.finishDelivery(
                            event.id,
                            with: .failure(AnchorLinkError.acknowledgementTimedOut)
                        )
                    }
                    self.pendingDeliveries[event.id] = PendingDelivery(
                        continuation: continuation,
                        timeoutWorkItem: timeout
                    )
                    self.queue.asyncAfter(deadline: .now() + Self.operationTimeout, execute: timeout)
                    peer.send(
                        LinkFrame(kind: .encrypted, senderID: self.deviceID, encryptedPayload: sealed)
                    ) { [weak self] result in
                        if case let .failure(error) = result {
                            self?.finishDelivery(event.id, with: .failure(error))
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func startDiscoveryOnQueue() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: AnchorBonjourServer.serviceType, domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, self.browser === browser else { return }
            switch state {
            case .ready:
                if self.connectionState != .connected { self.setConnection(.disconnected) }
            case .failed:
                self.setConnection(.failed)
                self.browser?.cancel()
                self.browser = nil
            case .cancelled:
                if self.connectionState != .connected { self.setConnection(.unavailable) }
            default:
                break
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            self.discoveredEndpoint = results.first?.endpoint
            if let endpoint = self.discoveredEndpoint, self.peer == nil {
                self.connect(to: endpoint)
            }
        }
        self.browser = browser
        browser.start(queue: queue)
    }

    private func connect(to endpoint: NWEndpoint) {
        guard peer == nil else { return }
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        let peer = LineConnection(connection: NWConnection(to: endpoint, using: .tcp), queue: queue)
        self.peer = peer
        peer.start { [weak self, weak peer] frame in
            guard let self, let peer, self.peer === peer else { return }
            self.handle(frame)
        } onState: { [weak self, weak peer] state in
            guard let self, let peer, self.peer === peer else { return }
            switch state {
            case .waiting:
                self.setConnection(.disconnected)
            case .failed, .cancelled:
                self.peer = nil
                self.peerID = nil
                self.cancelHeartbeatTimers()
                self.finishPairing(with: .failure(AnchorLinkError.connectionLost))
                self.failAllDeliveries(with: AnchorLinkError.connectionLost)
                self.setConnection(.disconnected)
                self.scheduleReconnect()
            default:
                break
            }
        }
    }

    private func scheduleReconnect() {
        guard reconnectWorkItem == nil, let endpoint = discoveredEndpoint else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            if self.peer == nil { self.connect(to: endpoint) }
        }
        reconnectWorkItem = workItem
        queue.asyncAfter(deadline: .now() + Self.reconnectDelay, execute: workItem)
    }

    private func handle(_ frame: LinkFrame) {
        switch frame.kind {
        case .hello:
            peerID = frame.senderID
            if identityStore.sharedKey(peerID: frame.senderID) != nil {
                pendingCode = nil
                pendingPrivateKey = nil
                setConnection(.pairing)
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
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.failPairing(with: error)
            }
        }
    }

    private func handlePairAccepted(_ frame: LinkFrame) {
        guard frame.senderID == peerID,
              let publicKey = frame.publicKey,
              let pendingCode,
              let pendingPrivateKey else { return }
        do {
            let key = try AnchorLinkCodec.deriveKey(
                privateKey: pendingPrivateKey,
                peerPublicKey: publicKey,
                pairingCode: pendingCode,
                clientID: deviceID,
                serverID: frame.senderID
            )
            try identityStore.saveSharedKey(key, peerID: frame.senderID)
            peerID = frame.senderID
            setConnection(.pairing)
            sendHeartbeat()
        } catch {
            failPairing(with: error)
        }
    }

    private func handleEncrypted(_ frame: LinkFrame) {
        guard frame.senderID == peerID,
              let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID) else { return }
        do {
            let payload = try AnchorLinkCodec.open(encrypted, using: key)
            didAuthenticatePeer()
            guard replayWindow.accepts(payload.messageID) else {
                if payload.kind == .event,
                   let event = payload.event,
                   let peer = self.peer {
                    sendEncryptedAcknowledgement(for: event.id, using: key, to: peer)
                }
                return
            }
            if payload.kind == .acknowledgement, let eventID = payload.acknowledgedEventID {
                finishDelivery(eventID, with: .success(()))
                return
            }
            if payload.kind == .event,
               let event = payload.event,
               let onEvent {
                let precedingTask = eventApplicationTask
                eventApplicationTask = Task { [weak self, weak peer = self.peer] in
                    await precedingTask?.value
                    guard !Task.isCancelled else { return }
                    do {
                        try await onEvent(event)
                    } catch {
                        return
                    }
                    guard let self, let peer else { return }
                    self.queue.async { [weak self, weak peer] in
                        guard let self,
                              let peer,
                              self.peer === peer,
                              let peerID = self.peerID,
                              let key = self.identityStore.sharedKey(peerID: peerID) else { return }
                        self.sendEncryptedAcknowledgement(for: event.id, using: key, to: peer)
                    }
                }
            }
        } catch {
            return
        }
    }

    private func sendHeartbeat() {
        heartbeatSendWorkItem?.cancel()
        heartbeatSendWorkItem = nil
        heartbeatTimeoutWorkItem?.cancel()
        heartbeatTimeoutWorkItem = nil
        heartbeatGeneration &+= 1
        let generation = heartbeatGeneration

        guard let peer, let peerID, let key = identityStore.sharedKey(peerID: peerID) else {
            setConnection(.disconnected)
            return
        }
        do {
            let sealed = try AnchorLinkCodec.seal(LinkPayload(kind: .heartbeat), using: key)
            peer.send(
                LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed)
            ) { [weak self] result in
                guard case let .failure(error) = result else { return }
                self?.heartbeatSendFailed(error, generation: generation)
            }
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, self.heartbeatGeneration == generation else { return }
                self.heartbeatTimeoutWorkItem = nil
                self.setConnection(.disconnected)
                self.scheduleHeartbeat()
            }
            heartbeatTimeoutWorkItem = timeout
            queue.asyncAfter(deadline: .now() + Self.heartbeatResponseTimeout, execute: timeout)
        } catch {
            heartbeatSendFailed(error, generation: generation)
        }
    }

    private func heartbeatSendFailed(_ error: any Error, generation: UInt64) {
        guard heartbeatGeneration == generation else { return }
        heartbeatTimeoutWorkItem?.cancel()
        heartbeatTimeoutWorkItem = nil
        setConnection(.disconnected)
        failAllDeliveries(with: error)
        scheduleHeartbeat()
    }

    private func didAuthenticatePeer() {
        setConnection(.connected)
        finishPairing(with: .success(()))
        scheduleHeartbeat()
    }

    private func scheduleHeartbeat() {
        heartbeatSendWorkItem?.cancel()
        heartbeatSendWorkItem = nil
        heartbeatTimeoutWorkItem?.cancel()
        heartbeatTimeoutWorkItem = nil
        heartbeatGeneration &+= 1
        let generation = heartbeatGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.heartbeatGeneration == generation else { return }
            self.heartbeatSendWorkItem = nil
            self.sendHeartbeat()
        }
        heartbeatSendWorkItem = workItem
        queue.asyncAfter(deadline: .now() + Self.heartbeatInterval, execute: workItem)
    }

    private func cancelHeartbeatTimers() {
        heartbeatGeneration &+= 1
        heartbeatSendWorkItem?.cancel()
        heartbeatSendWorkItem = nil
        heartbeatTimeoutWorkItem?.cancel()
        heartbeatTimeoutWorkItem = nil
    }

    private func schedulePairingTimeout() {
        pairingTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.failPairing(with: AnchorLinkError.pairingTimedOut)
        }
        pairingTimeoutWorkItem = workItem
        queue.asyncAfter(deadline: .now() + Self.operationTimeout, execute: workItem)
    }

    private func failPairing(with error: any Error) {
        setConnection(.failed)
        finishPairing(with: .failure(error))
    }

    private func finishPairing(with result: Result<Void, any Error>) {
        guard let continuation = pairingContinuation else { return }
        pairingContinuation = nil
        pairingTimeoutWorkItem?.cancel()
        pairingTimeoutWorkItem = nil
        pendingCode = nil
        pendingPrivateKey = nil
        continuation.resume(with: result)
    }

    private func finishDelivery(_ id: UUID, with result: Result<Void, any Error>) {
        guard let delivery = pendingDeliveries.removeValue(forKey: id) else { return }
        delivery.timeoutWorkItem.cancel()
        delivery.continuation.resume(with: result)
    }

    private func failAllDeliveries(with error: any Error) {
        for id in Array(pendingDeliveries.keys) {
            finishDelivery(id, with: .failure(error))
        }
    }

    private func setConnection(_ state: ConnectionState) {
        guard connectionState != state else { return }
        connectionState = state
        onConnectionState?(state)
        broadcastSignals()
    }

    private func sendEncryptedAcknowledgement(
        for eventID: UUID,
        using key: Data,
        to peer: LineConnection
    ) {
        let acknowledgement = LinkPayload(
            kind: .acknowledgement,
            acknowledgedEventID: eventID
        )
        guard let sealed = try? AnchorLinkCodec.seal(acknowledgement, using: key) else { return }
        peer.send(LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed))
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
