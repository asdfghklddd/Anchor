import Foundation
import Testing
@testable import AnchorCore

@Test("Codex checkpoint store persists only file metadata and scanner state")
func codexCheckpointStorePersistsAcrossInstances() async throws {
    let directory = URL.temporaryDirectory.appending(path: "anchor-codex-checkpoint-" + UUID().uuidString)
    let storageURL = directory.appending(path: "checkpoints.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    var scanner = CodexIncrementalScanner()
    _ = scanner.append(Data("complete\nprivate partial".utf8))
    let checkpoint = CodexLifecycleCheckpoint(
        identity: CodexLifecycleFileIdentity(fileNumber: 42, creationDate: Date(timeIntervalSince1970: 123)),
        scannerCheckpoint: try scanner.checkpoint()
    )
    try await CodexLifecycleCheckpointStore(storageURL: storageURL).save(checkpoint, for: "codex")

    let restored = try #require(
        try await CodexLifecycleCheckpointStore(storageURL: storageURL).load(for: "codex")
    )
    #expect(restored.identity == checkpoint.identity)
    let restoredScanner = try CodexIncrementalScanner(checkpoint: restored.scannerCheckpoint)
    #expect(restoredScanner.offset == UInt64("complete\n".utf8.count))
    let storedText = try String(contentsOf: storageURL, encoding: .utf8)
    #expect(!storedText.contains("private partial"))
}

@Test("Corrupt Codex checkpoint state is preserved and never overwritten")
func corruptCodexCheckpointIsPreserved() async throws {
    let directory = URL.temporaryDirectory.appending(path: "anchor-codex-checkpoint-corrupt-" + UUID().uuidString)
    let storageURL = directory.appending(path: "checkpoints.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let corrupt = Data("{not-json".utf8)
    try corrupt.write(to: storageURL)
    let store = CodexLifecycleCheckpointStore(storageURL: storageURL)

    await #expect(throws: (any Error).self) {
        try await store.save(
            CodexLifecycleCheckpoint(
                identity: CodexLifecycleFileIdentity(fileNumber: nil, creationDate: nil),
                scannerCheckpoint: try CodexIncrementalScanner().checkpoint()
            ),
            for: "codex"
        )
    }
    #expect(try Data(contentsOf: storageURL) == corrupt)
}
