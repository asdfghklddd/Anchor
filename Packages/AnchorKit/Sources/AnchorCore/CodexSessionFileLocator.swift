import Foundation

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
        guard let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else { return nil }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }.compactMap { url -> (URL, Date)? in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]), values.isRegularFile == true,
                  let date = values.contentModificationDate else { return nil }
            return (url, date)
        }.max { $0.1 < $1.1 }?.0
    }
}
