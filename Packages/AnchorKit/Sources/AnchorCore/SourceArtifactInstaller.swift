import Foundation

/// Installs the explicit observation artifacts shipped by the production app.
/// The command destination remains user-selected and security-scoped.
public struct SourceArtifactInstaller: Sendable {
    public static let commandName = "anchor"

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
}

public enum SourceArtifactInstallerError: LocalizedError, Equatable, Sendable {
    case invalidCommandSource

    public var errorDescription: String? {
        switch self {
        case .invalidCommandSource:
            "The Anchor command is missing from this copy of Anchor."
        }
    }
}
