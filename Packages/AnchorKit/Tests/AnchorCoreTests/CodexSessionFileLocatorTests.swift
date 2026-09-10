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
