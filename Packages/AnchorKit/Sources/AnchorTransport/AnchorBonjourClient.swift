import AnchorCore
import CryptoKit
import Foundation
import Network

public final class AnchorBonjourClient: @unchecked Sendable, PresenceSignalProviding, LocalLinkControlling, AnchorEventTransport, CurrentProcessProviding {
    private typealias OperationContinuation = CheckedContinuation<Void, any Error>
    private typealias SnapshotContinuation = CheckedContinuation<CurrentProcessSnapshot, any Error>

    private struct PendingDelivery {
        let continuation: OperationContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    private struct PendingSnapshotRequest {
        let continuation: SnapshotContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    private struct PairingAttempt {
        let method: PairingBootstrapMethod
        let secret: Data
        let privateKey: Curve25519.KeyAgreement.PrivateKey
    }

    private static let heartbeatInterval: TimeInterval = 10
    private static let heartbeatResponseTimeout: TimeInterval = 5
    private static let operationTimeout: TimeInterval = 10
    private static let reconnectDelay: TimeInterval = 1
    private static let automaticCredentialWait: TimeInterval = 1
    private static let automaticCredentialCheckLimit = 12
    private static let automaticAttemptTimeout: TimeInterval = 2

    private let queue = DispatchQueue(label: "com.andywang.anchor.bonjour.client")
    private let identityStore: PairingIdentityStore
    private let automaticPairing: AutomaticPairingConfiguration
    private let deviceID: UUID
    private let serviceType: String
    private var browser: NWBrowser?
    private var discoveredEndpoint: NWEndpoint?
    private var peer: LineConnection?
    private var peerID: UUID?
    private var peerChallenge: Data?
    private var bluetoothPairingSecrets: [UUID: Data] = [:]
    private var pairingAttempt: PairingAttempt?
    private var attemptedAutomaticMethods: Set<PairingBootstrapMethod> = []
    private var authenticatedRoute: DevicePairingRoute = .trustedDevice
    private var pairingContinuation: OperationContinuation?
    private var pairingTimeoutWorkItem: DispatchWorkItem?
    private var automaticPairingWorkItem: DispatchWorkItem?
    private var automaticCredentialChecksRemaining = 0
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var pendingSnapshotRequests: [UUID: PendingSnapshotRequest] = [:]
    private var eventApplicationTask: Task<Void, Never>?
    private var heartbeatSendWorkItem: DispatchWorkItem?
    private var heartbeatTimeoutWorkItem: DispatchWorkItem?
    private var heartbeatGeneration: UInt64 = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var replayWindow = LinkReplayWindow()
    private var connectionState = ConnectionState.unavailable
    private var fallbackConnectionState = ConnectionState.unavailable
    private var publishedConnectionState = ConnectionState.unavailable
    private var proximityState = ProximityState.unknown
    private var continuations: [UUID: AsyncStream<PresenceSignals>.Continuation] = [:]
    private var pairingStatus = DevicePairingStatus.automatic
    private var pairingStatusContinuations: [UUID: AsyncStream<DevicePairingStatus>.Continuation] = [:]

    /// These callbacks are invoked on the client's serial queue. The queue is
    /// the isolation boundary for all mutable Network.framework state.
    public var onEvent: (@Sendable (EventEnvelope) async throws -> Void)?
    public var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    public init(
        identityStore: PairingIdentityStore = PairingIdentityStore(),
        automaticPairing: AutomaticPairingConfiguration = .iOSProduction(),
        serviceType: String = AnchorBonjourServer.serviceType
    ) {
        self.identityStore = identityStore
        self.automaticPairing = automaticPairing
        self.serviceType = serviceType
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
            self.peerChallenge = nil
            self.reconnectWorkItem?.cancel()
            self.reconnectWorkItem = nil
            self.cancelHeartbeatTimers()
            self.cancelAutomaticPairingWork()
            self.eventApplicationTask?.cancel()
            self.eventApplicationTask = nil
            self.finishPairing(with: .failure(CancellationError()))
            self.failAllDeliveries(with: CancellationError())
            self.failAllSnapshotRequests(with: CancellationError())
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

    public func pairingStatusUpdates() -> AsyncStream<DevicePairingStatus> {
        let id = UUID()
        return AsyncStream { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }
                pairingStatusContinuations[id] = continuation
                continuation.yield(pairingStatus)
            }
            continuation.onTermination = { [weak self] _ in
                self?.queue.async { [weak self] in
                    self?.pairingStatusContinuations[id] = nil
                }
            }
        }
    }

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
                if self.effectiveConnectionState == .connected {
                    continuation.resume(returning: ())
                    return
                }

