import Foundation

public struct BrowserConnectionReceipt: Codable, Equatable, Sendable {
    public static let schemaIdentifier = "anchor.web.connection.v1"

    public let schema: String
    public let occurredAt: Date
    public let extensionOrigin: String

    public init(
        occurredAt: Date = .now,
        extensionOrigin: String = BrowserHostConfiguration.allowedOrigin
    ) {
        schema = Self.schemaIdentifier
        self.occurredAt = occurredAt
        self.extensionOrigin = extensionOrigin
    }

    public static func defaultURL() -> URL {
        FileProcessSource.defaultWebInboxURL()
            .deletingLastPathComponent()
            .appending(path: "BrowserConnection.json", directoryHint: .notDirectory)
    }

    public static func load(from url: URL = defaultURL()) -> Self? {
        guard let data = try? Data(contentsOf: url),
              let receipt = try? JSONDecoder.anchorExternal.decode(Self.self, from: data),
              receipt.schema == schemaIdentifier,
              receipt.extensionOrigin == BrowserHostConfiguration.allowedOrigin else {
            return nil
        }
        return receipt
    }

    public func write(to url: URL = Self.defaultURL()) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder.anchorExternal.encode(self).write(to: url, options: .atomic)
    }
}
