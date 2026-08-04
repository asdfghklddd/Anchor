import AnchorCore
import CryptoKit
import Foundation

public enum AnchorLinkError: LocalizedError, Sendable {
    case invalidPairingCode
    case invalidPeerKey
    case malformedFrame
    case notPaired
    case operationInProgress
    case pairingTimedOut
    case acknowledgementTimedOut
    case connectionLost
    case unsupportedOperation

    public var errorDescription: String? {
        switch self {
        case .invalidPairingCode:
            String(
                localized: "error.link.pairing-code",
                defaultValue: "Enter the six-digit pairing code shown on the Mac.",
                bundle: .module
            )
        case .invalidPeerKey:
            String(
                localized: "error.link.peer-key",
                defaultValue: "The peer supplied an invalid identity key.",
                bundle: .module
            )
        case .malformedFrame:
            String(
                localized: "error.link.malformed-frame",
                defaultValue: "The local Anchor message could not be decoded.",
                bundle: .module
            )
        case .notPaired:
            String(
                localized: "error.link.not-paired",
                defaultValue: "Pair this device before sending events.",
                bundle: .module
            )
        case .operationInProgress:
            String(
                localized: "error.link.operation-in-progress",
                defaultValue: "A local connection operation is already in progress.",
                bundle: .module
            )
        case .pairingTimedOut:
            String(
                localized: "error.link.pairing-timeout",
                defaultValue: "Pairing timed out. Check the code and try again.",
                bundle: .module
            )
        case .acknowledgementTimedOut:
            String(
                localized: "error.link.acknowledgement-timeout",
                defaultValue: "The Mac did not confirm the update. Try reconnecting.",
                bundle: .module
            )
        case .connectionLost:
            String(
                localized: "error.link.connection-lost",
                defaultValue: "The local Anchor connection was interrupted.",
                bundle: .module
            )
        case .unsupportedOperation:
            String(
                localized: "error.link.unsupported",
                defaultValue: "This pairing operation is unavailable on this device.",
                bundle: .module
            )
        }
    }
}

enum LinkFrameKind: String, Codable, Sendable {
    case hello
    case pairRequest
    case pairAccepted
    case encrypted
}

struct LinkFrame: Codable, Sendable {
    let version: Int
    let kind: LinkFrameKind
    let senderID: UUID
    let publicKey: Data?
    let pairingCode: String?
    let encryptedPayload: Data?

    init(
        kind: LinkFrameKind,
        senderID: UUID,
        publicKey: Data? = nil,
        pairingCode: String? = nil,
        encryptedPayload: Data? = nil
    ) {
        version = 1
        self.kind = kind
        self.senderID = senderID
        self.publicKey = publicKey
        self.pairingCode = pairingCode
        self.encryptedPayload = encryptedPayload
    }
}

enum LinkPayloadKind: String, Codable, Sendable {
    case heartbeat
    case event
    case acknowledgement
}

struct LinkPayload: Codable, Sendable {
    let kind: LinkPayloadKind
    let sentAt: Date
    let event: EventEnvelope?
    let acknowledgedEventID: UUID?

    init(
        kind: LinkPayloadKind,
        sentAt: Date = .now,
        event: EventEnvelope? = nil,
        acknowledgedEventID: UUID? = nil
    ) {
        self.kind = kind
        self.sentAt = sentAt
        self.event = event
        self.acknowledgedEventID = acknowledgedEventID
    }
}

enum AnchorLinkCodec {
    static func seal(_ payload: LinkPayload, using keyData: Data) throws -> Data {
        let data = try JSONEncoder.anchor.encode(payload)
        let box = try ChaChaPoly.seal(data, using: SymmetricKey(data: keyData))
        return box.combined
    }

    static func open(_ data: Data, using keyData: Data) throws -> LinkPayload {
        let box = try ChaChaPoly.SealedBox(combined: data)
        let clear = try ChaChaPoly.open(box, using: SymmetricKey(data: keyData))
        return try JSONDecoder.anchor.decode(LinkPayload.self, from: clear)
    }

    static func deriveKey(
        privateKey: Curve25519.KeyAgreement.PrivateKey,
        peerPublicKey: Data,
        pairingCode: String,
        clientID: UUID,
        serverID: UUID
    ) throws -> Data {
        guard pairingCode.utf8.count == 6,
              pairingCode.utf8.allSatisfy({ (48...57).contains($0) }) else {
            throw AnchorLinkError.invalidPairingCode
        }
        let peerKey: Curve25519.KeyAgreement.PublicKey
        do {
            peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKey)
        } catch {
            throw AnchorLinkError.invalidPeerKey
        }
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)
        var context = Data(clientID.uuidString.utf8)
        context.append(contentsOf: serverID.uuidString.utf8)
        let key = secret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(pairingCode.utf8),
            sharedInfo: context,
            outputByteCount: 32
        )
        return key.withUnsafeBytes { Data($0) }
    }
}

extension JSONEncoder {
    static var anchor: JSONEncoder {
        let encoder = JSONEncoder()
        // Preserve Date's exact representation across an encrypted round trip.
        // Floating-point seconds can be rounded by JSONSerialization, which is
        // enough to make otherwise identical event envelopes compare unequal.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate.bitPattern)
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var anchor: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let bitPattern = try container.decode(UInt64.self)
            return Date(timeIntervalSinceReferenceDate: Double(bitPattern: bitPattern))
        }
        return decoder
    }
}