                self.pairingContinuation = continuation
                self.cancelAutomaticPairingWork()
                self.pairingAttempt = PairingAttempt(
                    method: .verificationCode,
                    secret: Data(code.utf8),
                    privateKey: Curve25519.KeyAgreement.PrivateKey()
                )
                self.setPairingStatus(.verificationCodeRequired)
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
                self.failAllSnapshotRequests(with: AnchorLinkError.connectionLost)
                self.cancelHeartbeatTimers()
                self.cancelAutomaticPairingWork()
                self.reconnectWorkItem?.cancel()
                self.reconnectWorkItem = nil
                self.peer?.cancel()
                self.peer = nil
                self.peerID = nil
                self.peerChallenge = nil
                self.browser?.cancel()
                self.browser = nil
                self.discoveredEndpoint = nil
                self.setPairingStatus(.automatic)
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

    /// Reports the authenticated BLE data channel without changing the TCP
    /// state used by the primary sender. UI and presence observe the effective
    /// state across both transports.
    public func updateFallbackConnection(_ state: ConnectionState) {
        queue.async { [weak self] in
            guard let self, fallbackConnectionState != state else { return }
            fallbackConnectionState = state
            if state == .connected, connectionState != .connected {
                setPairingStatus(DevicePairingStatus(phase: .connected, route: .bluetooth))
            } else if connectionState != .connected, pairingStatus.phase == .connected {
                setPairingStatus(.automatic)
            }
            publishEffectiveConnection()
        }
    }

