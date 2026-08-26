#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import Foundation
import Observation

public enum MacSourceSetupBrowser: String, CaseIterable, Identifiable, Sendable {
    case chrome
    case edge
    case brave
    case chromium

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: "Google Chrome"
        case .edge: "Microsoft Edge"
        case .brave: "Brave"
        case .chromium: "Chromium"
        }
    }

    fileprivate var supportPathComponents: [String] {
        switch self {
        case .chrome: ["Google", "Chrome"]
        case .edge: ["Microsoft Edge"]
        case .brave: ["BraveSoftware", "Brave-Browser"]
        case .chromium: ["Chromium"]
        }
    }
}

@MainActor
@Observable
public final class MacSourceSetupModel {
    public private(set) var isCommandInstalled = false
    public private(set) var installedBrowsers = Set<MacSourceSetupBrowser>()
    public private(set) var isWorking = false
    public private(set) var didCopyShellSetup = false
    public var errorMessage: String?

    public let isCommandBundled: Bool
    public let isBrowserBridgeBundled: Bool
    public let isBrowserExtensionBundled: Bool

    private let commandURL: URL
    private let browserBridgeURL: URL
    private let browserExtensionURL: URL
    private let installer = SourceArtifactInstaller()
    private let defaults: UserDefaults

    public init(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        commandURL = bundle.bundleURL.appending(path: "Contents/Helpers/anchor")
        browserBridgeURL = bundle.bundleURL.appending(path: "Contents/Helpers/AnchorWebBridge")
        browserExtensionURL = bundle.bundleURL.appending(
            path: "Contents/Resources/AnchorWebExtension",
            directoryHint: .isDirectory
        )
        self.defaults = defaults
        isCommandBundled = FileManager.default.isExecutableFile(atPath: commandURL.path)
        isBrowserBridgeBundled = FileManager.default.isExecutableFile(atPath: browserBridgeURL.path)
        isBrowserExtensionBundled = FileManager.default.fileExists(atPath: browserExtensionURL.path)
        refresh()
    }

    public func refresh() {
        isCommandInstalled = withBookmarkedURL(for: Self.commandBookmarkKey) { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        } ?? false

        installedBrowsers = Set(MacSourceSetupBrowser.allCases.filter { browser in
            withBookmarkedURL(for: bookmarkKey(for: browser)) { supportURL in
                let manifestURL = supportURL
                    .appending(path: SourceArtifactInstaller.nativeMessagingDirectoryName)
                    .appending(path: SourceArtifactInstaller.nativeMessagingManifestName)
                return installer.browserManifestIsCurrent(
                    at: manifestURL,
                    helperURL: browserBridgeURL
                )
            } ?? false
        })
    }

    public func installCommand() async {
        guard isCommandBundled else {
            errorMessage = L10n.sourceSetupCommandMissing
            return
        }

        let panel = NSSavePanel()
        panel.title = L10n.sourceSetupCommandPanelTitle
        panel.message = L10n.sourceSetupCommandPanelMessage
        panel.nameFieldStringValue = SourceArtifactInstaller.commandName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = true
        panel.directoryURL = preferredCommandDirectory()
        guard await panel.begin() == .OK, let destinationURL = panel.url else { return }

        await performInstall {
            try installer.installCommand(from: commandURL, to: destinationURL)
            try storeBookmark(for: destinationURL, key: Self.commandBookmarkKey)
        }
    }

    public func installBrowserBridge(for browser: MacSourceSetupBrowser) async {
        guard isBrowserBridgeBundled else {
            errorMessage = L10n.sourceSetupBrowserBridgeMissing
            return
        }

        let panel = NSOpenPanel()
        panel.title = L10n.sourceSetupBrowserPanelTitle(browser.displayName)
        panel.message = L10n.sourceSetupBrowserPanelMessage(browser.displayName)
        panel.prompt = L10n.sourceSetupInstall
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = preferredBrowserSupportURL(for: browser)
        guard await panel.begin() == .OK, let supportURL = panel.url else { return }

        await performInstall {
            try installer.installBrowserManifest(
                helperURL: browserBridgeURL,
                browserSupportURL: supportURL
            )
            try storeBookmark(for: supportURL, key: bookmarkKey(for: browser))
        }
    }

    public func copyShellSetup() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(#"eval "$(anchor shell zsh)""#, forType: .string)
        didCopyShellSetup = true
    }

    public func revealBrowserExtension() {
        guard isBrowserExtensionBundled else {
            errorMessage = L10n.sourceSetupBrowserExtensionMissing
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([browserExtensionURL])
    }

    public func clearError() {
        errorMessage = nil
    }

    private func performInstall(_ operation: () throws -> Void) async {
        isWorking = true
        didCopyShellSetup = false
        defer {
            isWorking = false
            refresh()
        }
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func preferredCommandDirectory() -> URL {
        let localBin = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".local/bin", directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: localBin.path) {
            return localBin
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private func preferredBrowserSupportURL(for browser: MacSourceSetupBrowser) -> URL {
        let applicationSupport = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support", directoryHint: .isDirectory)
        let browserURL = browser.supportPathComponents.reduce(applicationSupport) { url, component in
            url.appending(path: component, directoryHint: .isDirectory)
        }
        if FileManager.default.fileExists(atPath: browserURL.path) {
            return browserURL
        }
        return applicationSupport
    }

    private func storeBookmark(for url: URL, key: String) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    private func withBookmarkedURL<T>(for key: String, operation: (URL) -> T) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if isStale, let refreshedData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(refreshedData, forKey: key)
        }
        return operation(url)
    }

    private func bookmarkKey(for browser: MacSourceSetupBrowser) -> String {
        "anchor.mac.source-setup.browser.\(browser.rawValue)"
    }

    private static let commandBookmarkKey = "anchor.mac.source-setup.command"
}
#endif
