import AnchorCore
import CryptoKit
import Foundation
import Network
import Security

public final class AnchorBonjourServer: @unchecked Sendable, LocalLinkControlling {
    public static let serviceType = "_anchor._tcp"

    public var onEvent: (@Sendable (EventEnvelope) -> Void)?
    public var onConnectionState: (@Sendable (ConnectionState) -> Void)?

    private let queue = DispatchQueue(label: "com.andywang.anchor.bonjour.server")
    private let identityStore: PairingIdentityStore
    private let deviceID: UUID
    private var listener: NWListener?
    private var peers: [ObjectIdentifier: LineConnection] = [:]
    private var pairingCodeValue: String

    public init(identityStore: PairingIdentityStore = PairingIdentityStore()) {
        self.identityStore = identityStore
        deviceID = identityStore.localDeviceID()
        pairingCodeValue = Self.makePairingCode()
    }

    public func start() throws {
        guard listener == nil else { return }
        let listener = try NWListener(using: .tcp)
        listener.service = NWListener.Service(name: "Anchor", type: Self.serviceType)
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.onConnectionState?(.disconnected)
            case .failed: self?.onConnectionState?(.failed)
            case .cancelled: self?.onConnectionState?(.unavailable)
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
        queue.async { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
            self?.peers.values.forEach { $0.cancel() }
            self?.peers.removeAll()
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
        if listener == nil { try? start() }
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
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        guard let derived = try? AnchorLinkCodec.deriveKey(
            privateKey: privateKey,
            peerPublicKey: publicKey,
            pairingCode: pairingCodeValue,
            clientID: frame.senderID,
            serverID: deviceID
        ) else { return }
        try? identityStore.saveSharedKey(derived, peerID: frame.senderID)
        peer.send(
            LinkFrame(
                kind: .pairAccepted,
                senderID: deviceID,
                publicKey: privateKey.publicKey.rawRepresentation
            )
        )
        pairingCodeValue = Self.makePairingCode()
        onConnectionState?(.connected)
    }

    private func handleEncrypted(_ frame: LinkFrame, from peer: LineConnection) {
        guard let encrypted = frame.encryptedPayload,
              let key = identityStore.sharedKey(peerID: frame.senderID),
              let payload = try? AnchorLinkCodec.open(encrypted, using: key) else { return }
        onConnectionState?(.connected)
        if let event = payload.event {
            onEvent?(event)
            let acknowledgement = LinkPayload(kind: .acknowledgement, acknowledgedEventID: event.id)
            if let sealed = try? AnchorLinkCodec.seal(acknowledgement, using: key) {
                peer.send(LinkFrame(kind: .encrypted, senderID: deviceID, encryptedPayload: sealed))
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
}
