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
    public var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    private let queue = DispatchQueue(label: "com.andywang.anchor.bonjour.server")
    private let identityStore: PairingIdentityStore
    private let deviceID: UUID
    private var listener: NWListener?
    private var peers: [ObjectIdentifier: LineConnection] = [:]
    private var peerIDs: [ObjectIdentifier: UUID] = [:]
    private var pendingDeliveries: [UUID: PendingDelivery] = [:]
    private var pairingCodeValue: String
    private var eventApplicationTask: Task<Void, Never>?
    private var replayWindow = LinkReplayWindow()

    public init(identityStore: PairingIdentityStore = PairingIdentityStore()) {
        self.identityStore = identityStore
        deviceID = identityStore.localDeviceID()
        pairingCodeValue = Self.makePairingCode()
    }

    public func start() throws {
        try queue.sync { try startOnQueue() }
    }

    private func startOnQueue() throws {
        guard listener == nil else { return }
        let listener = try NWListener(using: .tcp)
        listener.service = NWListener.Service(name: "Anchor", type: Self.serviceType)
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, self.listener === listener else { return }
            switch state {
            case .ready:
                self.onConnectionState?(.disconnected)
            case .failed:
                self.onConnectionState?(.failed)
                self.listener?.cancel()
                self.listener = nil
            case .cancelled:
                self.onConnectionState?(.unavailable)
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
            failAllDeliveries(with: CancellationError())
            eventApplicationTask?.cancel()
            eventApplicationTask = nil
        }
    }

    public func currentPairingCode() async -> String? {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in continuation.resume(returning: self?.pairingCodeValue) }
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
                        self.onConnectionState?(.failed)
                    }
                }
                continuation.resume()
            }
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
        peer.start { [weak self, weak peer] frame in
            guard let peer else { return }
            self?.handle(frame, from: peer)
        } onState: { [weak self] state in
            switch state {
            case .ready:
                peer.send(LinkFrame(kind: .hello, senderID: self?.deviceID ?? UUID()))
            case .failed, .cancelled:
                self?.peers[id] = nil
                self?.peerIDs[id] = nil
                self?.failAllDeliveries(with: AnchorLinkError.connectionLost)
                self?.onConnectionState?(.disconnected)
            default: break
            }
        }
    }

    private func handle(_ frame: LinkFrame, from peer: LineConnection) {
        switch frame.kind {
        case .pairRequest:
            handlePairRequest(frame, from: peer)
        case .encrypted:
            handleEncrypted(frame, from: peer)
        case .hello, .pairAccepted:
            break
        }
    }

    private func handlePairRequest(_ frame: LinkFrame, from peer: LineConnection) {
        guard frame.pairingCode == pairingCodeValue, let publicKey = frame.publicKey else { return }
        peerIDs[ObjectIdentifier(peer)] = frame.senderID
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        let derived: Data
        do {
            derived = try AnchorLinkCodec.deriveKey(
                privateKey: privateKey,
                peerPublicKey: publicKey,
                pairingCode: pairingCodeValue,
                clientID: frame.senderID,
                serverID: deviceID
            )
            try identityStore.saveSharedKey(derived, peerID: frame.senderID)
        } catch {
            return
        }
        peer.send(
            LinkFrame(
                kind: .pairAccepted,
                senderID: deviceID,
                publicKey: privateKey.publicKey.rawRepresentation
            )
        ) { [weak self] result in
            if case .success = result {
                self?.pairingCodeValue = Self.makePairingCode()
            }
        }
    }

    private func handleEncrypted(_ frame: LinkFrame, from peer: LineConnection) {
        peerIDs[ObjectIdentifier(peer)] = frame.senderID
        guard let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID),
              let payload = try? AnchorLinkCodec.open(encrypted, using: key) else { return }
        onConnectionState?(.connected)
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

    private func sendEncrypted(_ payload: LinkPayload, using key: Data, to peer: LineConnection) {
        guard let sealed = try? AnchorLinkCodec.seal(payload, using: key) else { return }
        peer.send(LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed))
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
}
