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
    public private(set) var isWorking = false
    public private(set) var didCopyShellSetup = false
    public private(set) var codexSessionFileName: String?
    public private(set) var codexCandidates: [CodexTaskCandidate] = []
    public private(set) var trackedCodexSessionIDs = Set<String>()
    public private(set) var codexSessionsFolderName: String?
    public private(set) var taskState: AnchorTaskState?
    public var errorMessage: String?

    public let isCommandBundled: Bool

    private let commandURL: URL
    private let installer = SourceArtifactInstaller()
    private let defaults: UserDefaults
    private let onCodexSessionSelected: (@MainActor @Sendable (URL) async throws -> Void)?
    private let autoAssociationSessions: (@Sendable () async -> [AnchorSession])?
    private let onCodexSessionAssociated: (@MainActor @Sendable (URL, UUID, Bool) async throws -> Void)?
    private let currentAnchorSessionID: (@Sendable () async -> UUID?)?
    private let taskStateProvider: (@Sendable () async -> AnchorTaskState?)?
    private var codexSecurityScopedURL: URL?
    private var codexSessionsRootURL: URL?
    private var codexSessionsRootSecurityScopedURL: URL?
    private var codexSupervisor: CodexTaskSupervisor?
    private var codexDiscoveryTask: Task<Void, Never>?
    private var registeredBindings = Set<TrackedCodexSession>()
    private var observedAnchorSessionID: UUID?
    private var isRestoringCodexSession = false

    private struct TrackedCodexSession: Codable, Hashable {
        let anchorSessionID: UUID
        let codexSessionID: String
        let relativePath: String
        var automaticallyMatched: Bool? = nil
    }

    public init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        onCodexSessionSelected: (@MainActor @Sendable (URL) async throws -> Void)? = nil,
        currentAnchorSessionID: (@Sendable () async -> UUID?)? = nil,
        taskStateProvider: (@Sendable () async -> AnchorTaskState?)? = nil,
        autoAssociationSessions: (@Sendable () async -> [AnchorSession])? = nil,
        onCodexSessionAssociated: (@MainActor @Sendable (URL, UUID, Bool) async throws -> Void)? = nil
    ) {
        commandURL = bundle.bundleURL.appending(path: "Contents/Helpers/anchor")
        self.defaults = defaults
        self.onCodexSessionSelected = onCodexSessionSelected
        self.currentAnchorSessionID = currentAnchorSessionID
        self.taskStateProvider = taskStateProvider
        self.autoAssociationSessions = autoAssociationSessions
        self.onCodexSessionAssociated = onCodexSessionAssociated
        isCommandBundled = FileManager.default.isExecutableFile(atPath: commandURL.path)
        refreshCommandStatus()
    }

    public func refresh() async {
        refreshCommandStatus()
        await refreshTaskState()
        await refreshCodexCandidates()
    }

    public func refreshTaskState() async {
        let sessionID = await currentAnchorSessionID?()
        if sessionID != observedAnchorSessionID {
            observedAnchorSessionID = sessionID
            trackedCodexSessionIDs.removeAll()
            codexSessionFileName = nil
            await restoreTrackedCodexSessions()
        }
        taskState = await taskStateProvider?()
    }

    public func connectCodexSession(
        _ url: URL,
        codexSessionID: String? = nil
    ) async throws {
        let resolvedID = codexSessionID ?? Self.codexSessionID(from: url)
        guard !trackedCodexSessionIDs.contains(resolvedID) else { return }
        if let onCodexSessionAssociated {
            guard let owner = await currentAnchorSessionID?() else { throw SessionRepositoryError.noActiveSession }
            try await onCodexSessionAssociated(url, owner, false)
        } else {
            try await onCodexSessionSelected?(url)
        }
        codexSessionFileName = url.lastPathComponent
        trackedCodexSessionIDs.insert(resolvedID)
    }

    public func restoreCodexSession() async {
        guard !isRestoringCodexSession else { return }
        isRestoringCodexSession = true
        defer { isRestoringCodexSession = false }

        await restoreCodexSessionsRoot()
        await restoreTrackedCodexSessions()

        if codexSecurityScopedURL == nil,
           let ownerText = defaults.string(forKey: Self.codexBookmarkKey + ".owner"),
           let owner = UUID(uuidString: ownerText),
           let onCodexSessionAssociated,
           let activeSessions = await autoAssociationSessions?(),
           activeSessions.contains(where: { $0.id == owner }),
           let url = resolveBookmarkedURL(for: Self.codexBookmarkKey),
           url.startAccessingSecurityScopedResource() {
            do {
                try await onCodexSessionAssociated(url, owner, false)
                if await currentAnchorSessionID?() == owner {
                    trackedCodexSessionIDs.insert(Self.codexSessionID(from: url))
                    codexSessionFileName = url.lastPathComponent
                }
                codexSecurityScopedURL = url
            } catch {
                url.stopAccessingSecurityScopedResource()
                errorMessage = error.localizedDescription
            }
        }

        startCodexDiscoveryIfNeeded()
    }

    public func selectCodexSession(suggestedURL: URL? = nil) async {
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
        if let proposedURL = suggestedURL ?? locator.newestSessionFile() {
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
            if let owner = await currentAnchorSessionID?() {
                defaults.set(owner.uuidString, forKey: Self.codexBookmarkKey + ".owner")
            }
        } catch { errorMessage = error.localizedDescription }
    }

    public func authorizeCodexSessionsFolder() async {
        let panel = NSOpenPanel()
        panel.title = L10n.sourceSetupCodexFolderPanelTitle
        panel.message = L10n.sourceSetupCodexFolderPanelMessage
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = CodexSessionFileLocator().rootURL
        guard await panel.begin() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }
            codexSessionsRootSecurityScopedURL?.stopAccessingSecurityScopedResource()
            codexSessionsRootSecurityScopedURL = url
            defaults.set(bookmark, forKey: Self.codexRootBookmarkKey)
            await observeAuthorizedCodexFolder(url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func trackCodexSession(_ candidate: CodexTaskCandidate) async {
        guard let rootURL = codexSessionsRootURL else {
            await selectCodexSession(suggestedURL: candidate.fileURL)
            return
        }

        do {
            try await connectCodexSession(
                candidate.fileURL,
                codexSessionID: candidate.id
            )
            guard let anchorSessionID = await currentAnchorSessionID?(),
                  let relativePath = Self.relativePath(
                    for: candidate.fileURL,
                    under: rootURL
                  ) else {
                return
            }
            var bindings = loadTrackedCodexSessions()
            bindings.removeAll {
                $0.anchorSessionID == anchorSessionID &&
                    $0.codexSessionID == candidate.id
            }
            bindings.append(
                TrackedCodexSession(
                    anchorSessionID: anchorSessionID,
                    codexSessionID: candidate.id,
                    relativePath: relativePath
                )
            )
            saveTrackedCodexSessions(bindings)
            registeredBindings.formUnion(bindings.filter { $0.anchorSessionID == anchorSessionID && $0.codexSessionID == candidate.id })
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func isTracking(_ candidate: CodexTaskCandidate) -> Bool {
        trackedCodexSessionIDs.contains(candidate.id)
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

    public func copyShellSetup() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(#"eval "$(anchor shell zsh)""#, forType: .string)
        didCopyShellSetup = true
    }

    public func clearError() {
        errorMessage = nil
    }

    public func refreshCodexCandidates() async {
        guard let codexSupervisor else {
            codexCandidates = []
            return
        }
        codexCandidates = await codexSupervisor.snapshot()
    }

    private func restoreCodexSessionsRoot() async {
        guard codexSessionsRootSecurityScopedURL == nil,
              let url = resolveBookmarkedURL(for: Self.codexRootBookmarkKey),
              url.startAccessingSecurityScopedResource() else {
            return
        }
        codexSessionsRootSecurityScopedURL = url
        await observeAuthorizedCodexFolder(url)
    }

    /// Called only after the system picker grants folder access, or with a
    /// disposable test directory. Discovery does not depend on the settings UI.
    func observeAuthorizedCodexFolder(_ url: URL) async {
        codexSessionsRootURL = url
        codexSessionsFolderName = url.lastPathComponent
        await restoreTrackedCodexSessions()
        restartCodexDiscovery(at: url)
    }

    public func stopObserving() {
        codexDiscoveryTask?.cancel()
        codexDiscoveryTask = nil
        codexSecurityScopedURL?.stopAccessingSecurityScopedResource()
        codexSessionsRootSecurityScopedURL?.stopAccessingSecurityScopedResource()
        codexSecurityScopedURL = nil
        codexSessionsRootSecurityScopedURL = nil
    }

    private func restoreTrackedCodexSessions() async {
        guard let rootURL = codexSessionsRootURL,
              let sessions = await autoAssociationSessions?(),
              let onCodexSessionAssociated else { return }
        let selectedID = await currentAnchorSessionID?()
        let activeIDs = Set(sessions.filter { $0.status == .active }.map(\.id))
        trackedCodexSessionIDs = []
        for binding in loadTrackedCodexSessions() where activeIDs.contains(binding.anchorSessionID) {
            let url = rootURL.appending(path: binding.relativePath)
            guard Self.relativePath(for: url, under: rootURL) != nil,
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                if !registeredBindings.contains(binding) {
                    try await onCodexSessionAssociated(url, binding.anchorSessionID, binding.automaticallyMatched == true)
                    registeredBindings.insert(binding)
                }
                if binding.anchorSessionID == selectedID { trackedCodexSessionIDs.insert(binding.codexSessionID) }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func startCodexDiscoveryIfNeeded() {
        guard codexDiscoveryTask == nil, let rootURL = codexSessionsRootURL else {
            return
        }
        restartCodexDiscovery(at: rootURL)
    }

    private func restartCodexDiscovery(at rootURL: URL) {
        codexDiscoveryTask?.cancel()
        let supervisor = CodexTaskSupervisor(rootURL: rootURL)
        codexSupervisor = supervisor
        codexDiscoveryTask = Task { [weak self, supervisor] in
            while !Task.isCancelled {
                guard let self else { return }
                let candidates = await supervisor.snapshot()
                self.codexCandidates = candidates
                await self.automaticallyAssociate(candidates)
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    private func automaticallyAssociate(_ candidates: [CodexTaskCandidate]) async {
        guard let root = codexSessionsRootURL, let autoAssociationSessions, let onCodexSessionAssociated else { return }
        await refreshTaskState()
        let sessions = await autoAssociationSessions()
        for candidate in candidates {
            guard !Task.isCancelled,
                  !loadTrackedCodexSessions().contains(where: { $0.codexSessionID == candidate.id }),
                  let started = candidate.createdAt,
                  sessions.contains(where: { $0.status == .active && started >= $0.startedAt }),
                  let path = Self.relativePath(for: candidate.fileURL, under: root) else { continue }
            let request = await Task.detached(priority: .utility) {
                CodexAutoAssociation.firstUserRequest(at: candidate.fileURL)
            }.value
            guard let request,
                  let sessionID = CodexAutoAssociation.matchingSession(text: request, conversationStartedAt: started, sessions: sessions) else { continue }
            do {
                try await onCodexSessionAssociated(candidate.fileURL, sessionID, true)
                var bindings = loadTrackedCodexSessions()
                let binding = TrackedCodexSession(anchorSessionID: sessionID, codexSessionID: candidate.id, relativePath: path, automaticallyMatched: true)
                bindings.append(binding)
                registeredBindings.insert(binding)
                saveTrackedCodexSessions(bindings)
                if await currentAnchorSessionID?() == sessionID {
                    trackedCodexSessionIDs.insert(candidate.id)
                }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func loadTrackedCodexSessions() -> [TrackedCodexSession] {
        guard let data = defaults.data(forKey: Self.codexTrackedSessionsKey) else {
            return []
        }
        return (try? JSONDecoder().decode([TrackedCodexSession].self, from: data)) ?? []
    }

    private func saveTrackedCodexSessions(_ sessions: [TrackedCodexSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: Self.codexTrackedSessionsKey)
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

    private static func codexSessionID(from url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let suffix = String(stem.suffix(36))
        return UUID(uuidString: suffix) == nil ? url.lastPathComponent : suffix.lowercased()
    }

    private static func relativePath(for fileURL: URL, under rootURL: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard filePath.hasPrefix(prefix) else { return nil }
        return String(filePath.dropFirst(prefix.count))
    }

    private static let commandBookmarkKey = "anchor.mac.source-setup.command"
    private static let codexBookmarkKey = "anchor.mac.source-setup.codex-session"
    private static let codexRootBookmarkKey = "anchor.mac.source-setup.codex-root.v1"
    private static let codexTrackedSessionsKey = "anchor.mac.source-setup.codex-tracked.v1"
}
#endif
