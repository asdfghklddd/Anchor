import AnchorCore
import CryptoKit
import Foundation
import Network
import Security

/// Network.framework callbacks and all mutable fields are serialized on
/// `queue`; the unchecked conformance is limited to that queue-owned state.
public final class AnchorBonjourServer: @unchecked Sendable, LocalLinkControlling, AnchorEventTransport {
    private typealias OperationContinuation = CheckedContinuation<Void, any Error>

    private struct PendingDelivery {
        let continuation: OperationContinuation
        let timeoutWorkItem: DispatchWorkItem
    }

    public static let serviceType = "_anchor._tcp"

    public var onEvent: (@Sendable (EventEnvelope) async throws -> Void)?
    public var onCurrentProcessSnapshot: (@Sendable () async throws -> CurrentProcessSnapshot)?
    public var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    private let queue = DispatchQueue(label: "com.andywang.anchor.bonjour.server")
    private let identityStore: PairingIdentityStore
    private let automaticPairing: AutomaticPairingConfiguration
    private let bluetoothPairingToken: AnchorBluetoothPairingToken?
    private let deviceID: UUID
    private let advertisedServiceType: String
    private let advertisedServiceName: String
    private var listener: NWListener?
    private var peers: [ObjectIdentifier: LineConnection] = [:]
    private var peerIDs: [ObjectIdentifier: UUID] = [:]
    private var peerChallenges: [ObjectIdentifier: Data] = [:]
    private var peerPairingRoutes: [ObjectIdentifier: DevicePairingRoute] = [:]
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var pairingCodeValue: String
    private var eventApplicationTask: Task<Void, Never>?
    private var replayWindow = LinkReplayWindow()
    private var connectionState = ConnectionState.unavailable
    private var fallbackConnectionState = ConnectionState.unavailable
    private var publishedConnectionState = ConnectionState.unavailable
    private var pairingStatus = DevicePairingStatus.automatic
    private var pairingStatusContinuations: [UUID: AsyncStream<DevicePairingStatus>.Continuation] = [:]

    public init(
        identityStore: PairingIdentityStore = PairingIdentityStore(),
        deviceID: UUID? = nil,
        automaticPairing: AutomaticPairingConfiguration = .macProduction(),
        bluetoothPairingToken: AnchorBluetoothPairingToken? = nil,
        serviceType: String = AnchorBonjourServer.serviceType,
        serviceName: String = "Anchor"
    ) {
        self.identityStore = identityStore
        self.automaticPairing = automaticPairing
        self.bluetoothPairingToken = bluetoothPairingToken
        self.deviceID = deviceID ?? identityStore.localDeviceID()
        advertisedServiceType = serviceType
        advertisedServiceName = serviceName
        pairingCodeValue = Self.makePairingCode()
    }

    public func start() throws {
        try queue.sync { try startOnQueue() }
    }

