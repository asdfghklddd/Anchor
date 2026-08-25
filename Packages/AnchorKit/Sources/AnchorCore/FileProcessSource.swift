import Foundation

public enum FileProcessSignalKind: Sendable {
    case cli
    case web
}

/// A small, sandbox-friendly handoff boundary for the supported Anchor CLI.
/// The CLI writes one atomically-created JSON file per observation; this source
/// moves consumed files out of the inbox before yielding them to the actor.
public struct FileProcessSource: ProcessSource, Sendable {
    public static let defaultSourceID = UUID(uuidString: "00000000-0000-4000-8000-000000000401") ?? UUID()

    public let directoryURL: URL
    public let pollInterval: TimeInterval
    public let maximumFileSize: Int
    public let descriptor: SourceDescriptor
    private let sessionContextProvider: @Sendable () async -> ProcessSourceSessionContext?
    private let signalKind: FileProcessSignalKind

    public init(
        directoryURL: URL = FileProcessSource.defaultInboxURL(),
        pollInterval: TimeInterval = 0.25,
        maximumFileSize: Int = 1_048_576,
        sessionContextProvider: @escaping @Sendable () async -> ProcessSourceSessionContext? = { nil },
        signalKind: FileProcessSignalKind = .cli,
        descriptor: SourceDescriptor = SourceDescriptor(
            id: FileProcessSource.defaultSourceID,
            name: "Anchor CLI",
            kind: .cli,
            symbol: "⌘",
            tone: "cyan",
            capabilities: [.observe]
        )
    ) {
        self.directoryURL = directoryURL
        self.pollInterval = max(0.05, pollInterval)
        self.maximumFileSize = max(1, maximumFileSize)
        self.sessionContextProvider = sessionContextProvider
        self.signalKind = signalKind
        self.descriptor = descriptor
    }

    public func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try makeInboxDirectories()
                    while !Task.isCancelled {
                        for fileURL in try pendingFiles() {
                            try Task.checkCancellation()
                            do {
                                if let event = try await readAndConsume(fileURL) {
                                    continuation.yield(event)
                                }
                            } catch is CancellationError {
                                throw CancellationError()
                            } catch {
                                // Invalid or oversized input is quarantined by
                                // readAndConsume. Keep the adapter alive so a
                                // later valid event is not blocked by one bad
                                // producer payload.
                            }
                        }
                        try await Task.sleep(for: .seconds(pollInterval))
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func retry(_ event: ExternalProcessEvent) async throws {
        try makeInboxDirectories()
        let destination = directoryURL.appending(path: "\(event.id.uuidString).json")
        let temporary = directoryURL.appending(path: ".\(event.id.uuidString).retry.tmp")
        let data = try JSONEncoder.anchorExternal.encode(event)
        try data.write(to: temporary, options: .atomic)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    public static func defaultInboxURL() -> URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Group Containers/group.com.andywang.anchor/Anchor/Inbox", directoryHint: .isDirectory)
        #else
        return URL.applicationSupportDirectory
            .appending(path: "Anchor/Inbox", directoryHint: .isDirectory)
        #endif
    }

    public static func defaultWebInboxURL() -> URL {
        #if os(macOS)
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(
                path: "Library/Group Containers/group.com.andywang.anchor/Anchor/WebInbox",
                directoryHint: .isDirectory
            )
        #else
        return URL.applicationSupportDirectory
            .appending(path: "Anchor/WebInbox", directoryHint: .isDirectory)
        #endif
    }

    private func makeInboxDirectories() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: directoryURL.appending(path: ".processed", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: directoryURL.appending(path: ".failed", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: directoryURL.appending(path: ".ignored", directoryHint: .isDirectory),
            withIntermediateDirectories: true
        )
    }

    private func pendingFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func readAndConsume(_ fileURL: URL) async throws -> ExternalProcessEvent? {
        let attributes = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard attributes.isRegularFile == true else {
            throw FileProcessSourceError.notRegularFile(fileURL)
        }
        guard (attributes.fileSize ?? 0) <= maximumFileSize else {
            try move(fileURL, to: ".failed")
            throw FileProcessSourceError.fileTooLarge(fileURL)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let event: ExternalProcessEvent
            if let externalEvent = try? JSONDecoder.anchorExternal.decode(
                ExternalProcessEvent.self,
                from: data
            ) {
                event = externalEvent
            } else {
                switch signalKind {
                case .cli:
                    let signal = try JSONDecoder.anchorExternal.decode(
                        CLIProcessSignal.self,
                        from: data
                    )
                    guard let session = await sessionContextProvider() else {
                        return nil
                    }
                    guard signal.occurredAt >= session.startedAt else {
                        try move(fileURL, to: ".ignored")
                        return nil
                    }
                    event = try signal.externalEvent(
                        sessionID: session.sessionID,
                        sourceID: descriptor.id
                    )
                case .web:
                    let signal = try JSONDecoder.anchorExternal.decode(
                        WebProcessSignal.self,
                        from: data
                    )
                    guard let session = await sessionContextProvider() else {
                        return nil
                    }
                    guard signal.occurredAt >= session.startedAt else {
                        try move(fileURL, to: ".ignored")
                        return nil
                    }
                    event = try signal.externalEvent(
                        sessionID: session.sessionID,
                        sourceID: descriptor.id
                    )
                }
            }
            try move(fileURL, to: ".processed")
            return event
        } catch {
            try? move(fileURL, to: ".failed")
            throw FileProcessSourceError.invalidEvent(
                fileURL,
                underlying: error.localizedDescription
            )
        }
    }

    private func move(_ fileURL: URL, to directoryName: String) throws {
        let destinationDirectory = directoryURL.appending(
            path: directoryName,
            directoryHint: .isDirectory
        )
        let destination = destinationDirectory.appending(path: fileURL.lastPathComponent)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: fileURL, to: destination)
    }
}

public enum FileProcessSourceError: LocalizedError, Sendable, Hashable {
    case notRegularFile(URL)
    case fileTooLarge(URL)
    case invalidEvent(URL, underlying: String)

    public var errorDescription: String? {
        switch self {
        case let .notRegularFile(url):
            "The Anchor CLI inbox item is not a regular file: \(url.lastPathComponent)."
        case let .fileTooLarge(url):
            "The Anchor CLI event is too large: \(url.lastPathComponent)."
        case let .invalidEvent(url, underlying):
            "The Anchor CLI event could not be decoded (\(url.lastPathComponent)): \(underlying)"
        }
    }
}
