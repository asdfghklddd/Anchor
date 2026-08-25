import Foundation

/// Chrome and Chromium native messaging use a four-byte little-endian length
/// followed by one UTF-8 JSON payload. The codec is independent of stdio so the
/// framing boundary can be tested without launching a browser.
public enum NativeMessagingFrameCodec {
    public static let maximumPayloadSize = 1_048_576

    public static func payloadLength(from header: Data) throws -> Int {
        guard header.count == MemoryLayout<UInt32>.size else {
            throw NativeMessagingFrameError.incompleteHeader
        }
        let rawLength = header.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        }
        let length = Int(UInt32(littleEndian: rawLength))
        guard length > 0, length <= maximumPayloadSize else {
            throw NativeMessagingFrameError.invalidPayloadLength(length)
        }
        return length
    }

    public static func frame(_ payload: Data) throws -> Data {
        guard !payload.isEmpty, payload.count <= maximumPayloadSize else {
            throw NativeMessagingFrameError.invalidPayloadLength(payload.count)
        }
        var length = UInt32(payload.count).littleEndian
        var result = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        result.append(payload)
        return result
    }
}

public enum NativeMessagingFrameError: LocalizedError, Hashable, Sendable {
    case incompleteHeader
    case invalidPayloadLength(Int)

    public var errorDescription: String? {
        switch self {
        case .incompleteHeader:
            "The browser native message header is incomplete."
        case let .invalidPayloadLength(length):
            "The browser native message payload length is invalid: \(length)."
        }
    }
}