    public func offerBluetoothPairingSecret(_ secret: Data, for peerID: UUID) {
        guard secret.count == 32 else { return }
        queue.async { [weak self] in
            guard let self else { return }
            bluetoothPairingSecrets[peerID] = secret
            guard self.peerID == peerID,
                  connectionState != .connected,
                  pairingContinuation == nil,
                  pairingAttempt == nil,
                  !attemptedAutomaticMethods.contains(.bluetooth) else { return }
            cancelAutomaticPairingWork()
            beginPairing(method: .bluetooth, secret: secret)
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

    public func currentProcessSnapshot() async throws -> CurrentProcessSnapshot {
        try await withCheckedThrowingContinuation { (continuation: SnapshotContinuation) in
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

                let requestID = UUID()
                do {
                    let payload = LinkPayload(
                        kind: .processSnapshotRequest,
                        requestID: requestID
                    )
                    let sealed = try AnchorLinkCodec.seal(payload, using: key)
                    let timeout = DispatchWorkItem { [weak self] in
                        self?.finishSnapshot(
                            requestID,
                            with: .failure(AnchorLinkError.processSnapshotTimedOut)
                        )
                    }
                    self.pendingSnapshotRequests[requestID] = PendingSnapshotRequest(
                        continuation: continuation,
                        timeoutWorkItem: timeout
                    )
                    self.queue.asyncAfter(
                        deadline: .now() + Self.operationTimeout,
                        execute: timeout
                    )
                    peer.send(
                        LinkFrame(
                            kind: .encrypted,
                            senderID: self.deviceID,
                            encryptedPayload: sealed
                        )
                    ) { [weak self] result in
                        if case let .failure(error) = result {
                            self?.finishSnapshot(requestID, with: .failure(error))
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
        let parameters = AnchorNearbyNetwork.tcpParameters()
        let browser = NWBrowser(
            for: .bonjour(type: serviceType, domain: nil),
            using: parameters
        )
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, self.browser === browser else { return }
            #if DEBUG
            print("[AnchorPairing] Bonjour browser state \(String(describing: state))")
            #endif
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
            #if DEBUG
            print("[AnchorPairing] Bonjour results \(results.count)")
            #endif
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
        let peer = LineConnection(
            connection: NWConnection(
                to: endpoint,
                using: AnchorNearbyNetwork.tcpParameters()
            ),
            queue: queue
        )
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
                self.peerChallenge = nil
                self.cancelHeartbeatTimers()
                self.cancelAutomaticPairingWork()
                self.finishPairing(with: .failure(AnchorLinkError.connectionLost))
                self.failAllDeliveries(with: AnchorLinkError.connectionLost)
                self.failAllSnapshotRequests(with: AnchorLinkError.connectionLost)
                self.setConnection(.disconnected)
                self.setPairingStatus(.automatic)
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
            self.peerID = frame.senderID
            peerChallenge = frame.challenge
            if identityStore.sharedKey(peerID: frame.senderID) != nil {
                pairingAttempt = nil
                authenticatedRoute = .trustedDevice
                setConnection(.pairing)
                sendHeartbeat()
            } else if pairingAttempt != nil {
                sendPairRequestIfPossible()
            } else {
                beginAutomaticPairing()
            }
        case .pairAccepted:
            handlePairAccepted(frame)
        case .fallbackRequested:
            break
        case .encrypted:
            handleEncrypted(frame)
        case .pairRequest:
            break
        }
    }

    private func beginAutomaticPairing() {
        cancelAutomaticPairingWork()
        attemptedAutomaticMethods.removeAll()
        automaticCredentialChecksRemaining = Self.automaticCredentialCheckLimit
        setPairingStatus(.automatic)
        setConnection(.pairing)
        attemptNextAutomaticMethodOrScheduleFallback()
    }

    private func beginPairing(method: PairingBootstrapMethod, secret: Data) {
        #if DEBUG
        print("[AnchorPairing] attempting \(method.rawValue)")
        #endif
        attemptedAutomaticMethods.insert(method)
        pairingAttempt = PairingAttempt(
            method: method,
            secret: secret,
            privateKey: Curve25519.KeyAgreement.PrivateKey()
        )
        setConnection(.pairing)
        sendPairRequestIfPossible()
        scheduleAutomaticAttemptTimeout(for: method)
    }

    private func scheduleAutomaticAttemptTimeout(for method: PairingBootstrapMethod) {
        automaticPairingWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  pairingContinuation == nil,
                  pairingAttempt?.method == method else { return }
            pairingAttempt = nil
            if method == .iCloud {
                scheduleVerificationCodeFallback(after: Self.automaticCredentialWait)
            } else {
                exposeVerificationCodeFallback()
            }
        }
        automaticPairingWorkItem = workItem
        queue.asyncAfter(deadline: .now() + Self.automaticAttemptTimeout, execute: workItem)
    }

    private func scheduleVerificationCodeFallback(after delay: TimeInterval) {
        automaticPairingWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  pairingContinuation == nil,
                  pairingAttempt == nil else { return }
            attemptNextAutomaticMethodOrExposeFallback()
        }
        automaticPairingWorkItem = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func attemptNextAutomaticMethodOrScheduleFallback() {
        if let secret = automaticPairing.iCloudSecretProvider(),
           secret.count == 32,
           !attemptedAutomaticMethods.contains(.iCloud) {
            beginPairing(method: .iCloud, secret: secret)
            return
        }
        if let peerID,
           let secret = bluetoothPairingSecrets[peerID],
           !attemptedAutomaticMethods.contains(.bluetooth) {
            beginPairing(method: .bluetooth, secret: secret)
            return
        }
        scheduleVerificationCodeFallback(after: Self.automaticCredentialWait)
    }

    private func attemptNextAutomaticMethodOrExposeFallback() {
        if let secret = automaticPairing.iCloudSecretProvider(),
           secret.count == 32,
           !attemptedAutomaticMethods.contains(.iCloud) {
            beginPairing(method: .iCloud, secret: secret)
            return
        }
        if let peerID,
           let secret = bluetoothPairingSecrets[peerID],
           !attemptedAutomaticMethods.contains(.bluetooth) {
            beginPairing(method: .bluetooth, secret: secret)
            return
        }
        if automaticCredentialChecksRemaining > 0 {
            automaticCredentialChecksRemaining -= 1
            scheduleVerificationCodeFallback(after: Self.automaticCredentialWait)
            return
        }
        exposeVerificationCodeFallback()
    }

    private func exposeVerificationCodeFallback() {
        #if DEBUG
        let attempted = attemptedAutomaticMethods.map(\.rawValue).sorted().joined(separator: ",")
        print("[AnchorPairing] fallback after [\(attempted)]")
        #endif
        automaticPairingWorkItem?.cancel()
        automaticPairingWorkItem = nil
        automaticCredentialChecksRemaining = 0
        pairingAttempt = nil
        peer?.send(LinkFrame(kind: .fallbackRequested, senderID: deviceID))
        setPairingStatus(.verificationCodeRequired)
        setConnection(.disconnected)
    }

    private func cancelAutomaticPairingWork() {
        automaticPairingWorkItem?.cancel()
        automaticPairingWorkItem = nil
        automaticCredentialChecksRemaining = 0
        if pairingContinuation == nil {
            pairingAttempt = nil
        }
    }

    private func sendPairRequestIfPossible() {
        guard let peer,
              let peerID,
              let challenge = peerChallenge,
              let pairingAttempt else { return }
        let publicKey = pairingAttempt.privateKey.publicKey.rawRepresentation
        let proof = AnchorLinkCodec.pairingProof(
            secret: pairingAttempt.secret,
            method: pairingAttempt.method,
            role: "client",
            clientID: deviceID,
            serverID: peerID,
            clientPublicKey: publicKey,
            challenge: challenge
        )
        peer.send(
            LinkFrame(
                kind: .pairRequest,
                senderID: deviceID,
                publicKey: publicKey,
                pairingMethod: pairingAttempt.method,
                pairingProof: proof
            )
        ) { [weak self] result in
            if case let .failure(error) = result {
                self?.handlePairingRequestFailure(error)
            }
        }
    }

    private func handlePairAccepted(_ frame: LinkFrame) {
        guard frame.senderID == peerID,
              let publicKey = frame.publicKey,
              let peerID,
              let challenge = peerChallenge,
              let proof = frame.pairingProof,
              let pairingAttempt,
              frame.pairingMethod == pairingAttempt.method,
              AnchorLinkCodec.validatesPairingProof(
                  proof,
                  secret: pairingAttempt.secret,
                  method: pairingAttempt.method,
                  role: "server",
                  clientID: deviceID,
                  serverID: peerID,
                  clientPublicKey: pairingAttempt.privateKey.publicKey.rawRepresentation,
                  serverPublicKey: publicKey,
                  challenge: challenge
              ) else { return }
        do {
            let key = try AnchorLinkCodec.deriveKey(
                privateKey: pairingAttempt.privateKey,
                peerPublicKey: publicKey,
                pairingSecret: pairingAttempt.secret,
                clientID: deviceID,
                serverID: frame.senderID
            )
            try identityStore.saveSharedKey(key, peerID: frame.senderID)
            authenticatedRoute = pairingAttempt.method.route
            automaticPairingWorkItem?.cancel()
            automaticPairingWorkItem = nil
            self.peerID = frame.senderID
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
            if payload.kind == .processSnapshotResponse, let requestID = payload.requestID {
                if let snapshot = payload.currentProcessSnapshot {
                    finishSnapshot(requestID, with: .success(snapshot))
                } else {
                    finishSnapshot(
                        requestID,
                        with: .failure(AnchorLinkError.processSnapshotUnavailable)
                    )
                }
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
        failAllSnapshotRequests(with: error)
        scheduleHeartbeat()
    }

    private func didAuthenticatePeer() {
        cancelAutomaticPairingWork()
        setConnection(.connected)
        setPairingStatus(DevicePairingStatus(phase: .connected, route: authenticatedRoute))
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

    private func handlePairingRequestFailure(_ error: any Error) {
        if pairingContinuation != nil {
            failPairing(with: error)
        } else {
            pairingAttempt = nil
            exposeVerificationCodeFallback()
        }
    }

    private func finishPairing(with result: Result<Void, any Error>) {
        let continuation = pairingContinuation
        pairingContinuation = nil
        pairingTimeoutWorkItem?.cancel()
        pairingTimeoutWorkItem = nil
        pairingAttempt = nil
        continuation?.resume(with: result)
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

    private func finishSnapshot(
        _ requestID: UUID,
        with result: Result<CurrentProcessSnapshot, any Error>
    ) {
        guard let request = pendingSnapshotRequests.removeValue(forKey: requestID) else { return }
        request.timeoutWorkItem.cancel()
        request.continuation.resume(with: result)
    }

    private func failAllSnapshotRequests(with error: any Error) {
        for requestID in Array(pendingSnapshotRequests.keys) {
            finishSnapshot(requestID, with: .failure(error))
        }
    }

    private func setConnection(_ state: ConnectionState) {
        guard connectionState != state else { return }
        connectionState = state
        if state != .connected, fallbackConnectionState == .connected {
            setPairingStatus(DevicePairingStatus(phase: .connected, route: .bluetooth))
        } else if effectiveConnectionState != .connected, pairingStatus.phase == .connected {
            setPairingStatus(.automatic)
        }
        publishEffectiveConnection()
    }

    private var effectiveConnectionState: ConnectionState {
        if connectionState == .connected || fallbackConnectionState == .connected {
            return .connected
        }
        if connectionState == .pairing { return .pairing }
        if connectionState == .failed, fallbackConnectionState == .failed { return .failed }
        if connectionState == .permissionDenied,
           fallbackConnectionState == .permissionDenied {
            return .permissionDenied
        }
        if connectionState == .disconnected || fallbackConnectionState == .disconnected {
            return .disconnected
        }
        return connectionState
    }

    private func publishEffectiveConnection() {
        let state = effectiveConnectionState
        guard publishedConnectionState != state else { return }
        publishedConnectionState = state
        onConnectionState?(state)
        broadcastSignals()
    }

    private func setPairingStatus(_ status: DevicePairingStatus) {
        guard pairingStatus != status else { return }
        pairingStatus = status
        for continuation in pairingStatusContinuations.values {
            continuation.yield(status)
        }
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
            connection: effectiveConnectionState,
            proximity: proximityState,
            observedAt: .now
        )
    }

    private func broadcastSignals() {
        let value = signals()
        for continuation in continuations.values { continuation.yield(value) }
    }
}
