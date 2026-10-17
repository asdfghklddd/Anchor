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
    /// Every recent user conversation for the dashboard, anchored or not.
    /// Kept in memory only; it is never saved or sent to the phone.
    public private(set) var codexConversations: [CodexConversationSummary] = []
    public private(set) var trackedCodexSessionIDs = Set<String>()
    public private(set) var codexSessionsFolderName: String?
    public private(set) var taskState: AnchorTaskState?
    public var errorMessage: String?

    public var showsCodexOnboarding = false
    public var showsCodexReview = false
    public var onNeedsAttention: (@MainActor () -> Void)?
    public private(set) var codexSuggestions: [CodexSuggestion] = []
    public private(set) var activeTasks: [AnchorSession] = []
    private var announcedSuggestions = Set<String>()

    public struct CodexSuggestion: Identifiable {
        public var id: String { candidate.id }
        public let candidate: CodexTaskCandidate
        public let suggestedTaskIDs: [UUID]
    }

    public func presentCodexSetupIfNeeded() {
        guard codexSessionsFolderName == nil else { return }
        showsCodexOnboarding = true
        onNeedsAttention?()
    }

    public func finishCodexOnboarding() {
        showsCodexOnboarding = false
        if !codexSuggestions.isEmpty { showsCodexReview = true }
    }

    public func dismissSuggestion(_ suggestion: CodexSuggestion) {
        var ignored = Set(defaults.stringArray(forKey: Self.codexIgnoredKey) ?? [])
        for taskID in suggestion.suggestedTaskIDs {
            ignored.insert(suggestion.id + ":" + taskID.uuidString)
        }
        defaults.set(Array(ignored), forKey: Self.codexIgnoredKey)
        codexSuggestions.removeAll { $0.id == suggestion.id }
    }

    public func confirmSuggestion(_ suggestion: CodexSuggestion, taskID: UUID) async {
        guard !isWorking, let root = codexSessionsRootURL,
              let onCodexSessionAssociated else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        let sessions = await autoAssociationSessions?() ?? []
        guard sessions.contains(where: { $0.id == taskID && $0.status == .active }),
              !loadTrackedCodexSessions().contains(where: { $0.codexSessionID == suggestion.id }),
              let path = Self.relativePath(for: suggestion.candidate.fileURL, under: root),
              FileManager.default.isReadableFile(atPath: suggestion.candidate.fileURL.path) else {
            errorMessage = "任务或会话已不可用，请重新查看匹配结果。"
            return
        }
        do {
            try await onCodexSessionAssociated(suggestion.candidate.fileURL, taskID, false)
            let binding = TrackedCodexSession(anchorSessionID: taskID, codexSessionID: suggestion.id, relativePath: path)
            var bindings = loadTrackedCodexSessions()
            bindings.append(binding)
            saveTrackedCodexSessions(bindings)
            registeredBindings.insert(binding)
            if await currentAnchorSessionID?() == taskID { trackedCodexSessionIDs.insert(suggestion.id) }
            codexSuggestions.removeAll { $0.id == suggestion.id }
        } catch { errorMessage = error.localizedDescription }
    }

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
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        let panel = NSOpenPanel()
        panel.title = L10n.sourceSetupCodexFolderPanelTitle
        panel.message = L10n.sourceSetupCodexFolderPanelMessage
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = CodexSessionFileLocator().rootURL
        panel.showsHiddenFiles = true
        panel.prompt = "授权并开始查找"
        guard await panel.begin() == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            guard url.startAccessingSecurityScopedResource() else {
                throw CocoaError(.fileReadNoPermission)
            }
            do {
                let sessionsURL = url.lastPathComponent == ".codex" ? url.appending(path: "sessions") : url
                _ = try FileManager.default.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: nil)
                guard url.lastPathComponent == "sessions" || url.lastPathComponent == ".codex" else {
                    throw NSError(domain: "Anchor.CodexSetup", code: 1, userInfo: [NSLocalizedDescriptionKey: "请选择 Codex 的 sessions 文件夹或 .codex 文件夹。"])
                }
            } catch {
                url.stopAccessingSecurityScopedResource()
                throw error
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
            codexConversations = []
            return
        }
        publish(await codexSupervisor.summaries())
    }

    /// Assigns only real changes, so a quiet two-second scan redraws nothing.
    private func publish(_ summaries: [CodexConversationSummary]) {
        if codexConversations != summaries { codexConversations = summaries }
        let candidates = summaries.map(\.candidate)
        if codexCandidates != candidates { codexCandidates = candidates }
    }

    private func restoreCodexSessionsRoot() async {
        guard codexSessionsRootSecurityScopedURL == nil,
              let url = resolveBookmarkedURL(for: Self.codexRootBookmarkKey),
              url.startAccessingSecurityScopedResource() else {
            return
        }
        let sessionsURL = url.lastPathComponent == ".codex" ? url.appending(path: "sessions") : url
        do {
            _ = try FileManager.default.contentsOfDirectory(at: sessionsURL, includingPropertiesForKeys: nil)
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = "之前连接的 Codex 文件夹已无法读取，请重新授权。"
            return
        }
        codexSessionsRootSecurityScopedURL = url
        await observeAuthorizedCodexFolder(url)
    }

    /// Called only after the system picker grants folder access, or with a
    /// disposable test directory. Discovery does not depend on the settings UI.
    func observeAuthorizedCodexFolder(_ url: URL) async {
        let root = url.lastPathComponent == ".codex" ? url.appending(path: "sessions") : url
        codexSessionsRootURL = root
        codexSessionsFolderName = root.lastPathComponent
        await restoreTrackedCodexSessions()
        restartCodexDiscovery(at: root)
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
        // Earlier builds could auto-match guardian or subagent logs; stop observing them.
        let bindings = loadTrackedCodexSessions()
        let retained = bindings.filter { binding in
            binding.automaticallyMatched != true
                || CodexSessionMetadata.read(from: rootURL.appending(path: binding.relativePath))?
                    .isUserConversation != false
        }
        if retained.count != bindings.count { saveTrackedCodexSessions(retained) }
        for binding in retained where activeIDs.contains(binding.anchorSessionID) {
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
                self.publish(await supervisor.summaries())
                await self.automaticallyAssociate(self.codexCandidates)
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    func automaticallyAssociate(_ candidates: [CodexTaskCandidate]) async {
        guard let root = codexSessionsRootURL, let autoAssociationSessions else { return }
        await refreshTaskState()
        let sessions = await autoAssociationSessions().filter { $0.status == .active }
        activeTasks = sessions
        let ignored = Set(defaults.stringArray(forKey: Self.codexIgnoredKey) ?? [])
        var suggestions: [CodexSuggestion] = []
        for candidate in candidates {
            guard !Task.isCancelled,
                  !loadTrackedCodexSessions().contains(where: { $0.codexSessionID == candidate.id }),
                  sessions.contains(where: { candidate.modifiedAt >= $0.startedAt }),
                  Self.relativePath(for: candidate.fileURL, under: root) != nil else { continue }
            let request = await Task.detached(priority: .utility) {
                CodexAutoAssociation.latestUserRequest(at: candidate.fileURL)
            }.value
            guard !Task.isCancelled, let request else { continue }
            let matches = CodexAutoAssociation.suggestedSessionIDs(text: request, sessions: sessions)
                .filter { !ignored.contains(candidate.id + ":" + $0.uuidString) }
            guard !matches.isEmpty else { continue }
            suggestions.append(CodexSuggestion(candidate: candidate, suggestedTaskIDs: matches))
        }
        // A confirmation may finish while the request is read off the main actor.
        guard !Task.isCancelled else { return }
        let boundIDs = Set(loadTrackedCodexSessions().map(\.codexSessionID))
        let latestIgnored = Set(defaults.stringArray(forKey: Self.codexIgnoredKey) ?? [])
        codexSuggestions = suggestions.compactMap { suggestion in
            guard !boundIDs.contains(suggestion.id) else { return nil }
            let matches = suggestion.suggestedTaskIDs.filter { !latestIgnored.contains(suggestion.id + ":" + $0.uuidString) }
            return matches.isEmpty ? nil : CodexSuggestion(candidate: suggestion.candidate, suggestedTaskIDs: matches)
        }
        let newIDs = Set(codexSuggestions.map(\.id)).subtracting(announcedSuggestions)
        announcedSuggestions.formUnion(newIDs)
        if !newIDs.isEmpty && !showsCodexOnboarding {
            showsCodexReview = true
            onNeedsAttention?()
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

    private static let codexIgnoredKey = "anchor.mac.source-setup.codex-ignored.v1"
    private static let commandBookmarkKey = "anchor.mac.source-setup.command"
    private static let codexBookmarkKey = "anchor.mac.source-setup.codex-session"
    private static let codexRootBookmarkKey = "anchor.mac.source-setup.codex-root.v1"
    private static let codexTrackedSessionsKey = "anchor.mac.source-setup.codex-tracked.v1"
}
#endif
