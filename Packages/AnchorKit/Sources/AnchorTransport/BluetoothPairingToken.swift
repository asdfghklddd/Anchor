import Foundation
import Security
import Synchronization

struct BluetoothPairingCredential: Codable, Equatable, Sendable {
    let deviceID: UUID
    let secret: Data
    let challenge: Data?

    init(deviceID: UUID, secret: Data, challenge: Data? = nil) {
        self.deviceID = deviceID
        self.secret = secret
        self.challenge = challenge
    }
}

public final class AnchorBluetoothPairingToken: Sendable {
    private let secret: Mutex<Data>

    public init() {
        secret = Mutex(Self.makeSecret())
    }

    public func current() -> Data {
        secret.withLock { $0 }
    }

    public func rotate() {
        secret.withLock { $0 = Self.makeSecret() }
    }

    private static func makeSecret() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = bytes.withUnsafeMutableBytes { buffer in
            guard let address = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, address)
        }
        precondition(status == errSecSuccess, "Secure random generation must be available.")
        return Data(bytes)
    }
}
