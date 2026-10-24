#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import Foundation
import Observation

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
    /// Set once the person granted Claude Code's `projects` folder.
    public private(set) var claudeProjectsFolderName: String?
    public private(set) var taskState: AnchorTaskState?

    /// Any agent's conversations can be read: Codex, Claude Code, or both.
    public var hasConversationSource: Bool {
        codexSessionsFolderName != nil || claudeProjectsFolderName != nil
    }
    public var errorMessage: String?

    public var showsCodexOnboarding = false
    public var onNeedsAttention: (@MainActor () -> Void)?
    /// Called with conversations whose latest turn just ended (see `CodexTurnEndDetector`).
    public var onCodexTurnsEnded: (@MainActor ([CodexConversationSummary]) -> Void)?
    private var turnEnds = CodexTurnEndDetector()
    public private(set) var activeTasks: [AnchorSession] = []
    /// Conversation ID to the task it is attached to.
    public private(set) var conversationTasks: [String: UUID] = [:]
    /// Conversation ID to the step it serves, when the request named one clearly.
    public private(set) var conversationSteps: [String: UUID] = [:]
    /// Recent conversations Anchor could not place with confidence, waiting for one click.
    public private(set) var unsortedConversations: [CodexConversationSummary] = []
    /// For an unsorted conversation, the tasks its words leaned towards, best first.
    public private(set) var unsortedCandidates: [String: [UUID]] = [:]
    private var matchMemory = TaskMatcher.Memory()
    private var currentTask: (id: UUID, since: Date)?
    /// Request text read for matching, kept in memory only and keyed by the log's change time.
    private var requestCache: [String: (stamp: Date, text: String)] = [:]
    private var lastPlacementOperation: Task<Void, Never>?

    public func presentCodexSetupIfNeeded() {
        guard !hasConversationSource else { return }
        showsCodexOnboarding = true
        onNeedsAttention?()
    }

    public func finishCodexOnboarding() {
        showsCodexOnboarding = false
    }

    /// The person files a conversation under a task, or moves it from another one.
    public func assign(_ conversation: CodexConversationSummary, to taskID: UUID) async {
        await serially { await self.performAssign(conversation, to: taskID) }
    }

    /// The person says a conversation is not part of any task: stop following it.
    public func ignore(_ conversation: CodexConversationSummary) async {
        await serially { await self.performIgnore(conversation) }
    }

    /// Placing, filing and ignoring run one at a time, so a scan and a click
    /// can never bind the same conversation twice.
    private func serially(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = lastPlacementOperation
        let current = Task { @MainActor in
            await previous?.value
            await operation()
        }
        lastPlacementOperation = current
        await current.value
    }

    private func performAssign(_ conversation: CodexConversationSummary, to taskID: UUID) async {
        guard !isWorking, let onCodexSessionAssociated,
              let location = location(of: conversation.candidate.fileURL) else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        let work = await work(for: conversation)
        do {
            var bindings = loadTrackedCodexSessions()
            if let old = bindings.first(where: { $0.codexSessionID == conversation.id }) {
                guard old.anchorSessionID != taskID else { return }
                try await onCodexSessionUnbound?(conversation.candidate.fileURL, old.anchorSessionID)
                registeredBindings.remove(old)
                bindings.removeAll { $0.codexSessionID == conversation.id }
                saveTrackedCodexSessions(bindings)
            }
            matchMemory.correct(work, to: taskID)
            saveMatchMemory()
            var step: UUID?
            if case let .task(_, matched, _) = TaskMatcher.place(work, tasks: activeTasks, current: nil, memory: matchMemory) {
                step = matched
            }
            try await onCodexSessionAssociated(conversation.candidate.fileURL, taskID, false, step)
            let binding = TrackedCodexSession(anchorSessionID: taskID, codexSessionID: conversation.id,
                                              relativePath: location.path, automaticallyMatched: false, stepID: step,
                                              source: location.source)
            bindings.append(binding)
            saveTrackedCodexSessions(bindings)
            registeredBindings.insert(binding)
            conversationTasks[conversation.id] = taskID
            conversationSteps[conversation.id] = step
            unsortedConversations.removeAll { $0.id == conversation.id }
            unsortedCandidates[conversation.id] = nil
            if taskID == observedAnchorSessionID { trackedCodexSessionIDs.insert(conversation.id) }
            else { trackedCodexSessionIDs.remove(conversation.id) }
        } catch { errorMessage = error.localizedDescription }
    }

    private func performIgnore(_ conversation: CodexConversationSummary) async {
        let work = await work(for: conversation)
        var bindings = loadTrackedCodexSessions()
        if let old = bindings.first(where: { $0.codexSessionID == conversation.id }) {
            do {
                try await onCodexSessionUnbound?(conversation.candidate.fileURL, old.anchorSessionID)
            } catch { errorMessage = error.localizedDescription }
            registeredBindings.remove(old)
            bindings.removeAll { $0.codexSessionID == conversation.id }
            saveTrackedCodexSessions(bindings)
        }
        matchMemory.ignore(work)
        saveMatchMemory()
        conversationTasks[conversation.id] = nil
        conversationSteps[conversation.id] = nil
        unsortedConversations.removeAll { $0.id == conversation.id }
        unsortedCandidates[conversation.id] = nil
    }

    public func isIgnored(_ conversationID: String) -> Bool {
        matchMemory.ignored.contains(conversationID)
    }

    public let isCommandBundled: Bool

    private let commandURL: URL
    private let installer = SourceArtifactInstaller()
    private let defaults: UserDefaults
    private let onCodexSessionSelected: (@MainActor @Sendable (URL) async throws -> Void)?
    private let autoAssociationSessions: (@Sendable () async -> [AnchorSession])?
    private let onCodexSessionAssociated: (@MainActor @Sendable (URL, UUID, Bool, UUID?) async throws -> Void)?
    private let onCodexSessionUnbound: (@MainActor @Sendable (URL, UUID) async throws -> Void)?
    /// Learns what each scanned conversation is called, for the names the phone shows
    /// and the recaps written when the person leaves.
    public let summaryBook: SummaryBook?
    private let currentAnchorSessionID: (@Sendable () async -> UUID?)?
    private let taskStateProvider: (@Sendable () async -> AnchorTaskState?)?
    private var codexSecurityScopedURL: URL?
    private var codexSessionsRootURL: URL?
    private var codexSessionsRootSecurityScopedURL: URL?
    private var codexSupervisor: CodexTaskSupervisor?
    private var claudeRootURL: URL?
    private var claudeRootSecurityScopedURL: URL?
    private var claudeSupervisor: CodexTaskSupervisor?
    private var codexDiscoveryTask: Task<Void, Never>?
    private var registeredBindings = Set<TrackedCodexSession>()
    private var observedAnchorSessionID: UUID?
    private var isRestoringCodexSession = false

    private struct TrackedCodexSession: Codable, Hashable {
        let anchorSessionID: UUID
        let codexSessionID: String
        let relativePath: String
        var automaticallyMatched: Bool? = nil
        var stepID: UUID? = nil
        /// Which folder `relativePath` is under; `nil` for Codex, as saved before Claude Code.
        var source: ConversationDialect? = nil
    }

    /// The folder a conversation's log lives in, and its path there.
    private func location(of url: URL) -> (source: ConversationDialect?, path: String)? {
        if let root = codexSessionsRootURL, let path = Self.relativePath(for: url, under: root) { return (nil, path) }
        if let root = claudeRootURL, let path = Self.relativePath(for: url, under: root) { return (.claudeCode, path) }
        return nil
    }

    private func root(for source: ConversationDialect?) -> URL? {
        source == .claudeCode ? claudeRootURL : codexSessionsRootURL
    }

    public init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        onCodexSessionSelected: (@MainActor @Sendable (URL) async throws -> Void)? = nil,
        currentAnchorSessionID: (@Sendable () async -> UUID?)? = nil,
        taskStateProvider: (@Sendable () async -> AnchorTaskState?)? = nil,
        autoAssociationSessions: (@Sendable () async -> [AnchorSession])? = nil,
        onCodexSessionAssociated: (@MainActor @Sendable (URL, UUID, Bool, UUID?) async throws -> Void)? = nil,
        onCodexSessionUnbound: (@MainActor @Sendable (URL, UUID) async throws -> Void)? = nil,
        summaryBook: SummaryBook? = nil
    ) {
        commandURL = bundle.bundleURL.appending(path: "Contents/Helpers/anchor")
        self.defaults = defaults
        self.onCodexSessionSelected = onCodexSessionSelected
        self.currentAnchorSessionID = currentAnchorSessionID
        self.taskStateProvider = taskStateProvider
        self.autoAssociationSessions = autoAssociationSessions
        self.onCodexSessionAssociated = onCodexSessionAssociated
        self.onCodexSessionUnbound = onCodexSessionUnbound
        self.summaryBook = summaryBook
        if let data = defaults.data(forKey: Self.matchMemoryKey),
           let memory = try? JSONDecoder().decode(TaskMatcher.Memory.self, from: data) {
            matchMemory = memory
        }
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
            currentTask = sessionID.map { (id: $0, since: .now) }
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
            try await onCodexSessionAssociated(url, owner, false, nil)
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
        await restoreClaudeRoot()
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
                try await onCodexSessionAssociated(url, owner, false, nil)
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

    /// Grants one persistent, folder-scoped access flow for the local agent logs.
    /// The person can select Codex `sessions` and Claude Code `projects` in the
    /// same panel; discovery then follows new conversations without per-session
    /// approval. Only these two log folders are accepted.
    public func authorizeAgentSessionFolders() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        let codexSessionsURL = CodexSessionFileLocator().rootURL.standardizedFileURL
        let homeURL = codexSessionsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let claudeProjectsURL = homeURL
            .appending(path: ".claude/projects", directoryHint: .isDirectory)
            .standardizedFileURL

        let panel = NSOpenPanel()
        panel.title = L10n.sourceSetupAgentFoldersPanelTitle
        panel.message = L10n.sourceSetupAgentFoldersPanelMessage
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = homeURL
        panel.showsHiddenFiles = true
        panel.prompt = L10n.sourceSetupAgentFoldersPanelPrompt
        guard await panel.begin() == .OK else { return }

        var codexSelection: URL?
        var claudeSelection: URL?
        for url in panel.urls {
            let selection = url.standardizedFileURL
            if selection == codexSessionsURL {
                codexSelection = url
            } else if selection == claudeProjectsURL {
                claudeSelection = url
            }
        }
        guard codexSelection != nil || claudeSelection != nil else {
            errorMessage = L10n.sourceSetupAgentFoldersSelectionError
            return
        }

        var accessedURLs: [URL] = []
        var codexBookmark: Data?
        var claudeBookmark: Data?
        do {
            if let codexSelection {
                codexBookmark = try Self.folderBookmark(for: codexSelection)
                guard codexSelection.startAccessingSecurityScopedResource() else {
                    throw CocoaError(.fileReadNoPermission)
                }
                accessedURLs.append(codexSelection)
                _ = try FileManager.default.contentsOfDirectory(
                    at: codexSelection,
                    includingPropertiesForKeys: nil
                )
            }
            if let claudeSelection {
                claudeBookmark = try Self.folderBookmark(for: claudeSelection)
                guard claudeSelection.startAccessingSecurityScopedResource() else {
                    throw CocoaError(.fileReadNoPermission)
                }
                accessedURLs.append(claudeSelection)
                _ = try FileManager.default.contentsOfDirectory(
                    at: claudeSelection,
                    includingPropertiesForKeys: nil
                )
            }
        } catch {
            for url in accessedURLs { url.stopAccessingSecurityScopedResource() }
            errorMessage = error.localizedDescription
            return
        }

        if let codexSelection, let codexBookmark {
            codexSessionsRootSecurityScopedURL?.stopAccessingSecurityScopedResource()
            codexSessionsRootSecurityScopedURL = codexSelection
            defaults.set(codexBookmark, forKey: Self.codexRootBookmarkKey)
            await observeAuthorizedCodexFolder(codexSelection)
        }
        if let claudeSelection, let claudeBookmark {
            claudeRootSecurityScopedURL?.stopAccessingSecurityScopedResource()
            claudeRootSecurityScopedURL = claudeSelection
            defaults.set(claudeBookmark, forKey: Self.claudeRootBookmarkKey)
            await observeAuthorizedClaudeFolder(claudeSelection)
        }
        if hasConversationSource { finishCodexOnboarding() }
    }

    /// Compatibility entry point. Both integrations use the combined picker.
    public func authorizeCodexSessionsFolder() async {
        await authorizeAgentSessionFolders()
    }

    /// Compatibility entry point. Both integrations share the same first-run
    /// folder picker so neither can prompt once per provider or conversation.
    public func authorizeClaudeCodeFolder() async {
        await authorizeAgentSessionFolders()
    }

    public func trackCodexSession(_ candidate: CodexTaskCandidate) async {
        guard let rootURL = codexSessionsRootURL else { return }

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
        guard codexSupervisor != nil || claudeSupervisor != nil else {
            codexCandidates = []
            codexConversations = []
            return
        }
        publish(await currentSummaries())
    }

    /// Recent conversations from every granted agent, newest first.
    private func currentSummaries() async -> [CodexConversationSummary] {
        var summaries = await codexSupervisor?.summaries() ?? []
        summaries += await claudeSupervisor?.summaries() ?? []
        return summaries.sorted { lhs, rhs in
            if lhs.candidate.modifiedAt != rhs.candidate.modifiedAt {
                return lhs.candidate.modifiedAt > rhs.candidate.modifiedAt
            }
            return lhs.id < rhs.id
        }
    }

    /// Assigns only real changes, so a quiet two-second scan redraws nothing.
    private func publish(_ summaries: [CodexConversationSummary]) {
        if codexConversations != summaries {
            codexConversations = summaries
            if let summaryBook {
                let seen = Dictionary(summaries.map { ($0.candidate.fileURL, $0.nameSource) }) { first, _ in first }
                Task { await summaryBook.note(seen) }
            }
        }
        let candidates = summaries.map(\.candidate)
        if codexCandidates != candidates { codexCandidates = candidates }
        // A conversation the person said is not part of a task never pings.
        let endings = turnEnds.endings(in: summaries, now: .now).filter { !isIgnored($0.id) }
        if !endings.isEmpty { onCodexTurnsEnded?(endings) }
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
        codexSupervisor = CodexTaskSupervisor(rootURL: root)
        await restoreTrackedCodexSessions()
        restartCodexDiscovery()
    }

    /// The same for Claude Code's `projects` folder.
    func observeAuthorizedClaudeFolder(_ url: URL) async {
        claudeRootURL = url
        claudeProjectsFolderName = url.lastPathComponent
        claudeSupervisor = CodexTaskSupervisor(rootURL: url, dialect: .claudeCode)
        await restoreTrackedCodexSessions()
        restartCodexDiscovery()
    }

    private func restoreClaudeRoot() async {
        guard claudeRootSecurityScopedURL == nil,
              let url = resolveBookmarkedURL(for: Self.claudeRootBookmarkKey),
              url.startAccessingSecurityScopedResource() else { return }
        do {
            _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        } catch {
            url.stopAccessingSecurityScopedResource()
            errorMessage = MacClaudeCodeCopy.lostAccess
            return
        }
        claudeRootSecurityScopedURL = url
        await observeAuthorizedClaudeFolder(url)
    }

    public func stopObserving() {
        codexDiscoveryTask?.cancel()
        codexDiscoveryTask = nil
        codexSecurityScopedURL?.stopAccessingSecurityScopedResource()
        codexSessionsRootSecurityScopedURL?.stopAccessingSecurityScopedResource()
        claudeRootSecurityScopedURL?.stopAccessingSecurityScopedResource()
        codexSecurityScopedURL = nil
        codexSessionsRootSecurityScopedURL = nil
        claudeRootSecurityScopedURL = nil
    }

    private func restoreTrackedCodexSessions() async {
        guard codexSessionsRootURL != nil || claudeRootURL != nil,
              let sessions = await autoAssociationSessions?(),
              let onCodexSessionAssociated else { return }
        let selectedID = await currentAnchorSessionID?()
        let activeIDs = Set(sessions.filter { $0.status == .active }.map(\.id))
        trackedCodexSessionIDs = []
        // Earlier builds could auto-match guardian or subagent logs; stop observing them.
        let bindings = loadTrackedCodexSessions()
        let retained = bindings.filter { binding in
            guard binding.automaticallyMatched == true, let rootURL = root(for: binding.source) else { return true }
            return CodexSessionMetadata.read(from: rootURL.appending(path: binding.relativePath))?
                .isUserConversation != false
        }
        if retained.count != bindings.count { saveTrackedCodexSessions(retained) }
        for binding in retained where activeIDs.contains(binding.anchorSessionID) {
            guard let rootURL = root(for: binding.source) else { continue }
            let url = rootURL.appending(path: binding.relativePath)
            guard Self.relativePath(for: url, under: rootURL) != nil,
                  FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                if !registeredBindings.contains(binding) {
                    try await onCodexSessionAssociated(url, binding.anchorSessionID, binding.automaticallyMatched == true, binding.stepID)
                    registeredBindings.insert(binding)
                }
                if binding.anchorSessionID == selectedID { trackedCodexSessionIDs.insert(binding.codexSessionID) }
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func startCodexDiscoveryIfNeeded() {
        guard codexDiscoveryTask == nil, hasConversationSource else { return }
        restartCodexDiscovery()
    }

    /// One loop reads every granted agent's recent conversations and places them.
    private func restartCodexDiscovery() {
        codexDiscoveryTask?.cancel()
        codexDiscoveryTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.publish(await self.currentSummaries())
                await self.placeConversations(self.codexConversations)
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    /// Places every recent, unplaced conversation: attached to a task (and step)
    /// when the evidence is clear, otherwise unsorted. Nothing opens a window.
    func placeConversations(_ conversations: [CodexConversationSummary]) async {
        await serially { await self.performPlacement(conversations) }
    }

    private func performPlacement(_ conversations: [CodexConversationSummary]) async {
        guard hasConversationSource, let autoAssociationSessions else { return }
        await refreshTaskState()
        let tasks = await autoAssociationSessions().filter { $0.status == .active }
        activeTasks = tasks
        let activeIDs = Set(tasks.map(\.id))
        var bindings = loadTrackedCodexSessions()
        var attached: [String: UUID] = [:]
        var steps: [String: UUID] = [:]
        for binding in bindings where activeIDs.contains(binding.anchorSessionID) {
            attached[binding.codexSessionID] = binding.anchorSessionID
            if let step = binding.stepID { steps[binding.codexSessionID] = step }
        }
        var unsorted: [CodexConversationSummary] = []
        var candidates: [String: [UUID]] = [:]
        let earliestStart = tasks.map(\.startedAt).min()
        for conversation in conversations {
            guard !Task.isCancelled else { return }
            guard attached[conversation.id] == nil, !matchMemory.ignored.contains(conversation.id),
                  let earliestStart, conversation.candidate.modifiedAt >= earliestStart,
                  let location = location(of: conversation.candidate.fileURL) else { continue }
            let work = await work(for: conversation)
            switch TaskMatcher.place(work, tasks: tasks, current: currentTask, memory: matchMemory) {
            case let .task(taskID, step, reason):
                bindings = loadTrackedCodexSessions()
                guard let onCodexSessionAssociated,
                      !bindings.contains(where: { $0.codexSessionID == conversation.id }) else { continue }
                do {
                    let automatic = reason != .corrected
                    try await onCodexSessionAssociated(conversation.candidate.fileURL, taskID, automatic, step)
                    let binding = TrackedCodexSession(anchorSessionID: taskID, codexSessionID: conversation.id,
                                                      relativePath: location.path, automaticallyMatched: automatic,
                                                      stepID: step, source: location.source)
                    bindings.removeAll { $0.codexSessionID == conversation.id }
                    bindings.append(binding)
                    saveTrackedCodexSessions(bindings)
                    registeredBindings.insert(binding)
                    matchMemory.learn(folder: work.folder, task: taskID)
                    saveMatchMemory()
                    attached[conversation.id] = taskID
                    if let step { steps[conversation.id] = step }
                    if taskID == observedAnchorSessionID { trackedCodexSessionIDs.insert(conversation.id) }
                } catch { errorMessage = error.localizedDescription }
            case let .unsorted(leaning):
                unsorted.append(conversation)
                candidates[conversation.id] = leaning
            case .ignored:
                continue
            }
        }
        // A click may have filed something while requests were read off the main actor.
        guard !Task.isCancelled else { return }
        for (id, task) in attached where conversationTasks[id] != task { conversationTasks[id] = task }
        for id in conversationTasks.keys where attached[id] == nil { conversationTasks[id] = nil }
        if conversationSteps != steps { conversationSteps = steps }
        let stillUnsorted = unsorted.filter { conversationTasks[$0.id] == nil && !matchMemory.ignored.contains($0.id) }
        if unsortedConversations != stillUnsorted { unsortedConversations = stillUnsorted }
        if unsortedCandidates != candidates { unsortedCandidates = candidates }
    }

    private func work(for conversation: CodexConversationSummary) async -> TaskMatcher.Work {
        let stamp = conversation.candidate.modifiedAt
        let latest: String
        if let cached = requestCache[conversation.id], cached.stamp == stamp {
            latest = cached.text
        } else {
            let url = conversation.candidate.fileURL
            latest = await Task.detached(priority: .utility) {
                CodexAutoAssociation.latestUserRequest(at: url) ?? ""
            }.value
            requestCache[conversation.id] = (stamp, latest)
        }
        return TaskMatcher.Work(
            id: conversation.id,
            folder: conversation.candidate.workspaceName,
            request: [conversation.title ?? "", latest].joined(separator: "\n"),
            startedAt: conversation.candidate.createdAt,
            lastActivityAt: stamp
        )
    }

    private func saveMatchMemory() {
        guard let data = try? JSONEncoder().encode(matchMemory) else { return }
        defaults.set(data, forKey: Self.matchMemoryKey)
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

    private static func folderBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private static let matchMemoryKey = "anchor.mac.source-setup.match-memory.v1"
    private static let commandBookmarkKey = "anchor.mac.source-setup.command"
    private static let codexBookmarkKey = "anchor.mac.source-setup.codex-session"
    private static let codexRootBookmarkKey = "anchor.mac.source-setup.codex-root.v1"
    private static let codexTrackedSessionsKey = "anchor.mac.source-setup.codex-tracked.v1"
    private static let claudeRootBookmarkKey = "anchor.mac.source-setup.claude-root.v1"
}

enum MacClaudeCodeCopy {
    static let title = AnchorStrings.value("mac.sources.claude", default: "Claude Code")
    static let detail = AnchorStrings.value(
        "mac.sources.claude.detail",
        default: "Automatically discovers Claude Code conversations, titles, turn status and reply summaries, then associates them with matching tasks.")
    static let ready = AnchorStrings.value(
        "mac.sources.claude.ready", default: "Automatically discovering conversations")
    static let lostAccess = AnchorStrings.value(
        "mac.sources.claude.lost-access", default: "The Claude Code folder can no longer be read. Allow it again.")
}
#endif
