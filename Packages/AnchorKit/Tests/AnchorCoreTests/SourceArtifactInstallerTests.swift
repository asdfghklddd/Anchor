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

    @Test("The browser manifest points to the signed embedded helper")
    func installsPinnedBrowserManifest() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let helper = directory.appending(path: "AnchorWebBridge")
        let browserSupport = directory.appending(path: "Chrome")
        try Data("helper".utf8).write(to: helper)

        let installer = SourceArtifactInstaller()
        let manifest = try installer.installBrowserManifest(
            helperURL: helper,
            browserSupportURL: browserSupport
        )

        #expect(
            manifest.path == browserSupport
                .appending(path: "NativeMessagingHosts/com.andywang.anchor.web.json")
                .path
        )
        #expect(installer.browserManifestIsCurrent(at: manifest, helperURL: helper))
    }

    @Test("A manifest for a moved app is reported as stale")
    func detectsStaleBrowserManifest() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let originalHelper = directory.appending(path: "Original/AnchorWebBridge")
        let movedHelper = directory.appending(path: "Moved/AnchorWebBridge")
        let browserSupport = directory.appending(path: "Chrome")
        try FileManager.default.createDirectory(
            at: originalHelper.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("helper".utf8).write(to: originalHelper)

        let installer = SourceArtifactInstaller()
        let manifest = try installer.installBrowserManifest(
            helperURL: originalHelper,
            browserSupportURL: browserSupport
        )

        #expect(!installer.browserManifestIsCurrent(at: manifest, helperURL: movedHelper))
    }

    @Test(
        "Known browsers resolve to fixed user support locations",
        arguments: [
            (ChromiumBrowserTarget.chrome, "Library/Application Support/Google/Chrome"),
            (ChromiumBrowserTarget.edge, "Library/Application Support/Microsoft Edge"),
            (ChromiumBrowserTarget.brave, "Library/Application Support/BraveSoftware/Brave-Browser"),
            (ChromiumBrowserTarget.chromium, "Library/Application Support/Chromium"),
        ]
    )
    func resolvesFixedBrowserSupportLocations(
        browser: ChromiumBrowserTarget,
        relativePath: String
    ) {
        let home = URL(filePath: "/Users/anchor-test", directoryHint: .isDirectory)

        #expect(
            browser.applicationSupportURL(homeDirectory: home).path
                == home.appending(path: relativePath, directoryHint: .isDirectory).path
        )
    }

    @Test("The automatic browser installer writes only the fixed manifest")
    func installsManifestAtFixedBrowserLocation() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let helper = directory.appending(path: "Anchor.app/Contents/Helpers/AnchorWebBridge")
        try FileManager.default.createDirectory(
            at: helper.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("helper".utf8).write(to: helper)

        let manifest = try SourceArtifactInstaller().installBrowserManifest(
            helperURL: helper,
            browser: .chrome,
            homeDirectory: directory
        )

        #expect(
            manifest.path
                == directory.appending(
                    path: "Library/Application Support/Google/Chrome/NativeMessagingHosts/com.andywang.anchor.web.json"
                ).path
        )
    }

    @Test("Chrome external installation uses only the pinned Web Store update URL")
    func installsPinnedChromeExternalExtensionPreference() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = SourceArtifactInstaller()

        let preference = try #require(
            try installer.installExternalExtensionPreference(
                browser: .chrome,
                homeDirectory: directory
            )
        )

        #expect(
            preference.path == directory.appending(
                path: "Library/Application Support/Google/Chrome/External Extensions/omodbnhjlobhhkjcbaeokekfadoeiemk.json"
            ).path
        )
        #expect(
            installer.externalExtensionPreferenceIsCurrent(
                browser: .chrome,
                homeDirectory: directory
            )
        )
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: preference)) as? [String: String]
        )
        #expect(object == [
            "external_update_url": SourceArtifactInstaller.chromeWebStoreUpdateURL,
        ])
    }

    @Test("Unvalidated browsers keep the explicit store fallback")
    func doesNotWriteUnvalidatedExternalExtensionPreferences() throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = SourceArtifactInstaller()

        for browser in [
            ChromiumBrowserTarget.edge,
            .brave,
            .chromium,
        ] {
            #expect(
                try installer.installExternalExtensionPreference(
                    browser: browser,
                    homeDirectory: directory
                ) == nil
            )
        }
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
