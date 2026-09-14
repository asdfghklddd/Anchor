import Foundation
import Testing
@testable import AnchorCore

@Test("Codex locator selects newest regular JSONL file")
func locatesNewestCodexSession() throws {
    let root = URL.temporaryDirectory.appending(path: "codex-root-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let older = root.appending(path: "older.jsonl"); let newer = root.appending(path: "newer.jsonl")
    try Data("old".utf8).write(to: older); try Data("new".utf8).write(to: newer)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: older.path)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2)], ofItemAtPath: newer.path)
    #expect(CodexSessionFileLocator(rootURL: root).newestSessionFile()?.standardizedFileURL == newer.standardizedFileURL)
}

@Test("Codex locator returns a bounded newest-first metadata catalog")
func locatesRecentCodexSessions() throws {
    let root = URL.temporaryDirectory.appending(path: "codex-catalog-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let oldest = root.appending(path: "oldest.jsonl")
    let middle = root.appending(path: "middle.jsonl")
    let newest = root.appending(path: "newest.jsonl")
    try Data("old".utf8).write(to: oldest)
    try Data("middle".utf8).write(to: middle)
    try Data("new".utf8).write(to: newest)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1)], ofItemAtPath: oldest.path)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 2)], ofItemAtPath: middle.path)
    try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 3)], ofItemAtPath: newest.path)

    let files = CodexSessionFileLocator(rootURL: root).recentSessionFiles(limit: 2)

    #expect(
        files.map { $0.fileURL.standardizedFileURL } ==
            [newest.standardizedFileURL, middle.standardizedFileURL]
    )
    #expect(files.map(\.fileSize) == [3, 6])
}
