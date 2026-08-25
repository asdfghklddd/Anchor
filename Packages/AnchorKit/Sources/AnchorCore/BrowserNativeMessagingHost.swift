import Foundation

public enum BrowserHostConfiguration {
    public static let hostName = "com.andywang.anchor.web"
    public static let extensionID = "omodbnhjlobhhkjcbaeokekfadoeiemk"
    public static let allowedOrigin = "chrome-extension://\(extensionID)/"
}

/// Implements Chromium's stdio native-messaging boundary without starting the
/// macOS app UI. Production bundles embed a dedicated executable that calls
/// this host, while the Anchor CLI exposes the same protocol for development.
public enum BrowserNativeMessagingHost {
    public static func validate(origin: String) throws {
        guard origin == BrowserHostConfiguration.allowedOrigin else {
            throw BrowserNativeMessagingHostError.unauthorizedOrigin
        }
    }

    public static func run(
        inbox: URL = FileProcessSource.defaultWebInboxURL(),
        input: FileHandle = .standardInput,
        output: FileHandle = .standardOutput
    ) throws {
        while let payload = try readNativeMessage(from: input) {
            let response: BrowserHostResponse
            do {
                let signal = try JSONDecoder.anchorExternal.decode(
                    WebProcessSignal.self,
                    from: payload
                )
                try signal.validate()
                let timestamp = UInt64(
                    max(0, signal.occurredAt.timeIntervalSince1970 * 1_000)
                )
                let filename = String(
                    format: "%020llu-%020llu-web-%@.json",
                    timestamp,
                    signal.sequence,
                    signal.id.uuidString.lowercased()
                )
                try queue(
                    try JSONEncoder.anchorExternal.encode(signal),
                    itemID: signal.id,
                    inbox: inbox,
                    filename: filename
                )
                response = BrowserHostResponse(ok: true, eventID: signal.id)
            } catch {
                response = BrowserHostResponse(
                    ok: false,
                    error: "Anchor rejected the web activity signal."
                )
            }

            try output.write(
                contentsOf: NativeMessagingFrameCodec.frame(
                    try JSONEncoder().encode(response)
                )
            )
        }
    }

    public static func manifestData(binaryPath: String) throws -> Data {
        guard binaryPath.hasPrefix("/") else {
            throw BrowserNativeMessagingHostError.invalidBinaryPath
        }
        let manifest: [String: Any] = [
            "name": BrowserHostConfiguration.hostName,
            "description": "Anchor privacy-minimal web observation bridge",
            "path": binaryPath,
            "type": "stdio",
            "allowed_origins": [BrowserHostConfiguration.allowedOrigin],
        ]
        return try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    private static func readNativeMessage(from handle: FileHandle) throws -> Data? {
        guard let header = try readExactly(
            MemoryLayout<UInt32>.size,
            from: handle,
            allowsCleanEOF: true
        ) else {
            return nil
        }
        let payloadLength = try NativeMessagingFrameCodec.payloadLength(from: header)
        guard let payload = try readExactly(
            payloadLength,
            from: handle,
            allowsCleanEOF: false
        ) else {
            throw NativeMessagingFrameError.invalidPayloadLength(payloadLength)
        }
        return payload
    }

    private static func readExactly(
        _ count: Int,
        from handle: FileHandle,
        allowsCleanEOF: Bool
    ) throws -> Data? {
        var result = Data()
        while result.count < count {
            let chunk = try handle.read(upToCount: count - result.count) ?? Data()
            if chunk.isEmpty {
                if result.isEmpty, allowsCleanEOF {
                    return nil
                }
                throw NativeMessagingFrameError.invalidPayloadLength(result.count)
            }
            result.append(chunk)
        }
        return result
    }

    private static func queue(
        _ data: Data,
        itemID: UUID,
        inbox: URL,
        filename: String
    ) throws {
        try FileManager.default.createDirectory(
            at: inbox,
            withIntermediateDirectories: true
        )
        let temporary = inbox.appending(path: ".\(itemID.uuidString).tmp")
        let destination = inbox.appending(path: filename)
        try data.write(to: temporary, options: .atomic)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

public enum BrowserNativeMessagingHostError: LocalizedError, Hashable, Sendable {
    case invalidBinaryPath
    case unauthorizedOrigin

    public var errorDescription: String? {
        switch self {
        case .invalidBinaryPath:
            "The browser host binary path must be absolute."
        case .unauthorizedOrigin:
            "The browser extension origin is not authorized."
        }
    }
}

private struct BrowserHostResponse: Codable {
    let ok: Bool
    let eventID: UUID?
    let error: String?

    init(ok: Bool, eventID: UUID? = nil, error: String? = nil) {
        self.ok = ok
        self.eventID = eventID
        self.error = error
    }
}
