#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
public final class MacSourceSetupModel {
    public private(set) var isCommandInstalled = false
    public private(set) var isSafariExtensionEnabled = false
    public private(set) var isAwaitingSafariConfirmation = false
    public private(set) var isWorking = false
    public private(set) var didCopyShellSetup = false
    public private(set) var codexSessionFileName: String?
    public private(set) var taskState: AnchorTaskState?
    public var errorMessage: String?

    public let isCommandBundled: Bool
    public let isSafariExtensionBundled: Bool

    private let commandURL: URL
    private let installer = SourceArtifactInstaller()
    private let safariExtensionClient = SafariExtensionStateClient()
    private let defaults: UserDefaults
    private let onCodexSessionSelected: (@MainActor @Sendable (URL) async throws -> Void)?
    private let taskStateProvider: (@Sendable () async -> AnchorTaskState?)?
    private var codexSecurityScopedURL: URL?
    private var isRestoringCodexSession = false

    public init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        onCodexSessionSelected: (@MainActor @Sendable (URL) async throws -> Void)? = nil,
        taskStateProvider: (@Sendable () async -> AnchorTaskState?)? = nil
    ) {
        commandURL = bundle.bundleURL.appending(path: "Contents/Helpers/anchor")
        let safariExtensionURL = bundle.bundleURL.appending(
            path: "Contents/PlugIns/AnchorSafariExtension.appex",
            directoryHint: .isDirectory
        )
        self.defaults = defaults
        self.onCodexSessionSelected = onCodexSessionSelected
        self.taskStateProvider = taskStateProvider
        isCommandBundled = FileManager.default.isExecutableFile(atPath: commandURL.path)
        isSafariExtensionBundled = FileManager.default.fileExists(
            atPath: safariExtensionURL.path
        )
        refreshCommandStatus()
    }

    public func refresh() async {
        refreshCommandStatus()
        isSafariExtensionEnabled = (try? await safariExtensionClient.isEnabled()) == true
        if isSafariExtensionEnabled {
            isAwaitingSafariConfirmation = false
        }
        await refreshTaskState()
    }

    public func refreshTaskState() async {
        taskState = await taskStateProvider?()
    }

    public func connectCodexSession(_ url: URL) async throws {
        try await onCodexSessionSelected?(url)
        codexSessionFileName = url.lastPathComponent
    }

    public func restoreCodexSession() async {
        guard !isRestoringCodexSession,
              codexSecurityScopedURL == nil,
              let url = resolveBookmarkedURL(for: Self.codexBookmarkKey),
              url.startAccessingSecurityScopedResource() else { return }
        isRestoringCodexSession = true
        defer { isRestoringCodexSession = false }
        do {
            try await connectCodexSession(url)
            codexSecurityScopedURL = url
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = error.localizedDescription
        }
    }

    public func selectCodexSession() async {
        let panel = NSOpenPanel()
        let locator = CodexSessionFileLocator()
        panel.title = L10n.sourceSetupCodexPanelTitle
        panel.message = L10n.sourceSetupCodexPanelMessage
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "jsonl") ?? .data]
        // Discovery reads metadata only. The system panel remains the single
        // user confirmation that grants Anchor access to the proposed file.
        if let proposedURL = locator.newestSessionFile() {
            panel.directoryURL = proposedURL.deletingLastPathComponent()
            panel.nameFieldStringValue = proposedURL.lastPathComponent
            panel.message = "\(L10n.sourceSetupCodexPanelMessage)\n\(proposedURL.lastPathComponent)"
        } else {
            panel.directoryURL = locator.rootURL
        }
        guard await panel.begin() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            let didAccess = url.startAccessingSecurityScopedResource()
            guard didAccess else { throw CocoaError(.fileReadNoPermission) }
            do { try await connectCodexSession(url) }
            catch { url.stopAccessingSecurityScopedResource(); throw error }
            codexSecurityScopedURL?.stopAccessingSecurityScopedResource()
            codexSecurityScopedURL = url
            defaults.set(bookmark, forKey: Self.codexBookmarkKey)
        } catch { errorMessage = error.localizedDescription }
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

    public func openSafariExtensionSettings() async {
        guard isSafariExtensionBundled else {
            errorMessage = L10n.sourceSetupSafariExtensionMissing
            return
        }

        isWorking = true
        didCopyShellSetup = false
        defer { isWorking = false }
        do {
            try await safariExtensionClient.showPreferences()
            isAwaitingSafariConfirmation = !isSafariExtensionEnabled
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

    public func clearError() {
        errorMessage = nil
    }

    private func refreshCommandStatus() {
        isCommandInstalled = withBookmarkedURL(for: Self.commandBookmarkKey) { url in
            FileManager.default.isExecutableFile(atPath: url.path)
        } ?? false
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

    private func storeBookmark(for url: URL, key: String) throws {
        let data = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(data, forKey: key)
    }

    private func withBookmarkedURL<T>(for key: String, operation: (URL) -> T) -> T? {
        guard let url = resolveBookmarkedURL(for: key) else { return nil }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        return operation(url)
    }

    private func resolveBookmarkedURL(for key: String) -> URL? {
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
        if isStale, let refreshedData = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            defaults.set(refreshedData, forKey: key)
        }
        return url
    }

    private static let commandBookmarkKey = "anchor.mac.source-setup.command"
    private static let codexBookmarkKey = "anchor.mac.source-setup.codex-session"
}
#endif
