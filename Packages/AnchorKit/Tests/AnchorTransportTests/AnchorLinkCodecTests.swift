import AnchorCore
import CryptoKit
import Foundation
import Testing
@testable import AnchorTransport

@Suite("Local link codec")
struct AnchorLinkCodecTests {
    @Test("Both pairing peers derive the same encrypted channel")
    func pairingKeyAgreement() throws {
        let client = Curve25519.KeyAgreement.PrivateKey()
        let server = Curve25519.KeyAgreement.PrivateKey()
        let clientID = UUID()
        let serverID = UUID()
        let clientKey = try AnchorLinkCodec.deriveKey(
            privateKey: client,
            peerPublicKey: server.publicKey.rawRepresentation,
            pairingCode: "123456",
            clientID: clientID,
            serverID: serverID
        )
        let serverKey = try AnchorLinkCodec.deriveKey(
            privateKey: server,
            peerPublicKey: client.publicKey.rawRepresentation,
            pairingCode: "123456",
            clientID: clientID,
            serverID: serverID
        )
        #expect(clientKey == serverKey)
    }

    @Test("Authenticated payload round-trips and rejects the wrong key")
    func sealedPayload() throws {
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let wrongKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let event = EventEnvelope(
            sessionID: UUID(),
            sourceID: UUID(),
            sequence: 1,
            type: "test",
            payload: Data("hello".utf8)
        )
        let sealed = try AnchorLinkCodec.seal(LinkPayload(kind: .event, event: event), using: key)
        let opened = try AnchorLinkCodec.open(sealed, using: key)

        #expect(opened.event == event)
        #expect(throws: (any Error).self) {
            _ = try AnchorLinkCodec.open(sealed, using: wrongKey)
        }
    }
}
