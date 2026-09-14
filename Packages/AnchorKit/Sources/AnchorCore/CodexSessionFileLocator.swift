import Foundation

public struct CodexSessionFileMetadata: Hashable, Sendable {
    public let fileURL: URL
    public let contentModificationDate: Date
    public let fileSize: UInt64

    public init(fileURL: URL, contentModificationDate: Date, fileSize: UInt64) {
        self.fileURL = fileURL
        self.contentModificationDate = contentModificationDate
        self.fileSize = fileSize
    }
}

public struct CodexSessionFileLocator: Sendable {
    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

#if os(macOS)
    /// Codex Desktop stores local session metadata under the current Mac user's home directory.
    public init() {
        rootURL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/sessions")
    }
#endif

    /// Returns the newest JSONL session file by filesystem modification time.
    /// File contents are never opened during discovery.
    public func newestSessionFile() -> URL? {
        recentSessionFiles(limit: 1).first?.fileURL
    }

    /// Discovers recent session files from metadata only. Reading lifecycle
    /// records remains the responsibility of an explicitly authorized source.
    public func recentSessionFiles(limit: Int = 12) -> [CodexSessionFileMetadata] {
        guard limit > 0,
              let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey,
                ],
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension.lowercased() == "jsonl" }
            .compactMap { url -> CodexSessionFileMetadata? in
                guard let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey,
                ]),
                values.isRegularFile == true,
                let date = values.contentModificationDate else {
                    return nil
                }
                return CodexSessionFileMetadata(
                    fileURL: url,
                    contentModificationDate: date,
                    fileSize: UInt64(max(0, values.fileSize ?? 0))
                )
            }
            .sorted {
                if $0.contentModificationDate != $1.contentModificationDate {
                    return $0.contentModificationDate > $1.contentModificationDate
                }
                return $0.fileURL.path < $1.fileURL.path
            }
            .prefix(limit)
            .map { $0 }
    }
}
