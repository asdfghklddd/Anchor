import Foundation
import Testing
@testable import AnchorCore

@Suite("Source artifact installer")
struct SourceArtifactInstallerTests {
    @Test("The command is copied atomically and remains executable")
    func installsExecutableCommand() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appending(path: "bundled-anchor")
        let destination = directory.appending(path: "bin/anchor")
        try Data("anchor-command".utf8).write(to: source)

        try SourceArtifactInstaller().installCommand(from: source, to: destination)

        #expect(try Data(contentsOf: destination) == Data("anchor-command".utf8))
        #expect(FileManager.default.isExecutableFile(atPath: destination.path))
    }

    @Test("An existing command is replaced only at its selected destination")
    func replacesExistingCommand() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appending(path: "bundled-anchor")
        let destination = directory.appending(path: "anchor")
        try Data("new".utf8).write(to: source)
        try Data("old".utf8).write(to: destination)

        try SourceArtifactInstaller().installCommand(from: source, to: destination)

        #expect(try Data(contentsOf: destination) == Data("new".utf8))
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = URL.temporaryDirectory.appending(
            path: "anchor-source-installer-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