    private func startOnQueue() throws {
        guard listener == nil else { return }
        let listener = try NWListener(using: AnchorNearbyNetwork.tcpParameters())
        listener.service = NWListener.Service(
            name: advertisedServiceName,
            type: advertisedServiceType
        )
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, self.listener === listener else { return }
            switch state {
            case .ready:
                self.setConnection(.disconnected)
            case .failed:
                self.setConnection(.failed)
                self.listener?.cancel()
                self.listener = nil
            case .cancelled:
                self.setConnection(.unavailable)
                self.listener = nil
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    public func stop() {
        queue.sync { [weak self] in
            guard let self else { return }
            listener?.cancel()
            listener = nil
            peers.values.forEach { $0.cancel() }
            peers.removeAll()
            peerIDs.removeAll()
            peerChallenges.removeAll()
            peerPairingRoutes.removeAll()
            failAllDeliveries(with: CancellationError())
            eventApplicationTask?.cancel()
            eventApplicationTask = nil
            setConnection(.unavailable)
        }
    }

    public func currentPairingCode() async -> String? {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in continuation.resume(returning: self?.pairingCodeValue) }
        }
    }

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
        throw AnchorLinkError.unsupportedOperation
    }

    public func retryConnection() async {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }
                if self.listener == nil {
                    do {
                        try self.startOnQueue()
                    } catch {
                        self.setConnection(.failed)
                    }
                }
                self.setPairingStatus(.automatic)
                continuation.resume()
            }
        }
    }

    /// Keeps pairing UI and repository recovery aligned with the BLE event
    /// channel while the TCP listener remains the preferred transport.
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

    public func send(_ event: EventEnvelope) async throws {
        try await withCheckedThrowingContinuation { (continuation: OperationContinuation) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                guard let (peer, peerID, key) = self.authenticatedPeer() else {
                    continuation.resume(throwing: AnchorLinkError.notPaired)
                    return
                }
                guard self.pendingDeliveries[event.id] == nil else {
                    continuation.resume(throwing: AnchorLinkError.operationInProgress)
                    return
                }
                do {
                    let sealed = try AnchorLinkCodec.seal(
                        LinkPayload(kind: .event, event: event),
                        using: key
                    )
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
                    self.queue.asyncAfter(
                        deadline: .now() + 10,
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
                            self?.finishDelivery(event.id, with: .failure(error))
                        }
                    }
                    _ = peerID
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        let peer = LineConnection(connection: connection, queue: queue)
        let id = ObjectIdentifier(peer)
        peers[id] = peer
        peerChallenges[id] = Self.makePairingChallenge()
        peer.start { [weak self, weak peer] frame in
            guard let peer else { return }
            self?.handle(frame, from: peer)
        } onState: { [weak self, weak peer] state in
            guard let self,
                  let peer,
                  self.peers[id] === peer else { return }
            switch state {
            case .ready:
                peer.send(
                    LinkFrame(
                        kind: .hello,
                        senderID: self.deviceID,
                        challenge: self.peerChallenges[id]
                    )
                )
            case .failed, .cancelled:
                self.peers[id] = nil
                self.peerIDs[id] = nil
                self.peerChallenges[id] = nil
                self.peerPairingRoutes[id] = nil
                self.failAllDeliveries(with: AnchorLinkError.connectionLost)
                if self.authenticatedPeer() == nil {
                    self.setConnection(.disconnected)
                }
            default: break
            }
        }
    }

    private func handle(_ frame: LinkFrame, from peer: LineConnection) {
        switch frame.kind {
        case .pairRequest:
            handlePairRequest(frame, from: peer)
        case .fallbackRequested:
            setPairingStatus(.verificationCodeRequired)
        case .encrypted:
            handleEncrypted(frame, from: peer)
        case .hello, .pairAccepted:
            break
        }
    }

    private func handlePairRequest(_ frame: LinkFrame, from peer: LineConnection) {
        let peerObjectID = ObjectIdentifier(peer)
        guard let publicKey = frame.publicKey,
              let challenge = peerChallenges[peerObjectID] else { return }
        let method = frame.pairingMethod ?? .verificationCode
        let secret: Data
        switch method {
        case .iCloud:
            guard let value = automaticPairing.iCloudSecretProvider() else { return }
            secret = value
        case .bluetooth:
            guard let value = bluetoothPairingToken?.current() else { return }
            secret = value
        case .verificationCode:
            if frame.pairingMethod == nil {
                guard frame.pairingCode == pairingCodeValue else { return }
            }
            secret = Data(pairingCodeValue.utf8)
            setPairingStatus(.verificationCodeRequired)
        }
        if let proof = frame.pairingProof {
            guard AnchorLinkCodec.validatesPairingProof(
                proof,
                secret: secret,
                method: method,
                role: "client",
                clientID: frame.senderID,
                serverID: deviceID,
                clientPublicKey: publicKey,
                challenge: challenge
            ) else { return }
        } else if method != .verificationCode {
            return
        }
        peerIDs[peerObjectID] = frame.senderID
        peerPairingRoutes[peerObjectID] = method.route
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let derived: Data
        do {
            derived = try AnchorLinkCodec.deriveKey(
                privateKey: privateKey,
                peerPublicKey: publicKey,
                pairingSecret: secret,
                clientID: frame.senderID,
                serverID: deviceID
            )
            try identityStore.saveSharedKey(derived, peerID: frame.senderID)
        } catch {
            return
        }
        let serverPublicKey = privateKey.publicKey.rawRepresentation
        let proof = AnchorLinkCodec.pairingProof(
            secret: secret,
            method: method,
            role: "server",
            clientID: frame.senderID,
            serverID: deviceID,
            clientPublicKey: publicKey,
            serverPublicKey: serverPublicKey,
            challenge: challenge
        )
        peer.send(
            LinkFrame(
                kind: .pairAccepted,
                senderID: deviceID,
                publicKey: serverPublicKey,
                pairingMethod: method,
                pairingProof: proof
            )
        ) { [weak self] result in
            if case .success = result {
                if method == .verificationCode {
                    self?.pairingCodeValue = Self.makePairingCode()
                } else if method == .bluetooth {
                    self?.bluetoothPairingToken?.rotate()
                }
            }
        }
    }

    private func handleEncrypted(_ frame: LinkFrame, from peer: LineConnection) {
        let peerObjectID = ObjectIdentifier(peer)
        peerIDs[peerObjectID] = frame.senderID
        guard let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID),
              let payload = try? AnchorLinkCodec.open(encrypted, using: key) else { return }
        setConnection(.connected)
        let route = peerPairingRoutes[peerObjectID] ?? .trustedDevice
        setPairingStatus(DevicePairingStatus(phase: .connected, route: route))
        guard replayWindow.accepts(payload.messageID) else {
            if payload.kind == .event,
               let event = payload.event {
                sendEncrypted(
                    LinkPayload(kind: .acknowledgement, acknowledgedEventID: event.id),
                    using: key,
                    to: peer
                )
            }
            return
        }
        switch payload.kind {
        case .heartbeat:
            sendEncrypted(LinkPayload(kind: .heartbeat), using: key, to: peer)
        case .event:
            guard let event = payload.event, let onEvent else { return }
            let precedingTask = eventApplicationTask
            eventApplicationTask = Task { [weak self, weak peer] in
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
                          self.peers.values.contains(where: { $0 === peer }) else { return }
                    let acknowledgement = LinkPayload(
                        kind: .acknowledgement,
                        acknowledgedEventID: event.id
                    )
                    self.sendEncrypted(acknowledgement, using: key, to: peer)
                }
            }
        case .processSnapshotRequest:
            respondToProcessSnapshotRequest(
                requestID: payload.requestID,
                using: key,
                to: peer
            )
        case .processSnapshotResponse:
            break
        case .acknowledgement:
            if let eventID = payload.acknowledgedEventID {
                finishDelivery(eventID, with: .success(()))
            }
        }
    }

    private func authenticatedPeer() -> (LineConnection, UUID, Data)? {
        for (id, peer) in peers {
            guard let peerID = peerIDs[id],
                  let key = identityStore.sharedKey(peerID: peerID) else { continue }
            return (peer, peerID, key)
        }
        return nil
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

    /// Queue-isolated transitions prevent authenticated traffic from
    /// retriggering reconnect work while the same link remains healthy.
    private func setConnection(_ state: ConnectionState) {
        guard connectionState != state else { return }
        connectionState = state
        if state != .connected, fallbackConnectionState == .connected {
            setPairingStatus(DevicePairingStatus(phase: .connected, route: .bluetooth))
        } else if effectiveConnectionState != .connected {
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
    }

    private func setPairingStatus(_ status: DevicePairingStatus) {
        guard pairingStatus != status else { return }
        pairingStatus = status
        for continuation in pairingStatusContinuations.values {
            continuation.yield(status)
        }
    }

    private func sendEncrypted(_ payload: LinkPayload, using key: Data, to peer: LineConnection) {
        guard let sealed = try? AnchorLinkCodec.seal(payload, using: key) else { return }
        peer.send(LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed))
    }

    private func respondToProcessSnapshotRequest(
        requestID: UUID?,
        using key: Data,
        to peer: LineConnection
    ) {
        guard let requestID else { return }
        let provider = onCurrentProcessSnapshot
        Task { [weak self, weak peer] in
            let snapshot = try? await provider?()
            guard let self, let peer else { return }
            self.queue.async { [weak self, weak peer] in
                guard let self,
                      let peer,
                      self.peers.values.contains(where: { $0 === peer }) else { return }
                self.sendEncrypted(
                    LinkPayload(
                        kind: .processSnapshotResponse,
                        requestID: requestID,
                        currentProcessSnapshot: snapshot
                    ),
                    using: key,
                    to: peer
                )
            }
        }
    }

    private static func makePairingCode() -> String {
        var value: UInt32 = 0
        let status = withUnsafeMutableBytes(of: &value) { bytes in
            guard let address = bytes.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, bytes.count, address)
        }
        let number = status == errSecSuccess ? Int(value % 1_000_000) : Int.random(in: 0..<1_000_000)
        return String(format: "%06d", number)
    }

    private static func makePairingChallenge() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, address)
        }
        precondition(status == errSecSuccess, "Secure random generation must be available.")
        return Data(bytes)
    }
}
