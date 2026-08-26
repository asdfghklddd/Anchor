import Foundation

/// Installs the two explicit observation artifacts shipped by the production
/// macOS app. All destinations are chosen by the user through the app UI.
public struct SourceArtifactInstaller: Sendable {
    public static let commandName = "anchor"
    public static let nativeMessagingDirectoryName = "NativeMessagingHosts"
    public static let nativeMessagingManifestName = "\(BrowserHostConfiguration.hostName).json"

    public init() {}

    public func installCommand(from sourceURL: URL, to destinationURL: URL) throws {
        let fileManager = FileManager.default
        let values = try sourceURL.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else {
            throw SourceArtifactInstallerError.invalidCommandSource
        }

        let parentURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let temporaryURL = parentURL.appending(
            path: ".anchor-install-\(UUID().uuidString)",
            directoryHint: .notDirectory
        )
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try fileManager.copyItem(at: sourceURL, to: temporaryURL)
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o755)],
            ofItemAtPath: temporaryURL.path
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            _ = try fileManager.replaceItemAt(destinationURL, withItemAt: temporaryURL)
        } else {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        }
    }

    @discardableResult
    public func installBrowserManifest(
        helperURL: URL,
        browserSupportURL: URL
    ) throws -> URL {
        let helperValues = try helperURL.resourceValues(forKeys: [.isRegularFileKey])
        guard helperValues.isRegularFile == true else {
            throw SourceArtifactInstallerError.invalidBrowserHelper
        }

        let manifestDirectory = browserSupportURL.appending(
            path: Self.nativeMessagingDirectoryName,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: manifestDirectory,
            withIntermediateDirectories: true
        )
        let manifestURL = manifestDirectory.appending(
            path: Self.nativeMessagingManifestName,
            directoryHint: .notDirectory
        )
        let data = try BrowserNativeMessagingHost.manifestData(
            binaryPath: helperURL.standardizedFileURL.path
        )
        try data.write(to: manifestURL, options: .atomic)
        return manifestURL
    }

    public func browserManifestIsCurrent(
        at manifestURL: URL,
        helperURL: URL
    ) -> Bool {
        guard let data = try? Data(contentsOf: manifestURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["name"] as? String == BrowserHostConfiguration.hostName
            && object["path"] as? String == helperURL.standardizedFileURL.path
            && object["allowed_origins"] as? [String]
                == [BrowserHostConfiguration.allowedOrigin]
    }
}

public enum SourceArtifactInstallerError: LocalizedError, Equatable, Sendable {
    case invalidBrowserHelper
    case invalidCommandSource

    public var errorDescription: String? {
        switch self {
        case .invalidBrowserHelper:
            "The browser bridge is missing from this copy of Anchor."
        case .invalidCommandSource:
            "The Anchor command is missing from this copy of Anchor."
        }
    }
}
