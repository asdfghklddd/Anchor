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

    fileprivate var target: ChromiumBrowserTarget {
        ChromiumBrowserTarget(rawValue: rawValue) ?? .chrome
    }

    fileprivate var storeURL: URL? {
        switch self {
        case .chrome, .brave, .chromium:
            URL(
                string: "https://chromewebstore.google.com/detail/anchor/\(BrowserHostConfiguration.extensionID)"
            )
        case .edge:
            nil
        }
    }
}

@MainActor
@Observable
public final class MacSourceSetupModel {
    public private(set) var isCommandInstalled = false
    public private(set) var configuredBrowsers = Set<MacSourceSetupBrowser>()
    public private(set) var detectedBrowsers = Set<MacSourceSetupBrowser>()
    public private(set) var preferredBrowser: MacSourceSetupBrowser?
    public private(set) var awaitingConfirmationBrowser: MacSourceSetupBrowser?
    public private(set) var lastBrowserConnectionAt: Date?
    public private(set) var isWorking = false
    public private(set) var didCopyShellSetup = false
    public var errorMessage: String?

    public let isCommandBundled: Bool
    public let isBrowserBridgeBundled: Bool
    public let isBrowserExtensionBundled: Bool

    public var browsersAvailableForConnection: [MacSourceSetupBrowser] {
        MacSourceSetupBrowser.allCases.filter {
            detectedBrowsers.contains($0) && $0.storeURL != nil
        }
    }

    private let commandURL: URL
    private let browserBridgeURL: URL
    private let browserExtensionURL: URL
    private let installer = SourceArtifactInstaller()
    private let browserSetupService = BrowserSetupServiceClient()
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
        detectBrowsers()
        refreshCommandStatus()
    }

    public func refresh() async {
        refreshCommandStatus()
        detectBrowsers()
        var currentBrowsers = Set<MacSourceSetupBrowser>()
        for browser in MacSourceSetupBrowser.allCases {
            if (try? await browserSetupService.browserIsPrepared(browser)) == true {
                currentBrowsers.insert(browser)
            }
        }
        configuredBrowsers = currentBrowsers
        lastBrowserConnectionAt = BrowserConnectionReceipt.load()?.occurredAt
        if let attempt = awaitingConfirmationBrowser,
           currentBrowsers.contains(attempt),
           let lastBrowserConnectionAt,
           lastBrowserConnectionAt >= (connectionAttemptStartedAt ?? .distantFuture) {
            awaitingConfirmationBrowser = nil
        }
    }

    private func refreshCommandStatus() {
        isCommandInstalled = withBookmarkedURL(for: Self.commandBookmarkKey) { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        } ?? false
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

    public func connectBrowser(_ browser: MacSourceSetupBrowser) async {
        guard isBrowserBridgeBundled else {
            errorMessage = L10n.sourceSetupBrowserBridgeMissing
            return
        }
        guard let storeURL = browser.storeURL else {
            errorMessage = L10n.sourceSetupBrowserStoreUnavailable(browser.displayName)
            return
        }

        isWorking = true
        didCopyShellSetup = false
        defer { isWorking = false }
        do {
            try await browserSetupService.prepareBrowser(browser)
            configuredBrowsers.insert(browser)
            awaitingConfirmationBrowser = browser
            connectionAttemptStartedAt = .now
            try await openBrowserConfirmation(for: browser, storeURL: storeURL)
        } catch {
            errorMessage = error.localizedDescription
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
            refreshCommandStatus()
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

    private func detectBrowsers() {
        detectedBrowsers = Set(MacSourceSetupBrowser.allCases.filter { browser in
            NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: browser.target.applicationBundleIdentifier
            ) != nil
        })

        if let webURL = URL(string: "https://anchor.local"),
           let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: webURL),
           let defaultIdentifier = Bundle(url: defaultBrowserURL)?.bundleIdentifier,
           let browser = MacSourceSetupBrowser.allCases.first(where: {
               $0.target.applicationBundleIdentifier == defaultIdentifier && $0.storeURL != nil
           }) {
            preferredBrowser = browser
        } else {
            preferredBrowser = MacSourceSetupBrowser.allCases.first(where: {
                detectedBrowsers.contains($0) && $0.storeURL != nil
            })
        }
    }

    private func openBrowserConfirmation(
        for browser: MacSourceSetupBrowser,
        storeURL: URL
    ) async throws {
        let bundleIdentifier = browser.target.applicationBundleIdentifier
        let isRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).isEmpty
        if browser.target.supportsExternalWebStoreInstall,
           !isRunning,
           let applicationURL = NSWorkspace.shared.urlForApplication(
               withBundleIdentifier: bundleIdentifier
           ) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            _ = try await NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            )
            return
        }
        guard NSWorkspace.shared.open(storeURL) else {
            throw MacSourceSetupError.couldNotOpenBrowserStore
        }
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

    private var connectionAttemptStartedAt: Date?
    private static let commandBookmarkKey = "anchor.mac.source-setup.command"
}

private enum MacSourceSetupError: LocalizedError {
    case couldNotOpenBrowserStore

    var errorDescription: String? {
        switch self {
        case .couldNotOpenBrowserStore:
            L10n.sourceSetupBrowserStoreOpenFailed
        }
    }
}
#endif
